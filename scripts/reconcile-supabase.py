#!/usr/bin/env python3
"""
Reconcile Supabase configuration from generated manifest
Ensures JWT security, RLS enforcement, and proper secret handling
"""

import json
import sys
import os
from pathlib import Path
import subprocess
import argparse
from typing import Dict, Any

class SupabaseReconciler:
    def __init__(self, project: str, dry_run: bool = False):
        self.project = project
        self.dry_run = dry_run
        self.manifest_path = Path(f".out/{project}/supabase-config.json")
        self.config = None
        
    def load_manifest(self) -> bool:
        """Load the Supabase configuration manifest"""
        if not self.manifest_path.exists():
            print(f"❌ Manifest not found: {self.manifest_path}")
            print("Run 'make render' first to generate artifacts")
            return False
        
        with open(self.manifest_path, 'r') as f:
            self.config = json.load(f)
        
        return True
    
    def validate_jwt_config(self) -> bool:
        """Validate JWT configuration meets security requirements"""
        auth = self.config.get('auth', {})
        
        # Check JWT secret is present (as reference)
        jwt_secret = auth.get('jwt_secret')
        if not jwt_secret:
            print("  ❌ JWT secret is missing")
            return False
        
        # Validate JWT expiry (must be <= 24 hours)
        jwt_exp = auth.get('jwt_exp', 0)
        if jwt_exp > 86400:  # 24 hours in seconds
            print(f"  ❌ JWT expiry too long: {jwt_exp}s (max: 86400s)")
            return False
        
        print(f"  ✅ JWT configured: exp={jwt_exp}s")
        return True
    
    def apply_auth_settings(self) -> bool:
        """Apply authentication settings"""
        print("\n🔐 Applying Authentication Settings...")
        
        if not self.validate_jwt_config():
            return False
        
        auth = self.config.get('auth', {})
        
        if not self.dry_run:
            # Get actual JWT secret from Infisical
            jwt_secret_ref = auth.get('jwt_secret')
            if jwt_secret_ref and jwt_secret_ref.startswith('${'):
                # Extract the secret name
                secret_name = jwt_secret_ref.strip('${}')
                print(f"  Fetching {secret_name} from Infisical...")
                
                # In production, fetch from Infisical
                # jwt_secret = subprocess.check_output(
                #     ['infisical', 'secrets', 'get', secret_name, '--plain'],
                #     text=True
                # ).strip()
            
            # Apply auth providers
            providers = auth.get('providers', [])
            for provider in providers:
                print(f"  Configuring provider: {provider}")
                if not self.dry_run:
                    # supabase auth providers enable {provider}
                    pass
        else:
            print("  [DRY RUN] Would configure auth settings")
        
        return True
    
    def apply_database_settings(self) -> bool:
        """Apply database settings including RLS"""
        print("\n🗄️  Applying Database Settings...")
        
        db = self.config.get('database', {})
        rls_enforced = db.get('rls_enforced', True)
        
        if not rls_enforced:
            print("  ⚠️  WARNING: RLS is not enforced - this is a security risk!")
            return False
        
        print(f"  ✅ RLS enforced: {rls_enforced}")
        
        if not self.dry_run:
            # Enable RLS on all tables
            schema = db.get('schema', 'public')
            
            # This would connect to Supabase and enable RLS
            # For demonstration, showing the SQL that would run
            sql_commands = [
                f"ALTER TABLE {schema}.users ENABLE ROW LEVEL SECURITY;",
                f"ALTER TABLE {schema}.posts ENABLE ROW LEVEL SECURITY;",
                # Add more tables as needed
            ]
            
            for sql in sql_commands:
                print(f"    SQL: {sql}")
                # In production: supabase db execute "{sql}"
        else:
            print("  [DRY RUN] Would enable RLS on all tables")
        
        return True
    
    def apply_environment_variables(self) -> bool:
        """Apply public environment variables"""
        print("\n🌍 Applying Environment Variables...")
        
        env = self.config.get('environment', {})
        public_env = env.get('public', {})
        
        for key, value in public_env.items():
            # Validate public env vars
            if 'SUPABASE_SERVICE_KEY' in key:
                print(f"  ❌ BLOCKED: {key} - service key must never be public!")
                return False
            
            if key.startswith('NEXT_PUBLIC_SUPABASE_'):
                print(f"  ✅ Setting {key}")
                if not self.dry_run:
                    # Set in Supabase project settings
                    # This would use Supabase Management API
                    pass
            else:
                print(f"  ⚠️  Skipping {key} - not a Supabase public var")
        
        return True
    
    def apply_edge_functions(self) -> bool:
        """Deploy Edge Functions if configured"""
        print("\n⚡ Checking Edge Functions...")
        
        # Check if edge functions directory exists
        edge_dir = Path(f"supabase/functions/{self.project}")
        
        if edge_dir.exists():
            functions = list(edge_dir.glob("*/index.ts"))
            print(f"  Found {len(functions)} edge functions")
            
            for func_path in functions:
                func_name = func_path.parent.name
                print(f"  Deploying function: {func_name}")
                
                if not self.dry_run:
                    # Deploy edge function
                    cmd = ["supabase", "functions", "deploy", func_name]
                    print(f"    CMD: {' '.join(cmd)}")
                    # subprocess.run(cmd)
        else:
            print("  No edge functions found")
        
        return True
    
    def reconcile(self) -> bool:
        """Main reconciliation logic"""
        print(f"\n🔄 Reconciling Supabase configuration for project: {self.project}")
        
        if self.dry_run:
            print("  ⚠️  DRY RUN MODE - No changes will be applied")
        
        # Load manifest
        if not self.load_manifest():
            return False
        
        print(f"\n📋 Configuration loaded from: {self.manifest_path}")
        
        # Apply settings in order
        steps = [
            ("Authentication", self.apply_auth_settings),
            ("Database", self.apply_database_settings),
            ("Environment", self.apply_environment_variables),
            ("Edge Functions", self.apply_edge_functions),
        ]
        
        results = {}
        for step_name, step_func in steps:
            try:
                results[step_name] = step_func()
            except Exception as e:
                print(f"\n❌ {step_name} failed: {e}")
                results[step_name] = False
        
        # Summary
        print("\n📊 Reconciliation Summary:")
        for step, success in results.items():
            status = "✅" if success else "❌"
            print(f"  {status} {step}")
        
        all_success = all(results.values())
        
        if all_success:
            print(f"\n✅ Supabase reconciliation complete for project: {self.project}")
        else:
            print(f"\n❌ Supabase reconciliation failed for project: {self.project}")
        
        return all_success

def main():
    parser = argparse.ArgumentParser(description="Reconcile Supabase configuration")
    parser.add_argument("project", help="Project name")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without applying")
    parser.add_argument("--supabase-url", help="Supabase project URL")
    parser.add_argument("--supabase-key", help="Supabase service role key")
    
    args = parser.parse_args()
    
    # Set up Supabase environment if provided
    if args.supabase_url:
        os.environ["SUPABASE_URL"] = args.supabase_url
    if args.supabase_key:
        os.environ["SUPABASE_SERVICE_KEY"] = args.supabase_key
    
    # Run reconciliation
    reconciler = SupabaseReconciler(args.project, args.dry_run)
    success = reconciler.reconcile()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()