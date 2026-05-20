# DevOps Internship Assignment - Alchemyst AI

**Name:** Naboth Tieng  
**Submission Date:** May 2026

## Architecture Overview

This project deploys the [iii quickstart](https://iii.dev/docs/quickstart) across **3 EC2 instances** in AWS using a secure VPC architecture:

- **Public VM** (API Gateway): Runs `iii Engine` + `iii-http`
- **Private VM 1**: Runs `Python Math Worker`
- **Private VM 2**: Runs `TypeScript Caller Worker`

All workers communicate via **RPC (WebSocket)** over the **private network** (port 49134). Only the API Gateway is exposed to the internet.

### Architecture Diagram

```ascii
                     Internet
                         |
                    Port 3111 (HTTP)
                         ↓
               [ Public Subnet ]
                   API-Gateway VM (Public IP)
                   ├── iii Engine (ws://*:49134)
                   └── iii-http worker

                         │
               Private Network (VPC)
                         │
          ┌────────────────────────────────┐
          │                                │
   Python-Math-VM                   TS-Caller-VM
   (math-worker)                   (caller-worker)
          │                                │
          └──────────────RPC (WebSocket)───┘
```

## How to Redeploy (From Scratch)

Clone this repo:

```bash
git clone https://github.com/NabothTieng/Devops-Alchemyst-ai.git
cd Devops-Alchemyst-ai
```

Then follow these steps:

1. Follow infrastructure/ scripts (or use AWS Console in sandbox)
2. Run deployment scripts on each VM
3. Test with curl command below

## Testing the JSON API

```bash
curl -X POST http://<PUBLIC-IP>:3111/math/add_two_numbers \
  -H "Content-Type: application/json" \
  -d '{"a": 15, "b": 27}'
```

### Expected Response

```json
{
  "result": 42
}
```

## Project Structure

- `infrastructure/` → AWS setup scripts
- `deployment/` → User data & systemd services
- `diagrams/` → Architecture
- `quickstart/` → iii framework

Infrastructure is defined as code using AWS CloudFormation (infrastructure/cloudformation/stack.yaml)

1. How to Clean Up (Destroy) Everything
The easiest and cleanest way to tear down all resources is by deleting the CloudFormation stack. This will automatically delete the EC2 instances, VPC, subnets, security groups, etc.
How to Delete the Stack:

Go to AWS Console → CloudFormation
Select your stack (e.g. alchemyst-devops-stack)
Click Delete
Confirm deletion

→ This is the "tear down" button we will document in the README.


Steps i have done so far when setting it up
1. opened te aws console
2. Step 1: Create Key Pair (Do this first)

In the AWS Console, search for EC2 and open it.
In the left menu, under network and security click Key Pairs.
Click Create key pair on the right it is a orange button.
enter the below details
Name: devops-intern-key
Key pair type: RSA
File format: .pem
Click Create key pair.
Download the .pem file and save it safely (you'll need it to SSH later).


3. Step 2: Launch the CloudFormation Stack

In the AWS Console, search for CloudFormation and open it.
Click Create stack to the right it is a drop down → press With new resources (standard).
Choose an existing template
Select Upload a template file.
Click Choose file and upload this file from your repo:
infrastructure/cloudformation/stack.yaml
Click Next.

4. Step 3: Stack Details

Stack name: alchemyst-devops-stack
KeyName: Select devops-intern-key (the one created manually )
Click Next

5. Step 4: Configure Stack Options

Leave everything default .
Click Next.


6. Step 5: Review & Create

Scroll to the bottom and check the box:
Click submit stack.

7. Before testing, let's confirm where you are. Did the stack update complete successfully (showing UPDATE_COMPLETE)?
If yes, go to CloudFormation → alchemyst-devops-stack → Outputs tab and share what you see there. We need the APIGatewayPublicIP and the TestCommand values.
Then the test is just one curl:
bashcurl -X POST http://<APIGatewayPublicIP>:3111/math/add_two_numbers \
  -H "Content-Type: application/json" \
  -d '{"a": 15, "b": 27}'
