variable "aws_region" {
  description = "AWS region on which we will setup the swarm cluster"
  default = "ap-south-1"
}

variable "ami" {
  description = "Amazon Linux AMI"
  default = "ami-8da8d2e2"
}

variable "instance_type" {
  description = "Instance type"
  default = "t2.micro"
}

variable "key_path" {
  description = "SSH Public Key path"
  default = "/home/ratul/developments/devops/keyfile/ec2-core-app.pem"
}

variable "key_name" {
  description = "Desired name of Keypair..."
  default = "ec2-core-app"
}

variable "bootstrap_path" {
  description = "Script to install Docker Engine"
  default = "install_docker_machine_compose.sh"
}
