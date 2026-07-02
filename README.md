# 🏗️ Automated AWS 3-Tier Architecture via Terraform

A comprehensive, production-ready guide to deploying a Highly Available, Scalable, and Secure 3-Tier Architecture on AWS using Infrastructure as Code (IaC).

---

## 🚀 How to Run and Use This Code

If you want to clone this repository and deploy this infrastructure yourself, follow these quick steps:

### Prerequisites
* An AWS Account with CLI credentials configured.
* Terraform installed locally or using GitHub Codespaces.

### Execution Steps
1. **Clone the Repository:**
   ```bash
   git clone <your-github-repo-link>
   cd aws-3tier-terraform

  Initialize the Project: (Downloads AWS provider plugins)

Bash
terraform init

Review the Blueprint: (Check what resources will be created)

Bash
terraform plan

Deploy to AWS: (Creates the full 3-Tier setup automatically)

Bash
terraform apply --auto-approve

Clean Up / Avoid Billing: (Deletes everything once you are done)

Bash
terraform destroy --auto-approve

🛠️ Project Development Journey: Step-by-Step Execution
Below is the exact chronological sequence of how this project was built, showing what was done, why it was done, and which file was modified at each stage.

🛑 Step 1: Security & Leak Prevention
File Modified: .gitignore

What we did: Added .terraform/, *.tfstate, *.tfstate.backup, and .terraform.lock.hcl to the ignore list.

Why: To prevent sensitive AWS state files, plain-text database passwords, and heavy plugin folders from leaking onto GitHub.

🔌 Step 2: Setting up the Cloud Connector
File Modified: providers.tf

What we did: Defined the required_providers block specifying HashiCorp AWS plugin (version ~> 5.0) and set the deployment region to us-east-1 (N. Virginia).

Why: Terraform needs to know which cloud API to talk to and where to build the data center before executing any code.

🌐 Step 3: Designing the Base Network (VPC)
File Modified: main.tf (Section 1 to 4)

What we did: Created an isolated network (aws_vpc) with a CIDR block of 10.0.0.0/16 (65,536 IPs) and attached an Internet Gateway (aws_internet_gateway).

Why: This establishes a secure, custom virtual perimeter in the cloud where all our servers and databases will live.

🗺️ Step 4: Building Public Subnets & Traffic Routing
File Modified: main.tf (Section 5 to 10)

What we did: Created two Public Subnets in different Availability Zones (us-east-1a and us-east-1b), built a Route Table mapping traffic to the Internet Gateway (0.0.0.0/0), and associated them together.

Why: This ensures High Availability. If one AWS physical data center goes down, the load balancer routes traffic to the second public subnet seamlessly.

⚖️ Step 5: Creating the Traffic Inspector & Firewalls
File Modified: main.tf (Section 11 to 13)

What we did: Created a Security Group (lb_sg) opening Port 80 (HTTP) to the world, deployed an internet-facing Application Load Balancer (ALB) across both public subnets, and configured a Target Group with automated health checks.

Why: To absorb external web traffic and intelligently distribute it only to "Healthy" backend servers, performing auto-healing checks every 20 seconds.

📈 Step 6: Deploying Elastic Compute with Auto-Scaling
File Modified: main.tf (Section 14)

What we did: Created a Launch Template with an Ubuntu AMI specifying an automated bash user-data script (encoded via base64encode) to auto-install Apache. Then, bound it to an Auto Scaling Group (ASG) with a capacity rule of Min: 1, Desired: 2, Max: 3.

Why: To completely automate server provisioning. The system dynamically spins up or terminates EC2 instances depending on traffic spikes without human intervention.

🗄️ Step 7: Isolating the Database Layer (The Final Tier)
File Modified: main.tf (Section 15 to 19)

What we did: Created two strictly Private Subnets with no internet access routes, grouped them using an aws_db_subnet_group, established a tightly restricted firewall (db_sg) allowing incoming traffic only from the web servers on Port 3306, and launched an AWS RDS MySQL Database.

Why: This fulfills the absolute core rule of a 3-Tier Architecture—hiding data away from the public web. Even if someone discovers the database endpoint, it is impenetrable from the outside internet.

🚨 Production Errors Faced & Troubleshooted
As a DevOps Engineer, building is only half the job—debugging is where the real value lies. Here are the critical industry-level blockers encountered and fixed in this project:

Target Group Unhealthy Status (Network Routing Block)

The Problem: Initially, the load balancer could not reach the EC2 instances, marking them unhealthy.

The Fix: Corrected the subnets mapping layout to make the entire design Multi-AZ compliant, ensuring cross-subnet visibility so health checks could pass.

Invalid RDS Subnet Group Name (AWS API Constraints)

The Problem: Attempting to use a name starting with a number (3tier...) threw an invalid parameter error from the AWS API.

The Fix: Refactored the naming convention to a standard clean alphabetical string (dbsubnet), clearing the AWS API regex validation rules.

Bash Interpretation Error on Terminal Testing

The Problem: Running the DB connection string using generic placeholder brackets (< >) caused Linux Bash to misinterpret it as a file redirection operator.

The Fix: Stripped the syntax down to raw text values and executed the command exclusively via SSH inside the public web server instance since direct external DB access is securely blocked.
