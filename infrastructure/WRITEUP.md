
# Production Hardening & Scaling Write-up

## Submission Note

I am submitting this assignment with the infrastructure fully provisioned and the iii engine running, but the end-to-end API call not yet confirmed working due to time constraints. The CloudFormation stack deploys all three EC2 instances across the correct subnets, the engine starts on the public VM, and both worker VMs boot with systemd services configured to connect back to the engine via WebSocket. The blockers I hit — an expired SSL certificate on `pypi.iii.dev` making the Python SDK uninstallable via pip, and KVM being unavailable on t3.micro preventing iii's microVM sandboxing — are documented in the README and worked around in the CloudFormation UserData using `--trusted-host pypi.iii.dev` and `III_ISOLATION=none` respectively.

One thing I am reasonably proud of is how the infrastructure and software provisioning are handled entirely inside the CloudFormation template using UserData bash scripts. There is no manual SSH step required after the stack is created — every dependency installation, config file write, systemd service registration, and service start happens automatically at boot time on each instance. The engine's private IP is injected into the worker VMs at deploy time using CloudFormation's `!Sub` with a two-argument map (`EngineIP: !GetAtt APIGatewayInstance.PrivateIp`), so the WebSocket URL each worker connects to is resolved by CloudFormation before the instance even boots.

---

## What I Would Harden Before Putting This in Production

**IAM and access control.** Right now the EC2 instances have no IAM instance profiles attached. In production I would assign least-privilege IAM roles so instances can pull secrets from AWS Secrets Manager instead of having any credentials hardcoded or passed through environment variables in UserData.

**Secrets management.** Any API keys, database passwords, or sensitive config should come from Secrets Manager or Parameter Store, not from the CloudFormation template or environment variables that land in instance metadata.

**Rate limiting and idempotency on the API.** The iii-http worker exposes a raw HTTP endpoint with no rate limiting. I would put an API Gateway (the AWS managed one, not our EC2) or an ALB with WAF in front of it to handle rate limiting, DDoS protection, and request throttling. For the inference endpoint specifically, idempotency matters — if a client retries a request the result should be the same and we should not double-count state like `running_total`.

**CloudWatch monitoring and alerting.** I would set up CloudWatch agent on each instance to ship system logs and application logs, set alarms on CPU, memory, and network metrics, and use CloudWatch Log Insights to query across all three VMs from one place. This is the natural choice on AWS and does not require setting up separate monitoring infrastructure.

**Security groups tightened further.** Port 22 is currently open to `0.0.0.0/0` on the public VM. In production I would restrict SSH to a specific CIDR (a VPN or bastion host IP range) or use AWS Systems Manager Session Manager entirely and remove the SSH inbound rule.

**HTTPS on port 3111.** The API currently serves plain HTTP. I would put an Application Load Balancer with an ACM certificate in front and terminate TLS at the ALB.

---

## What I Would Do Differently if the Model Were 100x Larger

The current setup runs the math worker on a t3.micro which is fine for simple arithmetic. A model 100x larger changes the constraints significantly.

The first thing I would change is the compute. A model that size needs a GPU instance — something in the `g4dn` or `g5` family depending on the model size and throughput requirements. The `torch` and `gguf` dependencies I had to strip out for t3.micro would be restored, and the instance would need enough RAM to load the model weights without swapping.

The second thing I would reconsider is whether EC2 is even the right substrate for the inference worker. For a simple stateless inference function, AWS Lambda with a container image (Lambda supports images up to 10GB) could replace the always-on inference VM and only charges for actual invocations. This would significantly reduce cost if inference requests are sporadic rather than continuous. The iii caller-worker would stay as-is — it is lightweight TypeScript and costs almost nothing to run — and would simply call a Lambda endpoint instead of the Python worker directly.

If the model is too large for Lambda's memory limits or the latency requirements are strict, I would look at keeping the GPU EC2 instance but adding a caching layer (ElastiCache for Redis) in front of it to serve repeated identical prompts from cache rather than re-running inference every time.

For scaling under load I would put the inference worker behind an Auto Scaling Group and an internal load balancer so new GPU instances can spin up when the queue depth grows. The iii engine's WebSocket mesh means additional worker instances register themselves automatically — no config changes needed on the engine side.