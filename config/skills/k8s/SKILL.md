---
name: k8s
description: Kubernetes operations - kubectl, pods, deployments, namespaces, cluster troubleshooting, helm.
argument-hint: [cluster] [namespace] [resource]
allowed-tools: Bash(kubectl get *), Bash(kubectl logs *), Bash(kubectl describe *), Bash(kubectl config *), Bash(kubectl top *), Bash(helm template *), Bash(helm list *), Bash(helm status *), Read, Grep, Glob
---

# Kubernetes Operations

## Current Context
!`kubectl config current-context 2>/dev/null || echo "No context set"`

## Quick Commands

```bash
# Context management
kubectl config get-contexts
kubectl config use-context <name>
kubectl config current-context

# Namespace operations
kubectl get pods -n <ns>
kubectl logs -f deployment/<name> -n <ns> --tail=100
kubectl describe pod <pod> -n <ns>
kubectl rollout restart deployment/<name> -n <ns>

# Get pod by app label
kubectl get pods -n <ns> -l app=<app> -o jsonpath='{.items[0].metadata.name}'

# Exec into pod
kubectl exec -it -n <ns> deployment/<name> -- /bin/sh
```

## Service Exec Patterns

```bash
# Generic pattern
NS=<namespace> && APP=<app-label>
kubectl exec -n $NS $(kubectl get pods -n $NS -l app=$APP -o jsonpath='{.items[0].metadata.name}') -- <command>

# OpenSearch
kubectl exec -n $NS $(kubectl get pods -n $NS -l app=opensearch -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:9200/_cluster/health

# Redis
kubectl exec -n $NS $(kubectl get pods -n $NS -l app=redis -o jsonpath='{.items[0].metadata.name}') -- redis-cli -a '<password>' ping

# RabbitMQ
kubectl exec -n $NS $(kubectl get pods -n $NS -l app=rabbitmq -o jsonpath='{.items[0].metadata.name}') -- rabbitmqctl list_queues name messages

# PostgreSQL
kubectl exec -n $NS $(kubectl get pods -n $NS -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres -c "SELECT 1"
```

## Prometheus / Monitoring

If Prometheus is deployed (typically in a `monitoring` namespace):

```bash
PROM=http://prometheus-server.monitoring.svc.cluster.local:80

# Query from a pod (Go pods often have wget but not curl)
kubectl exec -n $NS $POD -- wget -qO- "$PROM/api/v1/query?query=up"

# Common PromQL queries:
# CPU rate by pod:    sum(rate(container_cpu_usage_seconds_total{namespace="$NS",container!=""}[1h]))by(pod)
# Memory by pod:      sum(container_memory_working_set_bytes{namespace="$NS",container!=""})by(pod)
# Network rx by pod:  sum(rate(container_network_receive_bytes_total{namespace="$NS"}[1h]))by(pod)
# Network tx by pod:  sum(rate(container_network_transmit_bytes_total{namespace="$NS"}[1h]))by(pod)
```

URL-encode PromQL when passing via wget/curl query params.

## Troubleshooting

### Pod Issues
```bash
# CrashLoopBackOff - check previous logs
kubectl logs <pod> -n <ns> --previous

# OOMKilled - check resource limits
kubectl describe pod <pod> -n <ns> | grep -A5 "Last State"

# ImagePullBackOff - check image name
kubectl describe pod <pod> -n <ns> | grep -A5 "Events"
```

### ConfigMap Operations
```bash
kubectl get configmap <name> -n <ns> -o yaml
kubectl patch configmap <name> -n <ns> --type merge -p '{"data":{"KEY":"value"}}'
kubectl rollout restart deployment/<name> -n <ns>
```
