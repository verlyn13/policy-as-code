#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

OUT_DIR = Path('.out/journal')

def opa_eval(query: str):
  """Run opa eval against policies/data and return the JSON value of the query."""
  cp = subprocess.run([
    'opa','eval','-d','data/','-f','json',query
  ], check=True, capture_output=True, text=True)
  doc = json.loads(cp.stdout)
  return doc['result'][0]['expressions'][0]['value']

def write_yaml(path: Path, obj: dict):
  # Minimal YAML emitter for flat dicts/lists
  def emit(val, indent=0):
    sp = '  '*indent
    if isinstance(val, dict):
      lines = []
      for k,v in val.items():
        if isinstance(v,(dict,list)):
          lines.append(f"{sp}{k}:")
          lines.append(emit(v, indent+1))
        else:
          sval = json.dumps(v) if isinstance(v, (str, bool)) or v is None else v
          lines.append(f"{sp}{k}: {sval}")
      return '\n'.join(lines)
    elif isinstance(val, list):
      lines = []
      for item in val:
        if isinstance(item,(dict,list)):
          lines.append(f"{sp}-")
          lines.append(emit(item, indent+1))
        else:
          sval = json.dumps(item) if isinstance(item, (str, bool)) or item is None else item
          lines.append(f"{sp}- {sval}")
      return '\n'.join(lines)
    else:
      return f"{sp}{val}"

  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(emit(obj) + "\n", encoding='utf-8')

def main():
  OUT_DIR.mkdir(parents=True, exist_ok=True)

  # Load Infisical mirrors via OPA (OPA parses YAML → JSON)
  journal = opa_eval('data.infisical.journal')
  identities = journal['identities']
  project_roles = journal.get('project_roles', [])

  # Roles
  for role in project_roles:
    slug = role['slug']
    p = OUT_DIR / f"ProjectRole_{slug}.yaml"
    write_yaml(p, {
      'apiVersion': 'infisical.verlyn13.dev/v1',
      'kind': 'ProjectRole',
      'metadata': {'name': role['name'], 'slug': slug},
      'spec': {'permissions': role['permissions']},
    })

  # Identities and bindings
  for ident in identities:
    name = ident['name']
    # Identity
    write_yaml(OUT_DIR / f"identity_{name}.yaml", {
      'apiVersion': 'infisical.verlyn13.dev/v1',
      'kind': 'MachineIdentity',
      'metadata': {'name': name, 'labels': {'env': ident.get('env')}} ,
      'spec': {
        'project_role': ident.get('project_role'),
        'auth': ident.get('auth', {}),
      }
    })
    # Binding
    perms = ident.get('permissions', {})
    write_yaml(OUT_DIR / f"binding_{name}.yaml", {
      'apiVersion': 'infisical.verlyn13.dev/v1',
      'kind': 'ProjectBinding',
      'metadata': {'identity': name, 'environment': ident.get('env')},
      'spec': {
        'project_role': ident.get('project_role'),
        'permissions': {
          'read_paths': perms.get('read_paths', []),
          'write_paths': perms.get('write_paths', []),
        }
      }
    })

  # Platform manifests (Vercel/Supabase)
  vercel = opa_eval('data.platforms.vercel')
  supabase = opa_eval('data.platforms.supabase')

  (OUT_DIR / 'vercel-env.json').write_text(json.dumps(vercel, indent=2) + '\n', encoding='utf-8')
  (OUT_DIR / 'supabase-config.json').write_text(json.dumps(supabase, indent=2) + '\n', encoding='utf-8')

  print(f"Artifacts written to {OUT_DIR}")

if __name__ == '__main__':
  try:
    main()
  except subprocess.CalledProcessError as e:
    sys.stderr.write(e.stderr)
    sys.exit(1)
