package decision.journal

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Compose a cross-policy decision contract for the 'journal' project.

project := data.infisical.journal
vercel_input := data.platforms.vercel.journal
supabase_input := data.platforms.supabase.journal

infisical_denies := data.infisical.intent.deny
infisical_warns := [m | data.infisical.intent.warn[m]]

vercel_denies := ds if {
  ds := [d | d := data.vercel.app.deny[_] with input as vercel_input]
}

supabase_denies := ds if {
  ds := [d | d := data.supabase.project.deny[_] with input as supabase_input]
}

infisical_denies_arr := ds if { ds := [d | d := infisical_denies[_]] }

all_denies := concat_arrays([infisical_denies_arr, vercel_denies, supabase_denies])

ok := count(all_denies) == 0

# Helper to concat arrays of strings
concat_arrays(arrs) := out if {
  out := [x | a := arrs[_]; x := a[_]]
}

# Artifact rendering
proj_dir := ".out/journal"

role_artifacts := roles if {
  roles := [sprintf("%s/ProjectRole_%s.yaml", [proj_dir, r.slug]) | r := project.project_roles[_]]
} else := roles if {
  # Fallback in case project roles not present in data mirror
  roles := [sprintf("%s/ProjectRole_%s.yaml", [proj_dir, r]) | r := ["runtime","ci","security-ops-prj"][_]]
}

identity_artifacts := ids if {
  ids := [sprintf("%s/identity_%s.yaml", [proj_dir, id.name]) | id := data.infisical.journal.identities[_]]
}

binding_artifacts := binds if {
  binds := [sprintf("%s/binding_%s.yaml", [proj_dir, id.name]) | id := data.infisical.journal.identities[_]]
}

vercel_manifest := sprintf("%s/vercel-env.json", [proj_dir])
supabase_manifest := sprintf("%s/supabase-config.json", [proj_dir])

contract := out if {
  meta := project.meta.project
  slug := meta.slug
  out := {
    "project_slug": slug,
    "project_id": meta.id,
    "allowed": ok,
    "denies": all_denies,
    "warnings": infisical_warns,
    "artifacts": {
      "infisical": {
        "project_roles": role_artifacts,
        "machine_identities": identity_artifacts,
        "bindings": binding_artifacts
      },
      "platforms": {
        "vercel_manifest": vercel_manifest,
        "supabase_manifest": supabase_manifest
      }
    }
  }
}
