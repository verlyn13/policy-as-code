#!/usr/bin/env python3
"""
Validate Terraform resource naming conventions
"""

import re
import sys
import glob

# Naming pattern: <resource_type>-<workload>-<environment>-<region>-<instance>
NAMING_PATTERN = r'^[a-z]{2,5}-[a-z0-9]{2,20}-(dev|stg|prod)-(hel1|fsn1|nbg1)-[0-9]{3}$'

# Resource abbreviations
ABBREVIATIONS = {
    'hetzner_server': 'hcs',
    'hetzner_firewall': 'hcfw',
    'hetzner_network': 'hcn',
    'hetzner_volume': 'hcv',
    'infisical_project': 'prj',
    'infisical_group': 'grp',
    'terraform_workspace': 'tfw',
}

def validate_resource_names():
    """Validate all resource names in Terraform files"""
    errors = []
    
    for tf_file in glob.glob('**/*.tf', recursive=True):
        with open(tf_file, 'r') as f:
            content = f.read()
            
        # Find resource declarations
        resources = re.findall(r'resource\s+"([^"]+)"\s+"([^"]+)"', content)
        
        for resource_type, resource_name in resources:
            if resource_type in ABBREVIATIONS:
                if not re.match(NAMING_PATTERN, resource_name):
                    errors.append(f"{tf_file}: {resource_type}.{resource_name} does not follow naming convention")
    
    return errors

if __name__ == '__main__':
    errors = validate_resource_names()
    
    if errors:
        print("❌ Naming validation failed:")
        for error in errors:
            print(f"  - {error}")
        sys.exit(1)
    else:
        print("✅ All resource names follow the convention")
        sys.exit(0)