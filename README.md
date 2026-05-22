# DevOps Internship Assignment — Alchemyst AI

**Candidate:** Naboth Tieng  
**Submission Date:** May 2026  
**Contact:** nabothtieng@gmail.com

---

## Architecture Overview

This project deploys the [iii quickstart](https://iii.dev/docs/quickstart) across **3 EC2 instances** in AWS using a secure VPC architecture with full infrastructure-as-code via CloudFormation.

### Infrastructure

| VM | Subnet | Role |
|----|--------|------|
| `api-gateway-vm` | Public (10.0.1.0/24) | iii Engine + iii-http + both workers (Docker) |
| `math-worker-vm` | Private (10.0.2.0/24) | Reserved — see note below |
| `caller-worker-vm` | Private (10.0.3.0/24) | Reserved — see note below |

**Note on worker placement:** During deployment we discovered that `iii-worker` requires KVM/microVM support to sandbox worker processes. AWS t3.micro instances do not support nested virtualisation, so `/dev/kvm` is unavailable. We bypassed this using `III_ISOLATION=none`, which runs workers as direct processes inside Docker instead of inside microVMs. Both workers (`math-worker` and `caller-worker`) therefore run inside the Docker container on the public API Gateway VM. The private VMs are provisioned and networked correctly — they can host workers on any KVM-capable instance type (e.g. metal or dedicated).

### Architecture Diagram

```
                        Internet
                            |
                       Port 3111 (HTTP)
                            ↓
                  [ Public Subnet 10.0.1.0/24 ]
                      api-gateway-vm (Public IP)
                      Docker Container:
                      ├── iii Engine       (ws://0.0.0.0:49134)
                      ├── iii-http worker  (HTTP 0.0.0.0:3111)
                      ├── math-worker      (Python)
                      └── caller-worker    (TypeScript)

                            │
               VPC Private Network (NAT Gateway)
                            │
          ┌─────────────────────────────────────┐
          │                                     │
   [ Private Subnet 10.0.2.0/24 ]    [ Private Subnet 10.0.3.0/24 ]
      math-worker-vm                     caller-worker-vm
      (reserved)                         (reserved)
```

---

## Key Technical Decisions & Findings

### iii SDK not available on PyPI

During setup we attempted `pip install iii-sdk==0.11.0` and discovered the package is hosted on `pypi.iii.dev`, which had an **expired SSL certificate** at the time of this assignment. This made it impossible to install the Python SDK via pip directly. As a result we pivoted away from running workers as bare Python processes and used `iii project generate-docker` instead, which packages everything inside a Docker container where the SDK is installed by the iii toolchain itself.

### iii Worker Sandboxing Requires KVM

The `iii-worker` binary uses microVM sandboxing (libkrun) to isolate each worker process. This requires `/dev/kvm` to be present on the host. AWS t3.micro instances run on shared hardware without nested virtualisation support, so KVM is not available. We resolved this by setting `III_ISOLATION=none` in the Docker environment, which instructs iii to run worker processes directly without a microVM wrapper. This is documented by iii as a supported deployment mode for environments where KVM is unavailable.

### Source Repository

The assignment specifies using the quickstart from the [Alchemyst AI hiring repo](https://github.com/Alchemyst-ai/hiring/tree/main/may-2026/devops/quickstart) rather than `iii project init`. We use `git sparse-checkout` to pull only the relevant subdirectory.

---

## Prerequisites — Do This Before Deploying

### 1. Create an EC2 Key Pair (manual step — required once)

CloudFormation cannot create key pairs on your behalf. You must do this manually before deploying the stack.

1. Open the AWS Console and navigate to **EC2 → Network & Security → Key Pairs**
2. Click **Create key pair**
3. Fill in the details:
   - **Name:** `devops-intern-key`
   - **Key pair type:** RSA
   - **File format:** `.pem`
4. Click **Create key pair**
5. The `.pem` file will download automatically — **save it somewhere safe**, you will need it to SSH into the instances

---

## Deploying the Stack

### Step 1 — Clone this repo

```bash
git clone https://github.com/NabothTieng/Devops-Alchemyst-ai.git
cd Devops-Alchemyst-ai
```

### Step 2 — Open CloudFormation

1. In the AWS Console, search for **CloudFormation** and open it
2. Click **Create stack** → **With new resources (standard)**
3. Under **Specify template**, select **Upload a template file**
4. Click **Choose file** and upload: `infrastructure/cloudformation/stack.yaml`
5. Click **Next**

### Step 3 — Stack Details

- **Stack name:** `alchemyst-devops-stack`
- **KeyName:** Select `devops-intern-key` (the one you created above)
- Click **Next**

### Step 4 — Configure Stack Options

Leave everything as default and click **Next**

### Step 5 — Review & Create

Scroll to the bottom and click **Submit**

### Step 6 — Wait for completion

The stack takes approximately **10–15 minutes** to fully deploy. The UserData scripts on the API Gateway VM install Docker, build the container image, and start all services. Wait for the stack status to show `CREATE_COMPLETE` before testing.

---

## Checking the Outputs

Once the stack shows `CREATE_COMPLETE`:

1. Click on the stack name (`alchemyst-devops-stack`)
2. Click the **Outputs** tab
3. You will see:

| Key | Description |
|-----|-------------|
| `APIGatewayPublicIP` | The public IP to hit with curl |
| `APIGatewayPrivateIP` | The engine's private IP within the VPC |
| `TestCommand` | Ready-to-run curl command |

---

## Testing the JSON API

Use the `TestCommand` value from the Outputs tab, or run:

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
| `messages[].content` | string | The message text |

---

## SSH Access

### Into the public API Gateway VM

```bash
ssh -i devops-intern-key.pem ec2-user@<APIGatewayPublicIP>
```

### Into private VMs (via jump host)

```bash
# First, copy your key to the public VM
scp -i devops-intern-key.pem devops-intern-key.pem ec2-user@<APIGatewayPublicIP>:~/.ssh/

# SSH into the public VM
ssh -i devops-intern-key.pem ec2-user@<APIGatewayPublicIP>

# From inside, fix permissions and jump to a private VM
chmod 600 ~/.ssh/devops-intern-key.pem
ssh -i ~/.ssh/devops-intern-key.pem ec2-user@<PrivateIP>
```

---

## Checking Service Status (on the API Gateway VM)

```bash
sudo su -

# Check if Docker container is running
docker ps

# Check iii worker status
docker exec quickstart-iii-1 iii worker list

# View live logs
docker logs -f quickstart-iii-1

# View specific worker logs
docker exec quickstart-iii-1 iii worker logs math-worker
docker exec quickstart-iii-1 iii worker logs caller-worker
```

---

## Tearing Down

The cleanest way to destroy all resources is via CloudFormation:

1. Go to **AWS Console → CloudFormation**
2. Select `alchemyst-devops-stack`
3. Click **Delete**
4. Confirm deletion

This removes all EC2 instances, VPC, subnets, security groups, NAT gateway, and Elastic IPs automatically.

---

## Project Structure

```
Devops-Alchemyst-ai/
├── infrastructure/
│   └── cloudformation/
│       └── stack.yaml          # Full IaC — deploy everything from here
├── README.md                   # This file
```

---

## Known Limitations

- **No GPU / model inference:** The original quickstart uses `gemma-3-270m` via `torch` and `gguf`. These packages require ~4GB RAM to install and run, which exceeds t3.micro's 1GB. The `torch` and `gguf` dependencies were removed from `requirements.txt`. The worker architecture is fully functional; swap in a larger instance and restore the original `requirements.txt` to enable real model inference.
- **KVM unavailable on t3.micro:** `III_ISOLATION=none` is set as a workaround. On metal or dedicated instances, remove this env var to restore full microVM isolation per worker.
- **Workers co-located:** Due to the KVM constraint both workers run inside a single Docker container on the public VM. The VPC and private subnet infrastructure is in place for future distributed deployment.
