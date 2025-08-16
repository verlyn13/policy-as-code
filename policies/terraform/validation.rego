package terraform.validation

import data.lib.common
import future.keywords.contains
import future.keywords.if
import future.keywords.in

# METADATA
# title: Terraform Resource Validation
# description: Validates Terraform resources for compliance and best practices
# authors:
# - Policy Team
# custom:
#   severity: medium
#   category: compliance
#   version: 1.0.0

default allow := false

allow if {
    count(deny) == 0
}

# Required tags for all resources
required_tags := {
    "Environment",
    "Owner",
    "CostCenter",
    "Project",
    "ManagedBy"
}

# Deny resources without required tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    resource.type != "random_id"  # Exclude certain resource types
    
    missing_tags := required_tags - object.keys(resource.change.after.tags)
    count(missing_tags) > 0
    
    msg := sprintf("Resource '%s' is missing required tags: %v", [
        resource.address,
        missing_tags
    ])
}

# Deny S3 buckets without encryption
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not resource.change.after.server_side_encryption_configuration
    
    msg := sprintf("S3 bucket '%s' must have encryption enabled", [resource.address])
}

# Deny public S3 buckets
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.after.acl == "public-read"
    
    msg := sprintf("S3 bucket '%s' must not be publicly readable", [resource.address])
}

# Deny EC2 instances without monitoring
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    not resource.change.after.monitoring
    
    msg := sprintf("EC2 instance '%s' must have monitoring enabled", [resource.address])
}

# Deny security groups with unrestricted ingress
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group_rule"
    resource.change.after.type == "ingress"
    resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
    resource.change.after.from_port == 0
    resource.change.after.to_port == 65535
    
    msg := sprintf("Security group rule '%s' allows unrestricted access from the internet", [resource.address])
}

# Deny RDS instances without backup
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.after.backup_retention_period < 7
    
    msg := sprintf("RDS instance '%s' must have at least 7 days backup retention", [resource.address])
}

# Cost optimization: Deny expensive instance types in non-production
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    resource.change.after.tags.Environment != "production"
    
    expensive_types := {
        "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
        "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge"
    }
    
    resource.change.after.instance_type in expensive_types
    
    msg := sprintf("Instance '%s' uses expensive type '%s' in non-production environment", [
        resource.address,
        resource.change.after.instance_type
    ])
}

# Generate decision record
decision = {
    "allowed": allow,
    "denials": deny,
    "resource_count": count(input.resource_changes),
    "timestamp": time.now_ns()
}