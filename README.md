**docker-swarm-using-terraform-ansible**

A node in a swarm cluster is any machine with docker engine installed and capable of hosting containers/services (When we run docker engine under swarm mode we often call applications as services). This is also referred as Docker node. A Docker node can be a physical machine or one or more virtual machines running on a physical host or cloud server. It is recommended to spread your docker nodes across multiple physical machines to provide availability and reliability for the applications running on the hosts. Docker Swarm environment consists of one or more manager nodes. To deploy an application on Docker Swarm we submit a request in the form of service definition to a manager node. Manager node performs orchestration and cluster management functions required to maintain the desired state of the farm. If there are multiple manager nodes in a swarm, the nodes elect a leader to conduct orchestration which implements leader election strategy.

Step-1
In this post we can see how to install Terraform and how to setup the AWS account for working ahead. After installing Terraform and setting up AWS account go to the next step.
NOTE: You need to create and download a key-pair using aws management console. Mine is : docker-key.pem

Step-2
Create a directory named swarm-deploy. create three files named variable.tf, security-groups.tf, main.tf and output.tf. In variable.tf file add the following

```
### variable.tf
variable "aws_region" {
  description = "AWS region on which we will setup the swarm cluster"
  default = "eu-west-1"
}
variable "ami" {
  description = "Amazon Linux AMI"
  default = "ami-04d10c7d"
}
variable "instance_type" {
  description = "Instance type"
  default = "t2.micro"
}
variable "key_path" {
  description = "SSH Public Key path"
  default = "/path-to-keyfile/docker-key.pem"
}
variable "key_name" {
  description = "Desired name of Keypair..."
  default = "docker-key"
}
variable "bootstrap_path" {
  description = "Script to install Docker Engine"
  default = "install_docker_machine_compose.sh"
}
```

In this file I’m using region eu-west-1 and Ubuntu-16.04 amazon machine image. You can set yours… :)
In security-groups.tf file add the following

```
### security-groups.tf
resource "aws_security_group" "sgswarm" {
  name = "sgswarm"
  tags {
        Name = "sgswarm"
  }
# Allow all inbound
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
# Enable ICMP
  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

In main.tf add the following

```
### main.tf
# Specify the provider and access details
provider "aws" {
  access_key = "your-aws-access-key"
  secret_key = "your-aws-secret-access-key"
  region = "${var.aws_region}"
}
resource "aws_instance" "master" {
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  user_data = "${file("${var.bootstrap_path}")}"
  vpc_security_group_ids = ["${aws_security_group.sgswarm.id}"]
tags {
    Name  = "master"
  }
}
resource "aws_instance" "worker1" {
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  user_data = "${file("${var.bootstrap_path}")}"
  vpc_security_group_ids = ["${aws_security_group.sgswarm.id}"]
tags {
    Name  = "worker 1"
  }
}
resource "aws_instance" "worker2" {
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  user_data = "${file("${var.bootstrap_path}")}"
  vpc_security_group_ids = ["${aws_security_group.sgswarm.id}"]
tags {
    Name  = "worker 2"
  }
}
```

In output.tf file add the following

```
### output.tf
output "master_public_ip" {
    value = ["${aws_instance.master.public_ip}"]
}
output "worker1_public_ip" {
    value = ["${aws_instance.worker1.public_ip}"]
}
output "worker2_public_ip" {
    value = ["${aws_instance.worker2.public_ip}"]
}
```

Step-3
Create a shell script named install_docker_machine_compose.sh which will install docker. This script will execute in the provision time of EC2…

```
#!/bin/bash
export LC_ALL=C
sudo apt-get update -y
#sudo apt-get upgrade -y
### install python-minimal
sudo apt-get install python-minimal -y
# install docker-engine
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
echo "Docker installed..."
sudo usermod -aG docker ${whoami}
sudo systemctl enable docker
sudo systemctl start docker
echo "########################################"
echo "########################################"
echo "##################### install docker-compose ########################"
sudo curl -L https://github.com/docker/compose/releases/download/1.16.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
echo "docker-compose installed..."
echo "########################################"
echo "########################################"
echo "#################### install docker-machine #########################"
curl -L https://github.com/docker/machine/releases/download/v0.12.2/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine
chmod +x /tmp/docker-machine
sudo cp /tmp/docker-machine /usr/local/bin/docker-machine
echo "docker-machine installed..."
```

Step-4
Install Ansible

```
$ sudo apt-add-repository ppa:ansible/ansible
Press ENTER to accept the PPA addition.
$ sudo apt-get update
$ sudo apt-get install ansible
```

Step-5
There are a couple of ways of setting up a swarm cluster. You can create a cluster using any virtualized environments like Hyper-V, virtual box. The number of hosts running in a swarm cluster will be restricted to the host’s CPU and memory capacity. Traditionally on premise environments are setup using multiple physical nodes. The second way of setting up swarm environment is by using hosted environments like Azure or AWS.

We’ll create ansible script for creating swarm cluster(a manager node and two worker nodes). Create a file named playbook.yml in the same swarm-deploy directory and add the following

```
### playbook.yml
---
  - name: Init Swarm Master
    hosts: masters
    become: true
    gather_facts: False
    remote_user: ubuntu
    tasks:
      - name: Swarm Init
        command: sudo usermod -aG docker {{remote_user}}
        command: docker swarm init --advertise-addr {{ inventory_hostname }}
- name: Get Worker Token
        command: docker swarm join-token worker -q
        register: worker_token
- name: Show Worker Token
        debug: var=worker_token.stdout
- name: Master Token
        command: docker swarm join-token manager -q
        register: master_token
- name: Show Master Token
        debug: var=master_token.stdout
- name: Join Swarm Cluster
    hosts: workers
    become: true
    remote_user: ubuntu
    gather_facts: False
    vars:
      token: "{{ hostvars[groups['masters'][0]]['worker_token']['stdout'] }}"
      master: "{{ hostvars[groups['masters'][0]]['inventory_hostname'] }}"
    tasks:
      - name: Join Swarm Cluster as a Worker
        command: sudo usermod -aG docker {{remote_user}}
        command: sudo docker swarm join --token {{ token }} {{ master }}:2377
        register: worker
- name: Show Results
        debug: var=worker.stdout
- name: Show Errors
        debug: var=worker.stderr
```
        
        
Create a directory named inventory and a file named hosts under inventory folder. Change the public ip and key-file-path which you’ll get after running the terraform apply command.

```
[masters]
52.51.138.1 ansible_user=ubuntu ansible_private_key_file=/path-to-your-keyfile/docker-key.pem
[workers]
34.240.19.111 ansible_user=ubuntu ansible_private_key_file=/path-to-your-keyfile/docker-key.pem
52.208.83.236 ansible_user=ubuntu ansible_private_key_file=/path-to-your-keyfile/docker-key.pem
```


Step-6
All the configuration files and scripts are now set. Run the following commands to deploy three instances using terraform and to create swarm cluser using ansible in those intances.

```
$ terraform init
$ terraform plan
$ terraform apply
```
```
$ ansible-playbook -i inventory/hosts playbook.yml
```

Our swarm cluster is ready. Let’s check the cluster using ssh in manager node.

```
$ ssh -i your_key_file.pem ubuntu@manager_public_ip

$ sudo docker node ls
```

That’s all.
