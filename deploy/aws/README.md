# AWS Deployment (ECS Fargate)

This repo includes a workflow to build a Docker image, push to Amazon ECR, and deploy to an ECS Fargate service behind an ALB, using domain api.careridesolutionspa.com in us-east-1.

## Prereqs you provide
- AWS Account ID (e.g., 726591790830) and region us-east-1
- ECR repository name for backend (e.g., care-ride-backend)
- ECS Cluster and Service names
- VPC subnets + a security group for the service (or use default VPC)
- SSM Parameter Store names for:
  - SPRING_DATASOURCE_URL
  - SPRING_DATASOURCE_USERNAME
  - SPRING_DATASOURCE_PASSWORD
  - JWT_SECRET

Note: We use an ECS Task Role for SES. No static AWS keys are needed in the container.

## SES setup (production)
1) Move SES out of sandbox in us-east-1
- In SES Console → Account dashboard → Request production access. Fill expected sending use and domain.

2) Enable Easy DKIM for careridesolutionspa.com
- SES → Verified identities → Add/Select domain careridesolutionspa.com → Enable Easy DKIM (RSA_2048).
- SES will show 3 CNAME records. In Route53 hosted zone careridesolutionspa.com, create those CNAMEs exactly as shown.
- Wait for SES status to change to Verified. DKIM should show Enabled.

3) From/notify email
- We send from contact@careridesolutionspa.com by default. Ensure this mailbox exists or is routed, and DMARC policy is acceptable for your domain.

## TLS certificate (ACM) for api.careridesolutionspa.com
1) In us-east-1 ACM, request a public certificate for api.careridesolutionspa.com
- Choose DNS validation. ACM will show a CNAME. In Route53, create that CNAME record. Validation will complete in a few minutes.

## Networking and load balancer
1) Create or pick a VPC with at least two public subnets in us-east-1a/b (or private subnets + NAT if preferred).
2) Create an Application Load Balancer (ALB)
- Internet-facing, attach to your subnets.
- Security group: allow inbound 80/443 from 0.0.0.0/0.
- Create a target group (IP target type) on port 8080 with health check path /api/ping.
- Create listeners:
  - 80 → redirect to 443
  - 443 (HTTPS) with ACM cert for api.careridesolutionspa.com → forward to the target group

Example (from your setup):
- ALB name: care-ride-alb
- ALB ARN: arn:aws:elasticloadbalancing:us-east-1:726591790830:loadbalancer/app/care-ride-alb/388b95bf08cb328a
- Hosted zone ID: Z35SXDOTRQX7K
- DNS name: care-ride-alb-1303652544.us-east-1.elb.amazonaws.com
- VPC: vpc-0e6b7d604e243af77
- Subnets: subnet-032f78779da41220c, subnet-05c02aeb4aaea18a4
- Current listener: HTTP :80 → forward to target group care-ride-api-tg (add HTTPS :443 with ACM cert next)

## ECS roles and permissions
- Execution role (ecsTaskExecutionRole):
  - Policies: AmazonECSTaskExecutionRolePolicy, CloudWatchLogsFullAccess (or logs:CreateLogStream/PutLogEvents), AmazonEC2ContainerRegistryReadOnly

- Task role (ecsTaskRole) attached to your task definition:
  - Minimal policy for SES and SSM:

  Example policy JSON:

  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        "Resource": "arn:aws:ssm:us-east-1:ACCOUNT_ID:parameter/*"
      }
    ]
  }

Replace ACCOUNT_ID with your AWS Account ID.

## One-time AWS setup
1) Create an ECR repository. Note its URI: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/REPO
2) Create an ECS Cluster (Fargate) in us-east-1.
3) Create a CloudWatch Logs log group: /ecs/care-ride-backend
4) Put app secrets in SSM Parameter Store as plain String parameters (not SecureString):
   SPRING_DATASOURCE_URL, SPRING_DATASOURCE_USERNAME, SPRING_DATASOURCE_PASSWORD, JWT_SECRET
5) Create the ECS Task Execution Role and Task Role from above, and note their ARNs.

## Configure GitHub Secrets
In this repo → Settings → Secrets and variables → Actions:
- AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (for GitHub Action to deploy)
- AWS_REGION = us-east-1
- ECR_REPOSITORY = care-ride-solutions
- ECS_CLUSTER = care-ride-solutions-cluster
- ECS_SERVICE = care-ride-solutions

## Task definition
Edit deploy/aws/taskdef.json:
- Set executionRoleArn and taskRoleArn to your role ARNs
- Replace ACCOUNT_ID in SSM ARNs; REGION is fixed to us-east-1
- Image will be injected by the workflow
- No AWS access keys are referenced; SES credentials come from the Task Role

## Create the ECS service
- Launch service using the task definition family care-ride-backend, desired count 1+, awsvpc networking, attach the service to this ALB target group:
  - Target group name: care-ride-api-tg
  - Target group ARN: arn:aws:elasticloadbalancing:us-east-1:726591790830:targetgroup/care-ride-api-tg/f65f323487c75b33
- Health check should pass at /api/ping.

## Route53 DNS
- In the careridesolutionspa.com hosted zone, create/replace A record for api.careridesolutionspa.com as an Alias to the ALB DNS name.
- Wait for propagation. Test https://api.careridesolutionspa.com/api/ping
  - Alias target: care-ride-alb-1303652544.us-east-1.elb.amazonaws.com (Hosted zone ID Z35SXDOTRQX7K)

## Deploy
- GitHub → Actions → backend: deploy to AWS ECS → Run workflow
- Optionally set imageTag; otherwise the commit SHA is used.

## Health and logs
- Container checks /api/ping
- Logs in CloudWatch Logs group /ecs/care-ride-backend

## Notes
- App listens on 8080; ALB terminates TLS and forwards to 8080.
- SES uses the HTTP API via AWS SDK; region us-east-1. From-email contact@careridesolutionspa.com.
- Frontend can call https://api.careridesolutionspa.com via the same domain CORS policy.
