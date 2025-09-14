#!/usr/bin/env python3
"""
Validate YAML/JSON files against their schemas
"""

import json
import yaml
import sys
from pathlib import Path
from jsonschema import validate, ValidationError, Draft7Validator

# Schema mappings
SCHEMA_MAP = {
    'projects/*/project.yaml': 'schemas/project.schema.json',
    'projects/*/identities.yaml': 'schemas/identities.schema.json',
    'data/infisical/*/project.yaml': 'schemas/project.schema.json',
    'data/infisical/*/identities.yaml': 'schemas/identities.schema.json',
}

def load_schema(schema_path):
    """Load a JSON schema file"""
    with open(schema_path, 'r') as f:
        return json.load(f)

def load_yaml(yaml_path):
    """Load a YAML file"""
    with open(yaml_path, 'r') as f:
        return yaml.safe_load(f)

def validate_file(file_path, schema_path):
    """Validate a YAML file against a schema"""
    try:
        # Load files
        schema = load_schema(schema_path)
        data = load_yaml(file_path)
        
        # Validate
        validator = Draft7Validator(schema)
        errors = list(validator.iter_errors(data))
        
        if errors:
            print(f"❌ {file_path}")
            for error in errors:
                path = '.'.join(str(p) for p in error.path)
                print(f"   - {path}: {error.message}")
            return False
        else:
            print(f"✅ {file_path}")
            return True
            
    except Exception as e:
        print(f"❌ {file_path}: {str(e)}")
        return False

def main():
    """Main validation function"""
    root = Path('.')
    all_valid = True
    validated_count = 0
    
    print("Schema Validation Report")
    print("=" * 50)
    
    for pattern, schema_path in SCHEMA_MAP.items():
        # Check if schema exists
        if not Path(schema_path).exists():
            print(f"⚠️  Schema not found: {schema_path}")
            continue
            
        # Find matching files
        for file_path in root.glob(pattern):
            if file_path.is_file():
                valid = validate_file(file_path, schema_path)
                validated_count += 1
                if not valid:
                    all_valid = False
    
    print("=" * 50)
    
    if validated_count == 0:
        print("⚠️  No files found to validate")
        sys.exit(0)
    
    if all_valid:
        print(f"✅ All {validated_count} files passed schema validation")
        sys.exit(0)
    else:
        print(f"❌ Schema validation failed")
        sys.exit(1)

if __name__ == '__main__':
    main()