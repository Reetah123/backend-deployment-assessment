# StartupTech Backend Deployment Assessment

This project provisions AWS infrastructure with Terraform and deploys the MuchToDo Go backend with Docker Compose.

## Requirements

- AWS account and AWS CLI configured (`aws sts get-caller-identity`)
- Terraform and Docker installed locally
- Git and an existing EC2 key pair (`.pem` file on your computer)
- Your public IPv4 address (add `/32`)

## 1. Download the backend code

The assessment files are in this repository. The actual Golang application is stored in a github repository.

```bash
git clone --branch feature/backend-only https://github.com/Innocent9712/much-to-do.git
cp -rn much-to-do/Server/MuchToDo/. backend-deployment-assessment/
cd backend-deployment-assessment
```

The `-n` option keeps the assessment's Dockerfile and Compose file if the application repository contains its own versions. The app directory must contain `go.mod`, `go.sum` and `cmd/api/main.go` beside the Dockerfile.

## 2. Test with Docker locally

```bash
cp .env.example .env
# Edit .env and set a random JWT_SECRET_KEY.
docker compose build
docker compose up -d
docker compose ps
curl -i http://localhost:8080/health
```

The MongoDB service uses a Docker volume so its data survives container restarts. Redis caching is disabled because Redis is optional in the supplied app documentation.

## 3. Provision AWS resources

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit region, your actual public IP /32 and existing EC2 key pair name.
terraform fmt
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Save screenshots of `init`, `plan`, `apply`, the VPC, four subnets, security groups, three EC2 instances, and the ALB/target group. The target will initially be unhealthy until the backend is deployed.

## 4. Connect through the Bastion host

From `terraform/`, retrieve the IP addresses:

```bash
terraform output -raw bastion_public_ip
terraform output -raw backend_private_ip
```

On your own computer, use your existing SSH key (substitute the actual IPs):

```bash
chmod 400 ~/.ssh/my-assessment-key.pem
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/my-assessment-key.pem
ssh -J ec2-user@BASTION_PUBLIC_IP ec2-user@BACKEND_PRIVATE_IP
```

On Windows, use Git Bash or an SSH client supporting `ProxyJump`. Do not copy your private key onto the Bastion host.

## 5. Run containers on the Backend EC2

On the backend EC2:

```bash
git clone --branch feature/backend-only https://github.com/Innocent9712/much-to-do.git
cd much-to-do/Server/MuchToDo
```

Copy this assessment repository's Dockerfile, docker-compose.yml and .dockerignore into this directory (using Git clone or SCP from your own submission repo). Then:

```bash
printf 'JWT_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" > .env
sudo docker compose build
sudo docker compose up -d
sudo docker compose ps
curl -i http://localhost:8080/health
```

If `sudo docker compose` is not found, check startup logs using `sudo tail -100 /var/log/cloud-init-output.log` and confirm the plugin was installed using `sudo docker compose version`.

## 6. Test the ALB

From your own computer, retrieve the DNS name:

```bash
cd terraform
terraform output -raw alb_dns_name
curl -i http://YOUR_ALB_DNS_NAME/health
```

The HTTP health check should return `200`, and the target group should become healthy. Capture the ALB URL in your screenshot.

## 7. Screenshots to submit

1. Terraform init
2. Terraform plan
3. Terraform apply completed
4. VPC in AWS
5. Four subnets across two AZs
6. Four security groups and inbound rules
7. Three running EC2 instances
8. ALB and healthy target group
9. Docker image build
10. Local Compose containers running
11. Local /health returning 200
12. SSH connection through Bastion
13. Compose containers running on Backend EC2
14. /health working through ALB DNS

## 8. Cleanup (important: AWS resources cost money)

```bash
# On backend EC2, optional: stop the containers.
sudo docker compose down

# On your computer:
cd terraform
terraform destroy
```

Do this only after saving screenshots and the required state file. The assessment asks for `terraform.tfstate`; treat it as sensitive and do **not** commit it to a public repository. Ask your instructor for a private submission method. Destroying the infrastructure changes the Terraform state, so preserve the requested evidence before cleanup.

## Notes

- Phase 1 requests a separate MongoDB EC2 instance. Phase 2 requests a MongoDB Docker service. Both are included, but the working Docker Compose backend connects to the container called `mongodb`, not to the separate EC2 instance.
- The ALB permits port 443 in the security group as requested, but only port 80 has a listener because no HTTPS certificate was requested.
- NAT Gateway, ALB, EC2 and Elastic IP addresses can generate charges. Destroy resources after testing.
- This assessment does not claim a live AWS deployment until the commands are actually run.

### Bastion Host SSH Access

The Bastion security group allows SSH access on port 22 from two specific public IP addresses because I used two different devices to work on this assessment.

Both IP addresses are configured as `/32` CIDR blocks to restrict access to those addresses rather than allowing SSH access from anywhere (`0.0.0.0/0`).

The backend EC2 instance remains private and only accepts SSH connections from the Bastion security group.