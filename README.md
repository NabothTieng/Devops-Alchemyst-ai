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