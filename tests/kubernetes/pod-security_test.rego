package kubernetes.admission

import future.keywords.if

test_allow_secure_pod if {
    allow with input as {
        "spec": {
            "containers": [{
                "name": "app",
                "securityContext": {
                    "runAsNonRoot": true,
                    "privileged": false,
                    "allowPrivilegeEscalation": false,
                    "readOnlyRootFilesystem": true
                },
                "resources": {
                    "limits": {
                        "memory": "512Mi",
                        "cpu": "500m"
                    }
                },
                "livenessProbe": {
                    "httpGet": {
                        "path": "/health",
                        "port": 8080
                    }
                },
                "readinessProbe": {
                    "httpGet": {
                        "path": "/ready",
                        "port": 8080
                    }
                }
            }]
        }
    }
}

test_deny_privileged_container if {
    not allow with input as {
        "spec": {
            "containers": [{
                "name": "app",
                "securityContext": {
                    "runAsNonRoot": true,
                    "privileged": true,
                    "allowPrivilegeEscalation": false,
                    "readOnlyRootFilesystem": true
                },
                "resources": {
                    "limits": {
                        "memory": "512Mi",
                        "cpu": "500m"
                    }
                },
                "livenessProbe": {
                    "httpGet": {
                        "path": "/health",
                        "port": 8080
                    }
                },
                "readinessProbe": {
                    "httpGet": {
                        "path": "/ready",
                        "port": 8080
                    }
                }
            }]
        }
    }
}

test_deny_missing_resource_limits if {
    not allow with input as {
        "spec": {
            "containers": [{
                "name": "app",
                "securityContext": {
                    "runAsNonRoot": true,
                    "privileged": false,
                    "allowPrivilegeEscalation": false,
                    "readOnlyRootFilesystem": true
                },
                "livenessProbe": {
                    "httpGet": {
                        "path": "/health",
                        "port": 8080
                    }
                },
                "readinessProbe": {
                    "httpGet": {
                        "path": "/ready",
                        "port": 8080
                    }
                }
            }]
        }
    }
}

test_violation_messages if {
    violations := violation with input as {
        "spec": {
            "containers": [{
                "name": "insecure-app",
                "securityContext": {
                    "privileged": true,
                    "allowPrivilegeEscalation": true
                }
            }]
        }
    }
    
    count(violations) > 0
}