# MuchTodo Backend Deployment

AltSchool Cloud Engineering assessment — StartupTech

This repository contains my Terraform and Docker setup for deploying the **MuchTodo API** on EC2. The API is a Go application provided in the [MuchTodo repository](https://github.com/Innocent9712/much-to-do/tree/feature/backend-only).

I provisioned the infrastructure with Terraform, built the backend image on my laptop, pushed it to Docker Hub, and ran it with MongoDB on a private EC2 instance. The API is reachable through an Application Load Balancer (ALB).

## Repository structure

```text
backend-deployment-assessment/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── user_data/
│       ├── backend_setup.sh
│       └── mongodb_setup.sh
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── .env.example
├── .gitignore
├── evidence/
└── README.md
```

Terraform's lock file may also be present. I have not included my `.env`, actual `terraform.tfvars`, Terraform state or SSH private key in this repository.

## Infrastructure

The Terraform configuration creates:

- A VPC (`10.0.0.0/16`) with two public and two private subnets across two Availability Zones
- Internet Gateway, NAT Gateway and route tables
- Bastion EC2 in a public subnet
- Backend EC2 and MongoDB EC2 in private subnets
- Security groups restricting SSH, backend and database access
- A public Application Load Balancer forwarding HTTP requests to the backend on port `8080`, with a `/health` target-group check

The separate MongoDB EC2 instance is part of the infrastructure requirements. **The running Docker deployment uses its own MongoDB container.
### Provisioning

Install Terraform and configure AWS credentials first. From the `terraform/` directory:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: region, instance sizes, allowed SSH IPs and key-pair name
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
```

I reviewed the plan before applying it, particularly when updating the Bastion's allowed SSH IPs, to avoid replacing existing resources unintentionally.

## Docker image

I kept the developers' code in a separate clone. The two repositories are sibling directories on my laptop:

```text
cloud engineering second semester/
├── much-to-do/
│   └── Server/MuchToDo/       # Go application source
└── backend-deployment-assessment/  # My Docker and Terraform files
```

Clone the application branch if needed:

```bash
git clone -b feature/backend-only https://github.com/Innocent9712/much-to-do.git
```

From the **common parent directory**, build the backend image using my Dockerfile and the developers' Go source as the build context:

```bash
docker build --platform linux/amd64 \
  -f backend-deployment-assessment/Dockerfile \
  -t muchtodo-api:v1 \
  much-to-do/Server/MuchToDo
```

I built for `linux/amd64` because the Backend EC2 is a `t3.micro`. The Dockerfile uses a multi-stage Go build and runs the final application as a non-root user on port `8080`.

I then published the image to Docker Hub:

```bash
docker tag muchtodo-api:v1 reetahtee/muchtodo-api:v1
docker login
docker push reetahtee/muchtodo-api:v1
```

Published image: [`reetahtee/muchtodo-api:v1`](https://hub.docker.com/r/reetahtee/muchtodo-api)

## Docker Compose

The `docker-compose.yml` uses the published backend image and `mongo:7`. It also defines a persistent MongoDB volume, a shared network, restart policies and a MongoDB health check. The backend starts after MongoDB reports healthy.

I left Redis disabled because it is optional for the API and not needed for this deployment.

### Environment configuration

Create a local `.env` file in the assessment directory. The `.env.example` contains the JWT secret placeholder; the actual file needs these values:

```dotenv
PORT=8080
MONGO_URI=mongodb://mongodb:27017
DB_NAME=much_todo_db
JWT_SECRET_KEY=REPLACE_WITH_A_RANDOM_SECRET
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=false
LOG_LEVEL=INFO
LOG_FORMAT=json
```

Generate a secret with `openssl rand -hex 32` (or another secure random generator). Do not commit the real `.env` file.

The backend reads `/app/.env`, so Compose mounts the file read-only at that path. The image runs as a non-root user; on Linux, the mounted file must be readable by that user. On EC2 I adjusted the file's group permissions rather than making it world-readable.

### Local test

From `backend-deployment-assessment/`:

```bash
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps
curl -i http://localhost:8080/health
```

Both the backend and MongoDB reported healthy, and `/health` returned HTTP `200 OK`.

## Deployment to EC2

I connected from my laptop to the private Backend EC2 through the Bastion host using my locally generated SSH private key:

```bash
ssh -i ~/.ssh/my-assessment-key \
  -o "ProxyCommand=ssh -i ~/.ssh/my-assessment-key -W %h:%p ec2-user@52.51.162.116 \
  ec2-user@10.0.3.88
```

The private key stays on my laptop. The Bastion security group allows SSH only from the public IP addresses configured in Terraform.

To meet the assessment's cloning requirement, I cloned the developers' repository on the Backend EC2. I also cloned this assessment repository there. The developers' clone was left unchanged; **the running backend comes from Docker Hub**, not an EC2 source-code build.

```bash
cd ~
git clone -b feature/backend-only https://github.com/Innocent9712/much-to-do.git
git clone https://github.com/Reetah123/backend-deployment-assessment.git
```

I created a private `.env` file in `~/backend-deployment-assessment` with the same settings used locally and a newly generated JWT secret. Then I deployed with:

```bash
cd ~/backend-deployment-assessment
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps
curl -i http://localhost:8080/health
```

Because the published image is used, the EC2 instance does not need to compile the Go application. Both containers became healthy after correcting read access to the mounted `.env` file.

### ALB verification

I retrieved the ALB DNS name with `terraform output` and tested the API from my laptop:

```bash
curl -i http://startuptech-alb-1249897388.eu-west-1.elb.amazonaws.com/health
```

The endpoint returned HTTP `200 OK` through the ALB. The ALB uses HTTP on port `80`; HTTPS/TLS is not configured in this assessment.

## Evidence

The `evidence/` folder contains the assessment screenshots, including Terraform initialization, plan and apply, AWS resources, Docker image build, healthy local containers, local health response, Bastion SSH access, healthy containers on EC2 and the successful ALB health request.

## Cleanup

To stop the containers without deleting MongoDB's named volume:

```bash
docker compose down
```

When the AWS environment is no longer needed, review a destroy plan before removing it:

```bash
cd terraform
terraform plan -destroy
terraform destroy
```

EC2, NAT Gateway, ALB and public IPv4 resources can incur charges while running. Terraform state is kept out of the public repository because it can contain sensitive infrastructure details.
