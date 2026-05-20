# Production Hardening & Scaling Write-up

## What I would harden before putting this in production:

1. **Security**
   - Enable IAM Instance Profiles with least privilege
   - Use AWS Secrets Manager for any sensitive config
   - Enable VPC Flow Logs and CloudWatch monitoring
   - Set up WAF in front of the API Gateway
   - Regular security patching and automated updates

2. **Reliability**
   - Use Auto Scaling Groups + Load Balancer
   - Implement health checks and proper retry logic for RPC
   - Add circuit breakers for worker communication
   - Set up proper logging (ELK or CloudWatch Logs)

3. **Observability**
   - Distributed tracing (OpenTelemetry)
   - Metrics collection (Prometheus + Grafana)

4. **Cost & Performance**
   - Use proper instance sizing based on load
   - Consider containerization (ECS/Fargate) for better density

## What I would do differently if the model were 100x larger:

- Move from CPU-only t3.micro to GPU instances (g4dn/g5)
- Use Amazon SageMaker for model hosting and scaling
- Implement model sharding or distributed inference
- Add caching layer (Redis) for frequent inferences
- Use spot instances + proper auto-scaling policies
- Consider serverless options (Lambda + SageMaker endpoints) where possible
- Introduce model warmup and batching for better throughput

This assignment helped me understand VPC networking, private service communication, and production-grade deployment patterns.
