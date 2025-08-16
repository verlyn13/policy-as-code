package testing.framework

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Test utility functions for common assertions

# Assert that a value is true
assert_true(value, message) if {
    value == true
} else = error {
    error := sprintf("Assertion failed: %s", [message])
}

# Assert that two values are equal
assert_equal(actual, expected, message) if {
    actual == expected
} else = error {
    error := sprintf("Assertion failed: %s. Expected: %v, Got: %v", [message, expected, actual])
}

# Assert that a value is in a collection
assert_contains(collection, value, message) if {
    value in collection
} else = error {
    error := sprintf("Assertion failed: %s. Value %v not found in collection", [message, value])
}

# Assert that a collection is empty
assert_empty(collection, message) if {
    count(collection) == 0
} else = error {
    error := sprintf("Assertion failed: %s. Collection has %d items", [message, count(collection)])
}

# Assert that a collection has a specific size
assert_size(collection, expected_size, message) if {
    count(collection) == expected_size
} else = error {
    error := sprintf("Assertion failed: %s. Expected size: %d, Got: %d", [message, expected_size, count(collection)])
}

# Mock data generator for testing
mock_kubernetes_pod(name, namespace) = pod if {
    pod := {
        "apiVersion": "v1",
        "kind": "Pod",
        "metadata": {
            "name": name,
            "namespace": namespace,
            "labels": {
                "app": name,
                "test": "true"
            }
        },
        "spec": {
            "containers": [
                {
                    "name": sprintf("%s-container", [name]),
                    "image": "nginx:latest",
                    "resources": {
                        "limits": {
                            "memory": "512Mi",
                            "cpu": "500m"
                        },
                        "requests": {
                            "memory": "256Mi",
                            "cpu": "250m"
                        }
                    }
                }
            ]
        }
    }
}

# Mock data for Terraform resources
mock_terraform_resource(type, name) = resource if {
    resource := {
        "type": type,
        "name": name,
        "change": {
            "actions": ["create"],
            "after": {
                "tags": {
                    "Environment": "test",
                    "ManagedBy": "terraform"
                }
            }
        }
    }
}

# Performance test helper
benchmark_policy(policy_package, input_data, iterations) = result if {
    start_time := time.now_ns()
    
    # Run the policy multiple times
    results := [output |
        i := numbers.range(1, iterations)
        output := data[policy_package].allow with input as input_data
    ]
    
    end_time := time.now_ns()
    duration_ms := (end_time - start_time) / 1000000
    
    result := {
        "iterations": iterations,
        "duration_ms": duration_ms,
        "avg_time_ms": duration_ms / iterations,
        "results": results
    }
}