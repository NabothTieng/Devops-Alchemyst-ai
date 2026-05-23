# DevOps Assignment — Alchemyst AI

**Candidate:** Naboth Tieng  
**Submission Date:** May 2026  
**Contact:** nabothtieng@gmail.com

---
## Walkthrough Video

A full walkthrough of the deployment process — including CloudFormation stack creation, UserData boot logs, SSH access across the VMs, and the blockers encountered — is available here:

<a href="https://drive.google.com/file/d/1ThMBmQ1mwMzHr9Vp7I3kt9NRtBgwV4g5/view?usp=sharing" target="_blank">Watch the walkthrough on Google Drive</a>

---
## Architecture Overview

This project deploys the [iii quickstart](https://iii.dev/docs/quickstart) across **3 EC2 instances** in AWS using a secure VPC architecture with full infrastructure-as-code via CloudFormation.

### Infrastructure

| VM | Subnet | Role |
|----|--------|------|
| `api-gateway-vm` | Public (10.0.1.0/24) | iii Engine + iii-http (JSON API front door) |
| `math-worker-vm` | Private (10.0.2.0/24) | Python math worker — connects to engine via WebSocket |
| `caller-worker-vm` | Private (10.0.3.0/24) | TypeScript caller worker — connects to engine via WebSocket |

### Architecture Diagram

```
                          Internet
                              │
                         Port 3111 (HTTP)
                              ↓
                 ┌──────────────────────────┐
                 │   Public Subnet          │
                 │   api-gateway-vm         │
                 │                          │
                 │   iii Engine             │
                 │   ws://0.0.0.0:49134     │
                 │   iii-http :3111         │
                 └────────────┬─────────────┘
                              │ VPC Private Network
                              │ WebSocket (port 49134)
               ┌──────────────┴───────────────┐
               │                              │
   ┌───────────▼───────────┐     ┌────────────▼──────────┐
   │  Private Subnet       │     │  Private Subnet       │
   │  math-worker-vm       │     │  caller-worker-vm     │
   │                       │     │                       │
   │  Python math-worker   │     │  TypeScript           │
   │  III_URL=ws://        │     │  caller-worker        │
   │  <engine-private-ip>  │     │  III_URL=ws://        │
   │  :49134               │     │  <engine-private-ip>  │
   │                       │     │  :49134               │
   └───────────────────────┘     └───────────────────────┘

  Workers initiate outbound WebSocket connections to the engine.
  No inbound rules required on private VMs for worker traffic.
  Port 49134 on the public VM is restricted to 10.0.0.0/16 (VPC only).
```

### How the Request Flow Works

1. A client sends `POST /v1/chat/completions` to the public IP on port 3111
2. `iii-http` (running on the engine) receives the request and dispatches it to `caller-worker` via RPC over the internal WebSocket mesh
3. `caller-worker` (on the private caller VM) calls `math-worker` via `math::add` RPC through the same engine mesh
4. `math-worker` (on the private math VM) computes the result and returns it through the engine
5. The result travels back through the chain and is returned as JSON to the client

---

## Key Technical Decisions & Findings

### iii SDK not available on PyPI — Expired SSL Certificate

During setup we attempted `pip install iii-sdk==0.11.0` and found the package is hosted on `pypi.iii.dev`, which had an **expired SSL certificate** at the time of this assignment. Standard pip installation failed with an SSL verification error. We worked around this using `--trusted-host pypi.iii.dev` which bypasses certificate verification for that specific index only. This is scoped narrowly — it does not disable SSL verification globally.

### KVM Unavailable on t3.micro

The `iii-worker` binary uses microVM sandboxing (libkrun) to isolate each worker process, which requires `/dev/kvm`. AWS t3.micro instances run on shared hardware without nested virtualisation, so KVM is unavailable. We resolved this with `III_ISOLATION=none` in each worker's systemd environment, which instructs iii-worker to run the worker process directly without a microVM wrapper. This is a supported mode for environments where KVM is not available.

### torch and gguf Removed from requirements.txt

The original `math-worker` includes `torch`, `gguf`, and `transformers` for running `gemma-3-270m`. These packages require approximately 4GB of RAM to install and run, which exceeds the t3.micro's 1GB. They were removed from `requirements.txt` for this deployment. The worker architecture is fully operational — restoring these packages on a larger instance type (e.g. `g4dn.xlarge`) would enable real model inference.

### Source Repository

The quickstart was cloned directly from the [Alchemyst AI hiring repo](https://github.com/Alchemyst-ai/hiring/tree/main/may-2026/devops/quickstart) using `git sparse-checkout` rather than `iii project init`. Using the repo directly ensures the exact worker code specified in the assignment brief is used.

---

## Prerequisites — Do This Before Deploying

### Create an EC2 Key Pair (manual step — required once)

CloudFormation cannot create key pairs on your behalf. You must do this manually before deploying the stack.

1. Open the AWS Console and navigate to **EC2 → Network & Security → Key Pairs**
2. Click **Create key pair**
3. Fill in:
   - **Name:** `devops-intern-key`
   - **Key pair type:** RSA
   - **File format:** `.pem`
4. Click **Create key pair**
5. The `.pem` file downloads automatically — save it safely, you will need it to SSH

---

## Deploying the Stack

### Step 1 — Clone this repo

```bash
git clone https://github.com/NabothTieng/Devops-Alchemyst-ai.git
cd Devops-Alchemyst-ai
```

### Step 2 — Open CloudFormation

1. In the AWS Console search for **CloudFormation** and open it
2. Click **Create stack** → **With new resources (standard)**
3. Under **Specify template** select **Upload a template file**
4. Click **Choose file** and upload `infrastructure/cloudformation/stack.yaml`
5. Click **Next**

### Step 3 — Stack Details

- **Stack name:** `alchemyst-devops-stack`
- **KeyName:** Select `devops-intern-key`
- Click **Next**

### Step 4 — Configure Stack Options

Leave everything as default and click **Next**

### Step 5 — Review & Create

Scroll to the bottom and click **Submit**

### Step 6 — Wait for completion

The stack takes approximately **10–15 minutes** to reach `CREATE_COMPLETE`. The UserData scripts install iii, clone the quickstart, configure systemd services, and start everything. Do not test the API until the stack shows `CREATE_COMPLETE`.

---

## Getting the IPs (CloudFormation Outputs)

Once the stack shows `CREATE_COMPLETE`:

1. Click on the stack name in the CloudFormation console
2. Click the **Outputs** tab

You will see:

| Key | Description |
|-----|-------------|
| `APIGatewayPublicIP` | Public IP of the engine VM — use this for curl and SSH |
| `APIGatewayPrivateIP` | Private IP of the engine — injected into worker VMs at boot |
| `MathWorkerPrivateIP` | Private IP of the math-worker VM |
| `CallerWorkerPrivateIP` | Private IP of the caller-worker VM |
| `TestCommand` | Ready-to-run curl command pre-filled with the public IP |

---

## Testing the JSON API

Copy the `TestCommand` value from the Outputs tab, or run:

```bash
curl -X POST http://<APIGatewayPublicIP>:3111/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "What is 2+2?"}]}'
```

### Expected Response

```json
{
  "c": 4,
  "running_total": 4
}
```

### API Schema

| Field | Type | Description |
|-------|------|-------------|
| `messages` | array | Array of message objects |
| `messages[].role` | string | `"user"` or `"assistant"` |
| `messages[].content` | string | The message content |

---

## SSH Access

### Into the public API Gateway VM

```bash
ssh -i devops-intern-key.pem ec2-user@<APIGatewayPublicIP>
```
Ensure that you copy the key pair to this cloned repo for this code to function or replace this with the relevant paths 

### Into private VMs (via jump host)

Private VMs have no public IP. SSH into the public VM first, then jump across.

```bash
# Copy your key to the public VM
scp -i devops-intern-key.pem devops-intern-key.pem ec2-user@<APIGatewayPublicIP>:~/.ssh/

# SSH into the public VM
ssh -i devops-intern-key.pem ec2-user@<APIGatewayPublicIP>

# Fix permissions then jump to a private VM
chmod 600 ~/.ssh/devops-intern-key.pem
ssh -i ~/.ssh/devops-intern-key.pem ec2-user@<MathWorkerPrivateIP>
# or
ssh -i ~/.ssh/devops-intern-key.pem ec2-user@<CallerWorkerPrivateIP>
```

Private IPs are available in the CloudFormation **Outputs** tab.

---

## Checking Service Status

### On the API Gateway VM

```bash
ssh -i devops-intern-key.pem ec2-user@<APIGatewayPublicIP>
sudo systemctl status iii-engine
sudo journalctl -u iii-engine -n 50 --no-pager
```

### On the math-worker VM (after jumping through the public VM)

```bash
sudo systemctl status math-worker
sudo journalctl -u math-worker -n 50 --no-pager
```

### On the caller-worker VM

```bash
sudo systemctl status caller-worker
sudo journalctl -u caller-worker -n 50 --no-pager
```

### Checking worker registration from the engine

On the API Gateway VM:

```bash
sudo su -
iii worker list
```

A healthy output looks like:

```
NAME             STATUS
math-worker      running
caller-worker    running
iii-http         running
iii-state        running
```

### Checking UserData boot logs (if something did not start)

```bash
sudo cat /var/log/userdata.log
```

---

## Tearing Down

The cleanest way to destroy all resources is via CloudFormation:

1. Go to **AWS Console → CloudFormation**
2. Select `alchemyst-devops-stack`
3. Click **Delete**
4. Confirm deletion

This automatically removes all EC2 instances, VPC, subnets, security groups, NAT gateway, Elastic IPs, and route tables.

---

## Project Structure

```
Devops-Alchemyst-ai/
├── infrastructure/
│   └── WRITEUP.md         # Production hardening, scaling for a 100× larger model, and key project challenges faced.
│   │
│   └── cloudformation/
│       └── stack.yaml     # Full IaC — deploy everything from here
└── README.md              # This file
```

---

## Known Limitations

- **No model inference:** `torch`, `gguf`, and `transformers` were removed from `requirements.txt` due to RAM constraints on t3.micro. The distributed worker architecture is intact. Restore the original `requirements.txt` on a larger instance (e.g. `g4dn.xlarge`) to enable real `gemma-3-270m` inference.
- **KVM unavailable on t3.micro:** `III_ISOLATION=none` is set on both worker VMs. On metal or dedicated instances remove this to restore full per-worker microVM isolation.
- **pypi.iii.dev SSL:** The iii Python SDK index had an expired certificate during deployment. `--trusted-host pypi.iii.dev` is used as a workaround in the math-worker UserData.
