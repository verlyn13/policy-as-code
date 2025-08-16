#!/bin/bash
# OPA Performance Benchmarking Script

set -e

OPA_VERSION="v1.7.1"
BENCHMARK_DIR="benchmarks"
RESULTS_DIR="benchmarks/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}OPA Performance Benchmarking${NC}"
echo "================================"

# Check OPA version
echo -n "Checking OPA version... "
INSTALLED_VERSION=$(opa version --format json | jq -r .Version)
if [[ "$INSTALLED_VERSION" != "$OPA_VERSION" ]]; then
    echo -e "${YELLOW}Warning: Expected OPA $OPA_VERSION but found $INSTALLED_VERSION${NC}"
else
    echo -e "${GREEN}✓${NC}"
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Run benchmarks for each policy domain
echo ""
echo "Running policy benchmarks..."
echo "----------------------------"

# Kubernetes policies
if [ -d "policies/kubernetes" ]; then
    echo -e "\n${YELLOW}Benchmarking Kubernetes policies...${NC}"
    opa bench -d policies/kubernetes/ \
        -b "$BENCHMARK_DIR/bench.yaml" \
        --count 1000 \
        --format json \
        > "$RESULTS_DIR/kubernetes_${TIMESTAMP}.json"
    
    # Extract and display key metrics
    P50=$(jq '.metrics.timer_rego_query_eval_ns.percentiles["50"]' "$RESULTS_DIR/kubernetes_${TIMESTAMP}.json")
    P95=$(jq '.metrics.timer_rego_query_eval_ns.percentiles["95"]' "$RESULTS_DIR/kubernetes_${TIMESTAMP}.json")
    P99=$(jq '.metrics.timer_rego_query_eval_ns.percentiles["99"]' "$RESULTS_DIR/kubernetes_${TIMESTAMP}.json")
    
    echo "  P50: $(echo "scale=3; $P50/1000000" | bc)ms"
    echo "  P95: $(echo "scale=3; $P95/1000000" | bc)ms"
    echo "  P99: $(echo "scale=3; $P99/1000000" | bc)ms"
fi

# Terraform policies
if [ -d "policies/terraform" ]; then
    echo -e "\n${YELLOW}Benchmarking Terraform policies...${NC}"
    opa bench -d policies/terraform/ \
        -b "$BENCHMARK_DIR/bench.yaml" \
        --count 500 \
        --format json \
        > "$RESULTS_DIR/terraform_${TIMESTAMP}.json"
fi

# Run profiling if requested
if [ "$1" == "--profile" ]; then
    echo -e "\n${YELLOW}Running CPU profiling...${NC}"
    mkdir -p benchmarks/profiles
    
    opa bench -d policies/ \
        -b "$BENCHMARK_DIR/bench.yaml" \
        --count 10000 \
        --cpuprofile benchmarks/profiles/cpu_${TIMESTAMP}.prof
    
    echo -e "${GREEN}CPU profile saved to benchmarks/profiles/cpu_${TIMESTAMP}.prof${NC}"
    echo "View with: go tool pprof benchmarks/profiles/cpu_${TIMESTAMP}.prof"
fi

# Generate summary report
echo -e "\n${GREEN}Generating benchmark summary...${NC}"
cat > "$RESULTS_DIR/summary_${TIMESTAMP}.md" << EOF
# OPA Benchmark Results
**Date:** $(date)
**OPA Version:** $INSTALLED_VERSION

## Results
$(ls -1 "$RESULTS_DIR"/*_${TIMESTAMP}.json | while read f; do
    domain=$(basename "$f" | cut -d_ -f1)
    echo "### $domain"
    echo '```'
    jq '.metrics.timer_rego_query_eval_ns.percentiles' "$f"
    echo '```'
done)

## Test Configuration
- Iterations: See bench.yaml
- Policies tested: $(find policies -name "*.rego" | wc -l)
- Test cases: $(find tests -name "*_test.rego" | wc -l)
EOF

echo -e "${GREEN}✓ Benchmark complete!${NC}"
echo "Results saved to: $RESULTS_DIR/"
echo "Summary: $RESULTS_DIR/summary_${TIMESTAMP}.md"

# Check against thresholds
echo -e "\n${YELLOW}Checking performance thresholds...${NC}"
if [ -f "$RESULTS_DIR/kubernetes_${TIMESTAMP}.json" ]; then
    P95_MS=$(echo "scale=3; $(jq '.metrics.timer_rego_query_eval_ns.percentiles["95"]' "$RESULTS_DIR/kubernetes_${TIMESTAMP}.json")/1000000" | bc)
    THRESHOLD=5.0
    
    if (( $(echo "$P95_MS > $THRESHOLD" | bc -l) )); then
        echo -e "${RED}✗ P95 latency ($P95_MS ms) exceeds threshold ($THRESHOLD ms)${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ All performance thresholds met${NC}"
    fi
fi