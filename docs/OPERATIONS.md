# Operations Guide for Policy as Code

## Overview

This guide covers operational aspects of running OPA in production, including deployment, monitoring, troubleshooting, and maintenance.

## Deployment Models

### 1. Kubernetes Admission Controller

Deploy OPA as a validating admission webhook:

```bash
# Deploy OPA
kubectl apply -f deployments/kubernetes/opa-deployment.yaml

# Configure webhook (fail-closed)
kubectl apply -f examples/kubernetes/validatingwebhook-failclosed.yaml
```

**Key Configuration**:
- `failurePolicy: Fail` - Ensures fail-closed behavior
- `timeoutSeconds: 5` - Prevents hanging requests
- Namespace selector to exclude system namespaces

### 2. Sidecar Pattern

For service mesh integration:

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:latest
  - name: opa
    image: openpolicyagent/opa:1.7.1
    args:
      - "run"
      - "--server"
      - "--config-file=/config/config.yaml"
    volumeMounts:
    - name: opa-config
      mountPath: /config
```

### 3. Standalone Server

For centralized policy decisions:

```bash
# Production mode
make server

# Development mode with hot reload
make server-dev
```

## Monitoring & Observability

### Metrics

OPA exposes Prometheus metrics on `:8181/metrics`:

```yaml
# Key metrics to monitor
- opa_policy_evaluation_duration_seconds
- opa_policy_evaluation_total
- opa_bundle_loaded_timestamp
- opa_decision_log_queue_size
```

### Grafana Dashboard

Import the provided dashboard:

```bash
kubectl apply -f monitoring/grafana-dashboard.json
```

Key panels:
- Decision rate (allows/denies per second)
- P95 evaluation latency
- Bundle update status
- Error rate

### Alerting Rules

```yaml
# prometheus-rules.yaml
groups:
- name: opa_alerts
  rules:
  - alert: OPAHighDenyRate
    expr: rate(opa_policy_evaluation_total{decision="deny"}[5m]) > 10
    annotations:
      summary: "High deny rate detected"
      
  - alert: OPAHighLatency
    expr: histogram_quantile(0.95, opa_policy_evaluation_duration_seconds) > 0.1
    annotations:
      summary: "OPA evaluation latency above 100ms"
      
  - alert: OPABundleOutdated
    expr: time() - opa_bundle_loaded_timestamp > 3600
    annotations:
      summary: "OPA bundle not updated for >1 hour"
```

### Decision Logs

Configure structured logging to a central system:

```yaml
# config/decision-log.yaml
decision_logs:
  service: elasticsearch
  reporting:
    min_delay_seconds: 5
    max_delay_seconds: 10

services:
  elasticsearch:
    url: http://elasticsearch:9200
    credentials:
      bearer:
        token: ${ES_TOKEN}
```

Query decision logs:

```json
GET /opa-decisions-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"decision": "deny"}},
        {"range": {"timestamp": {"gte": "now-1h"}}}
      ]
    }
  }
}
```

## Performance Tuning

### Benchmarking

Run performance benchmarks:

```bash
# Basic benchmark
make benchmark

# With CPU profiling
make benchmark-profile

# Analyze profile
go tool pprof cpu.prof
```

### Optimization Strategies

1. **Index policies**: Use indexed rules for large datasets
2. **Partial evaluation**: Pre-compute static portions
3. **Bundle optimization**: Minimize bundle size
4. **Caching**: Enable inter-query caching

```yaml
# config.yaml
caching:
  inter_query_cache:
    max_size_bytes: 10000000
```

## Troubleshooting

### Common Issues

#### 1. High Memory Usage

**Symptom**: OPA consuming excessive memory

**Solution**:
```bash
# Check decision log queue
curl localhost:8181/metrics | grep decision_log_queue

# Reduce queue size
decision_logs:
  reporting:
    buffer_size_limit_bytes: 16384
```

#### 2. Slow Policy Evaluation

**Symptom**: P95 latency > 100ms

**Diagnosis**:
```bash
# Enable profiling
curl -X POST localhost:8181/v1/compile \
  -d '{"query": "data.kubernetes.admission.deny[x]", "profiler": true}'

# Review hot spots
```

#### 3. Bundle Update Failures

**Symptom**: Policies not updating

**Check**:
```bash
# Bundle status
curl localhost:8181/v1/status/bundles

# Manual bundle load
curl -X POST localhost:8181/v1/data \
  -H "Content-Type: application/x-tar" \
  --data-binary @bundle.tar.gz
```

### Debug Mode

Enable verbose logging:

```yaml
# config.yaml
logging:
  level: debug
  console: true
```

## Backup & Recovery

### Policy Backup

Automated backup of policies:

```bash
#!/bin/bash
# backup-policies.sh
BACKUP_DIR="/backup/opa/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup policies
cp -r policies/ $BACKUP_DIR/
cp -r data/ $BACKUP_DIR/

# Backup bundles
cp bundles/*.tar.gz $BACKUP_DIR/

# Create manifest
echo "Backup created: $(date)" > $BACKUP_DIR/manifest.txt
```

### Disaster Recovery

Recovery procedure:

1. **Restore policies from Git**:
   ```bash
   git clone https://github.com/verlyn13/policy-as-code.git
   cd policy-as-code
   ```

2. **Rebuild bundle**:
   ```bash
   make bundle
   ```

3. **Deploy to OPA**:
   ```bash
   kubectl rollout restart deployment/opa -n opa
   ```

4. **Verify**:
   ```bash
   curl localhost:8181/v1/policies
   ```

## Maintenance

### Bundle Updates

Automated bundle deployment:

```yaml
# .github/workflows/deploy.yml
- name: Deploy Bundle
  run: |
    curl -X POST https://opa.prod.example.com/v1/bundles/policy \
      -H "Authorization: Bearer ${{ secrets.OPA_TOKEN }}" \
      --data-binary @bundle.tar.gz
```

### Version Upgrades

Rolling upgrade procedure:

1. Test in staging environment
2. Review changelog for breaking changes
3. Update one replica at a time
4. Monitor metrics during rollout

### Health Checks

Configure liveness and readiness probes:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8181
  periodSeconds: 10
  
readinessProbe:
  httpGet:
    path: /health?bundle=true
    port: 8181
  periodSeconds: 5
```

## Security

### TLS Configuration

Enable TLS for OPA:

```yaml
# config.yaml
server:
  tls:
    cert_file: /certs/tls.crt
    key_file: /certs/tls.key
    ca_cert_file: /certs/ca.crt
```

### Authentication

Configure token-based auth:

```yaml
# config.yaml
auth:
  token:
    algorithm: HS256
    secret: ${OPA_AUTH_SECRET}
```

### Rate Limiting

Prevent DoS attacks:

```yaml
# config.yaml
server:
  rate_limit:
    requests_per_second: 100
    burst: 200
```

## Compliance & Audit

### Audit Log Retention

Ensure compliance with retention policies:

```bash
# Archive old logs
find /var/log/opa -name "*.log" -mtime +90 -exec gzip {} \;

# Ship to long-term storage
aws s3 sync /var/log/opa/archive s3://audit-logs/opa/
```

### Compliance Reports

Generate compliance reports:

```bash
# Coverage report
opa test policies/ tests/ --coverage --format json > coverage.json

# Policy inventory
find policies -name "*.rego" | xargs grep "^package" > inventory.txt

# Decision summary
kubectl logs -n opa deployment/opa --since=24h | \
  jq -r '.decision' | sort | uniq -c
```

## Support

For issues or questions:
- GitHub Issues: https://github.com/verlyn13/policy-as-code/issues
- Documentation: https://docs.verlyn13.dev/policies
- OPA Slack: #opa-help