---
name: env-check
description: Validate environment setup, check dependencies, configs, connections, troubleshoot setup issues.
allowed-tools: Read, Grep, Glob
---

# Environment Check

## Current Environment
!`echo "Node: $(node -v 2>/dev/null || echo 'not installed')"`
!`echo "Java: $(java -version 2>&1 | head -1 || echo 'not installed')"`
!`echo "Python: $(python3 --version 2>/dev/null || python --version 2>/dev/null || echo 'not installed')"`
!`echo "Go: $(go version 2>/dev/null || echo 'not installed')"`
!`echo "Docker: $(docker --version 2>/dev/null || echo 'not installed')"`
!`echo "kubectl: $(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' || echo 'not installed')"`

## Quick Checks

### 1. CLI Tools
```bash
# Required for most projects
docker --version
docker-compose --version
git --version
kubectl version --client

# GitHub CLI
gh --version

# Java projects
java -version
./mvnw --version

# Python projects
python3 --version  # macOS/Linux
python --version   # Windows
pip --version

# Node projects
node --version
npm --version

# Go projects
go version
```

### 2. Docker Services
```bash
# Check running containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check if infrastructure is up
docker-compose ps
```

### 3. Kubernetes Context
```bash
# Current context
kubectl config current-context

# Available contexts
kubectl config get-contexts

# Test connection
kubectl cluster-info
```

### 4. Network Connectivity
```bash
# GitHub
curl -s -o /dev/null -w "%{http_code}" https://github.com/

# VPN check (if applicable to your network)
scutil --nc list                          # macOS — list all VPN connections
ipconfig                                  # Windows
```

---

## Project-Specific Checks

Adapt to the repo you're in. Common patterns:

### Java/Spring service
```bash
cd <workspace>/<service>

# Check submodules
git submodule status

# Java version
java -version

# Run tests
./mvnw test
```

### Python/FastAPI service
```bash
cd <workspace>/<service>

# Python version
python3 --version  # macOS/Linux
python --version   # Windows

# Venv
<workspace>/py/venv/bin/python --version
```

### Go service
```bash
cd <workspace>/<service>

# Go version
go version

# Build
go build ./...
```

### Node/Next.js frontend
```bash
cd <workspace>/<service>

# Node version
node -v

# Install
npm install
```

---

## Common Issues

### VPN Not Connected
```
Symptom: Cannot reach internal git host
Fix: Connect to your VPN
Check (macOS): scutil --nc list
Check (Windows): ipconfig
```

### Wrong Java Version
```
Symptom: Unsupported class file major version
Fix: Install required Java version
Check: java -version
macOS: brew install openjdk@17
Windows: winget install Microsoft.OpenJDK.17
```

### Node Version Mismatch
```
Symptom: npm install fails
Fix: Use nvm to switch versions
Check: node -v
macOS/Linux: nvm use 18
Windows: nvm use 18 (using nvm-windows)
```

### Docker Not Running
```
Symptom: Cannot connect to Docker daemon
Fix: Start Docker Desktop
Check: docker ps
```

### kubectl Context Wrong
```
Symptom: Resources not found
Fix: Switch context
Check: kubectl config current-context
Fix: kubectl config use-context <name>
```

---

## Full Environment Validation

```bash
#!/bin/bash
echo "=== Environment Check ==="

# Tools
echo -e "\n--- CLI Tools ---"
for cmd in git docker docker-compose kubectl gh java node python go jq; do
  if command -v $cmd &> /dev/null; then
    echo "OK $cmd installed"
  else
    echo "MISSING $cmd NOT FOUND"
  fi
done

# Versions
echo -e "\n--- Versions ---"
java -version 2>&1 | head -1
node -v
python3 --version 2>/dev/null || python --version 2>/dev/null
go version 2>/dev/null || echo "Go not installed"

# Docker
echo -e "\n--- Docker ---"
docker ps --format "{{.Names}}: {{.Status}}" 2>/dev/null || echo "Docker not running"

# Kubernetes
echo -e "\n--- Kubernetes ---"
kubectl config current-context 2>/dev/null || echo "No kubectl context"

# Network
echo -e "\n--- Network ---"
curl -s -o /dev/null -w "GitHub: %{http_code}\n" --max-time 5 https://github.com/ || echo "GitHub: unreachable"

echo -e "\n=== Done ==="
```
