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
