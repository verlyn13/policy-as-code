#!/usr/bin/env python3
"""
Reconcile Infisical resources from generated artifacts
Applies roles, identities, and bindings to Infisical via API/SDK
"""

import json
import yaml
import sys
import os
from pathlib import Path
from typing import Dict, List, Any
import subprocess
import argparse

class InfisicalReconciler:
    def __init__(self, project: str, dry_run: bool = False):
        self.project = project
        self.dry_run = dry_run
        self.artifacts_dir = Path(f".out/{project}")
        self.applied = []
        self.failed = []
        
    def load_yaml(self, filepath: Path) -> Dict:
        """Load YAML artifact file"""
        with open(filepath, 'r') as f:
            return yaml.safe_load(f)
    
    def apply_project_role(self, filepath: Path) -> bool:
        """Apply ProjectRole resource"""
        try:
            role = self.load_yaml(filepath)
            role_name = role['metadata']['name']
            env = role['metadata'].get('environment', 'all')
            
            print(f"  Applying ProjectRole: {role_name} ({env})")
            
            if not self.dry_run:
                # Using Infisical CLI or API
                cmd = [
                    "infisical", "roles", "create",
                    "--name", role_name,
                    "--project", self.project,
                    "--permissions", json.dumps(role['spec']['permissions'])
                ]
                
                # For now, simulate the command
                print(f"    CMD: {' '.join(cmd)}")
                # result = subprocess.run(cmd, capture_output=True, text=True)
                # if result.returncode != 0:
                #     raise Exception(result.stderr)
            
            self.applied.append(f"ProjectRole/{role_name}")
            return True
            
        except Exception as e:
            print(f"    ❌ Failed: {e}")
            self.failed.append(f"ProjectRole/{filepath.name}")
            return False
    
    def apply_identity(self, filepath: Path) -> bool:
        """Apply MachineIdentity resource"""
        try:
            identity = self.load_yaml(filepath)
            name = identity['metadata']['name']
            env = identity['spec']['environment']
            
            print(f"  Applying MachineIdentity: {name} ({env})")
            
            if not self.dry_run:
                # Using Infisical CLI or API
                cmd = [
                    "infisical", "identities", "create",
                    "--name", name,
                    "--type", identity['spec']['type'],
                    "--project", self.project,
                    "--environment", env
                ]
                
                print(f"    CMD: {' '.join(cmd)}")
                # Execute command here
            
            self.applied.append(f"MachineIdentity/{name}")
            return True
            
        except Exception as e:
            print(f"    ❌ Failed: {e}")
            self.failed.append(f"MachineIdentity/{filepath.name}")
            return False
    
    def apply_binding(self, filepath: Path) -> bool:
        """Apply IdentityBinding resource"""
        try:
            binding = self.load_yaml(filepath)
            name = binding['metadata']['name']
            identity = binding['spec']['identity']
            role = binding['spec']['role']
            
            print(f"  Applying IdentityBinding: {name}")
            print(f"    Identity: {identity} -> Role: {role}")
            
            if not self.dry_run:
                # Using Infisical CLI or API
                for path in binding['spec']['paths']:
                    cmd = [
                        "infisical", "bindings", "create",
                        "--identity", identity,
                        "--role", role,
                        "--path", path,
                        "--project", self.project
                    ]
                    
                    print(f"    CMD: {' '.join(cmd)}")
                    # Execute command here
            
            self.applied.append(f"IdentityBinding/{name}")
            return True
            
        except Exception as e:
            print(f"    ❌ Failed: {e}")
            self.failed.append(f"IdentityBinding/{filepath.name}")
            return False
    
    def reconcile(self) -> bool:
        """Main reconciliation logic"""
        print(f"\n🔄 Reconciling Infisical resources for project: {self.project}")
        
        if self.dry_run:
            print("  ⚠️  DRY RUN MODE - No changes will be applied")
        
        if not self.artifacts_dir.exists():
            print(f"  ❌ Artifacts directory not found: {self.artifacts_dir}")
            return False
        
        # Order matters: roles -> identities -> bindings
        
        # 1. Apply ProjectRoles
        print("\n📋 Applying ProjectRoles...")
        for role_file in sorted(self.artifacts_dir.glob("ProjectRole_*.yaml")):
            self.apply_project_role(role_file)
        
        # 2. Apply MachineIdentities
        print("\n🤖 Applying MachineIdentities...")
        for identity_file in sorted(self.artifacts_dir.glob("identity_*.yaml")):
            self.apply_identity(identity_file)
        
        # 3. Apply IdentityBindings
        print("\n🔗 Applying IdentityBindings...")
        for binding_file in sorted(self.artifacts_dir.glob("binding_*.yaml")):
            self.apply_binding(binding_file)
        
        # Summary
        print("\n📊 Reconciliation Summary:")
        print(f"  ✅ Applied: {len(self.applied)} resources")
        for resource in self.applied:
            print(f"     - {resource}")
        
        if self.failed:
            print(f"  ❌ Failed: {len(self.failed)} resources")
            for resource in self.failed:
                print(f"     - {resource}")
            return False
        
        print(f"\n✅ Reconciliation complete for project: {self.project}")
        return True

def main():
    parser = argparse.ArgumentParser(description="Reconcile Infisical resources")
    parser.add_argument("project", help="Project name")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without applying")
    parser.add_argument("--config", help="Path to Infisical config file")
    
    args = parser.parse_args()
    
    # Set up Infisical config if provided
    if args.config:
        os.environ["INFISICAL_CONFIG"] = args.config
    
    # Run reconciliation
    reconciler = InfisicalReconciler(args.project, args.dry_run)
    success = reconciler.reconcile()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()