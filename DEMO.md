# SecureAgentOps Demo Guide

## Overview
This guide helps you demonstrate SecureAgentOps - a Zero-Trust DevSecOps framework for GenAI agents.

## Prerequisites
- Kubernetes cluster with SecureAgentOps deployed
- `kubectl` configured
- `curl` and `jq` installed (optional but recommended)

## Quick Demo Script

Run the automated demo:
```bash
chmod +x scripts/demo.sh
./scripts/demo.sh
```

## Manual Demo Steps

### 1. Show Architecture & Components

```bash
# Show all deployed components
kubectl -n secureagentops get pods,svc,deploy

# Show namespace overview
kubectl -n secureagentops get all
```

**Talking Points:**
- Security Gatekeeper: Validates agents before deployment
- Customer Support Agent: Example GenAI agent being protected
- Prometheus/Grafana: Real-time monitoring and metrics
- Zero-Trust Policy Engine: Enforces security policies

### 2. Demonstrate Security Scanning

```bash
# Get gatekeeper pod
GATEKEEPER_POD=$(kubectl -n secureagentops get pod -l app=security-gatekeeper -o jsonpath='{.items[0].metadata.name}')

# Port-forward
kubectl -n secureagentops port-forward $GATEKEEPER_POD 8080:8080 &

# Test health
curl http://localhost:8080/health

# Scan an agent
curl -X POST http://localhost:8080/api/v1/scan \
  -H "Content-Type: application/json" \
  -d '{
    "agent_path": "/tmp",
    "agent_id": "demo-agent",
    "agent_version": "1.0.0"
  }'
```

**Talking Points:**
- Automatic security scanning of agent code
- Detection of vulnerabilities, hardcoded secrets, injection risks
- Real-time results with severity classification

### 3. Show Policy-Based Gates

```bash
# Evaluate policies
curl -X POST http://localhost:8080/api/v1/policy/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": "demo-agent",
    "scan_results": {
      "summary": {
        "critical": 0,
        "high": 1,
        "medium": 2,
        "low": 0
      }
    }
  }'
```

**Talking Points:**
- Zero-Trust policies block deployments with critical issues
- Configurable thresholds for high/medium/low severity
- Automatic pass/fail decisions based on security posture

### 4. Show Real-time Metrics

```bash
# View Prometheus metrics
curl http://localhost:8080/metrics | grep secureagentops

# Or access Prometheus UI
PROM_POD=$(kubectl -n secureagentops get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
kubectl -n secureagentops port-forward $PROM_POD 9090:9090
# Open http://localhost:9090
```

**Talking Points:**
- Real-time security metrics
- Track scanning activities, policy violations, agent health
- Integration with Prometheus/Grafana for dashboards

### 5. Show Monitoring Dashboard

```bash
# Access Grafana
GRAFANA_POD=$(kubectl -n secureagentops get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
kubectl -n secureagentops port-forward $GRAFANA_POD 3000:3000
# Open http://localhost:3000 (admin/admin)
```

**Talking Points:**
- Visual dashboards for security posture
- Historical trends and analytics
- Alerting on security events

### 6. Complete Workflow Demo

```bash
# 1. Create a test agent with vulnerabilities
kubectl -n secureagentops exec $GATEKEEPER_POD -- bash -c 'cat > /tmp/test-agent/bad_code.py <<EOF
import os
password = "secret123"  # Hardcoded credential
os.system(f"rm -rf /tmp")  # Dangerous system call
EOF'

# 2. Scan it
curl -X POST http://localhost:8080/api/v1/scan \
  -H "Content-Type: application/json" \
  -d '{
    "agent_path": "/tmp/test-agent",
    "agent_id": "vulnerable-agent",
    "agent_version": "1.0.0"
  }' | jq .

# 3. Show it would be blocked
curl -X POST http://localhost:8080/api/v1/policy/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": "vulnerable-agent",
    "scan_results": {
      "summary": {
        "critical": 2,
        "high": 1,
        "medium": 0,
        "low": 0
      }
    }
  }' | jq .
```

## Demo Scenarios

### Scenario 1: Clean Agent (Passes)
Show an agent with no critical issues that passes all policies.

### Scenario 2: Vulnerable Agent (Blocked)
Show an agent with critical security issues that gets blocked.

### Scenario 3: Warning Agent (Passes with Warnings)
Show an agent with high-severity issues that passes but generates warnings.

## Key Features to Highlight

1. **Automatic Security Scanning**
   - Code analysis
   - Dependency scanning
   - Prompt injection detection
   - Configuration validation

2. **Zero-Trust Policies**
   - Block critical issues
   - Warn on high-severity issues
   - Configurable thresholds
   - Policy-as-code

3. **Real-time Monitoring**
   - Security metrics
   - Agent health tracking
   - Policy violation alerts
   - Historical analytics

4. **Integration Ready**
   - REST API for CI/CD integration
   - Kubernetes native
   - Prometheus/Grafana compatible
   - Scalable architecture

## Presentation Slides Outline

1. **Introduction** (2 min)
   - Problem: Securing GenAI agents at scale
   - Solution: Zero-Trust DevSecOps framework

2. **Architecture** (3 min)
   - Components overview
   - Data flow
   - Security model

3. **Live Demo** (5 min)
   - Security scanning
   - Policy evaluation
   - Metrics dashboard

4. **Use Cases** (3 min)
   - CI/CD integration
   - Pre-deployment validation
   - Continuous monitoring

5. **Q&A** (2 min)

## Troubleshooting Demo Issues

**Gatekeeper not responding:**
```bash
kubectl -n secureagentops logs -l app=security-gatekeeper --tail=50
```

**Pods not running:**
```bash
kubectl -n secureagentops describe pod <pod-name>
kubectl -n secureagentops get events --sort-by='.lastTimestamp'
```

**Port-forward issues:**
```bash
# Kill existing port-forwards
pkill -f port-forward

# Start fresh
kubectl -n secureagentops port-forward <pod> <port>:8080
```

## Additional Resources

- Architecture diagrams: `docs/`
- API documentation: Check `/api/v1/docs` endpoint (if Swagger enabled)
- Configuration: `k8s/gatekeeper.yaml`
- Policies: `k8s/gatekeeper.yaml` (ConfigMap section)


