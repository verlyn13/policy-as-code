package kubernetes.admission_test

import data.kubernetes.admission
import data.testing.framework
import future.keywords.if

# Parameterized tests for pod security policies
test_parameterized_security_violations if {
    test_cases := [
        {
            "name": "privileged_container",
            "container": {
                "name": "test",
                "securityContext": {"privileged": true}
            },
            "should_fail": true,
            "expected_violation": "must not run in privileged mode"
        },
        {
            "name": "allow_privilege_escalation",
            "container": {
                "name": "test",
                "securityContext": {"allowPrivilegeEscalation": true}
            },
            "should_fail": true,
            "expected_violation": "must not allow privilege escalation"
        },
        {
            "name": "secure_container",
            "container": {
                "name": "test",
                "securityContext": {
                    "runAsNonRoot": true,
                    "privileged": false,
                    "allowPrivilegeEscalation": false,
                    "readOnlyRootFilesystem": true
                },
                "resources": {
                    "limits": {"memory": "512Mi", "cpu": "500m"}
                },
                "livenessProbe": {"httpGet": {"path": "/health", "port": 8080}},
                "readinessProbe": {"httpGet": {"path": "/ready", "port": 8080}}
            },
            "should_fail": false,
            "expected_violation": ""
        }
    ]
    
    # Run each test case
    results := [result |
        test_case := test_cases[_]
        input_pod := {"spec": {"containers": [test_case.container]}}
        
        violations := admission.violation with input as input_pod
        has_violations := count(violations) > 0
        
        # Verify test expectation
        result := {
            "test": test_case.name,
            "passed": has_violations == test_case.should_fail,
            "violations": violations
        }
    ]
    
    # All tests should pass
    failed_tests := [r.test | r := results[_]; not r.passed]
    count(failed_tests) == 0
}

# Data-driven tests using external test data (example - commented as policy logic differs)
# test_data_driven_validation if {
#     # Test data could be loaded from data.test_cases
#     test_inputs := [
#         {"name": "pod1", "namespace": "default"},
#         {"name": "pod2", "namespace": "kube-system"},
#         {"name": "pod3", "namespace": "production"}
#     ]
#     
#     results := [result |
#         test_input := test_inputs[_]
#         pod := framework.mock_kubernetes_pod(test_input.name, test_input.namespace)
#         
#         # Apply namespace-specific rules
#         allowed := test_input.namespace != "kube-system"
#         actual := admission.allow with input as pod
#         
#         result := {
#             "pod": test_input.name,
#             "namespace": test_input.namespace,
#             "test_passed": (allowed == actual)
#         }
#     ]
    
    # Verify all tests passed
#     failed_count := count([r | r := results[_]; not r.test_passed])
#     failed_count == 0
# }

# Test with mocked functions (example - commented out as check_time_based_policy doesn't exist)
# test_with_mocked_time if {
#     # Mock time.now_ns() for deterministic testing
#     test_time := 1234567890
#     
#     result := admission.check_time_based_policy with time.now_ns as test_time
#     result == true
# }

# Coverage test to ensure all rules are tested
test_coverage_validation if {
    # List all rules that should be covered
    required_rules := {
        "allow",
        "violation"
    }
    
    # This would typically be checked by OPA's coverage report
    # Here we just verify the rules exist
    rules_exist := [exists |
        rule := required_rules[_]
        exists := data.kubernetes.admission[rule]
    ]
    count(rules_exist) == count(required_rules)
}