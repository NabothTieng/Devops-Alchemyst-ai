#!/bin/bash

# Create full directory structure
mkdir -p infrastructure deployment/systemd diagrams quickstart

# Create placeholder files with basic content
cat > README.md << 'EOL'
# DevOps Internship Assignment - Alchemyst AI

## Architecture Diagram
(See diagrams/architecture.md)

## Quick Start / Redeploy Instructions
(See below)

## Curl Example
(See below)
EOL

cat > WRITEUP.md << 'EOL'
# Production Hardening Write-up

## What I would harden before production:
...

## What I would do differently if the model was 100x larger:
...
EOL

cat > diagrams/architecture.md << 'EOL'
# Architecture Diagram
Internet
↓ (Port 3111)
[Public Subnet] → API-Gateway-VM (Public IP)
├── iii Engine (ws:49134)
└── iii-http worker
Private Network (VPC)
↓ (Private IPs)
┌──────────────────────────────┐
│                              │
Python-Math-VM               TS-Caller-VM
(math-worker)               (caller-worker)
textEOL

# Create infrastructure scripts (placeholders)
touch infrastructure/01-create-vpc.sh
touch infrastructure/02-security-groups.sh
touch infrastructure/03-launch-instances.sh
touch infrastructure/04-deploy-workers.sh
touch infrastructure/teardown.sh

# Deployment scripts
touch deployment/user-data-api.sh
touch deployment/user-data-math.sh
touch deployment/user-data-caller.sh

# Systemd services
touch deployment/systemd/iii-engine.service
touch deployment/systemd/iii-http.service
touch deployment/systemd/math-worker.service
touch deployment/systemd/caller-worker.service

chmod +x infrastructure/*.sh

echo "✅ Project structure created successfully!"
echo "Directory: $(pwd)"
ls -R
