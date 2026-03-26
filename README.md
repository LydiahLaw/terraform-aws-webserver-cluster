# Module: webserver-cluster

A reusable Terraform module that deploys a web server cluster on AWS. It provisions a launch template, an Auto Scaling Group, an Application Load Balancer, target group, listener, and the security groups needed to wire them together. Deploys into the default VPC in eu-central-1.

---

## Usage
```hcl
module "webserver_cluster" {
  source = "github.com/LydiahLaw/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name  = "webservers-dev"
  instance_type = "t2.micro"
  min_size      = 2
  max_size      = 4
  server_port   = 80
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name prefix for all cluster resources | string | — | yes |
| instance_type | EC2 instance type | string | t2.micro | no |
| min_size | Minimum number of instances in the ASG | number | — | yes |
| max_size | Maximum number of instances in the ASG | number | — | yes |
| server_port | Port the server listens on | number | 8080 | no |
| custom_tag | Custom tag applied to all cluster resources | string | terraform-module | no |

---

## Outputs

| Name | Description |
|------|-------------|
| alb_dns_name | DNS name of the Application Load Balancer |
| asg_name | Name of the Auto Scaling Group |

---

## Known limitations and gotchas

- Do not use relative file paths inside this module — use `path.module` for any file references
- Security group rules use inline blocks — do not mix with standalone `aws_security_group_rule` resources
- Avoid `depends_on` at the module level — reference specific outputs directly instead
- Always pin to a version tag using `?ref=vX.X.X` — never reference without a version