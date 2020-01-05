provider "aws" {
 access_key = ""
 secret_key = ""
 region = "us-east-1"
}

/*  

V A R I A B L E

*/
variable "cidr_vpc" {
  description = "CIDR block for the VPC"
  default = "10.0.0.0/16"
}

variable "private_subnet_cidr" {
    description = "CIDR for the Private Subnet"
    default = "10.0.4.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  default = "10.0.0.0/24"
}

variable "vpc_id" {}
data "aws_vpc" "environment_api" {
  id = "${var.vpc_id}"
}


variable "availability_zone" {
  description = "availability zone to create subnet"
  default = "us-east-1b"
}
variable "public_key_path" {
  description = "Public key path"
  default = "~/.ssh/id_rsa.pub"
}
variable "instance_ami" {
  description = "AMI for aws EC2 instance"
  default = "ami-012786b489e635ceb"
}
variable "instance_type" {
  description = "type for aws EC2 instance"
  default = "t2.micro"
}
variable "environment_tag" {
  description = "Environment tag"
  default = "Production"
}

/*

V P C

*/
resource "aws_vpc" "vpcTest" {
  cidr_block = "${var.cidr_vpc}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags {
    "Environment" = "${var.environment_tag}"
    name = "VPC-Terraform"
  }
}

/*

I G W 

*/
resource "aws_internet_gateway" "igw" {
  vpc_id = "${var.vpc_id}"
  tags =  {
    "Environment" = "${var.environment_tag}"

  }
}


/*

  N A T    I n s t a n c e

  */

resource "aws_security_group" "nat" {
    name = "vpc_nat"
    description = "Allow traffic to pass from the private subnet to the internet"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_vpc}"]
    }
    egress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    vpc_id = "${var.vpc_id}"

    tags {
        Name = "NATSG"
    }
}

resource "aws_instance" "nat" {
    
    ami = "{var.instance_ami}" # this is a special ami preconfigured to do NAT
    instance_type = "{var.instance_type}"
    availability_zone = "us-east-1b"
    
    key_name = "${aws_key_pair.ec2key.key_name}"
    vpc_security_group_ids = ["${aws_security_group.nat.id}"]
    subnet_id = "${aws_subnet.subnet_public.id}"
    associate_public_ip_address = true
    source_dest_check = false
    user_data = "${file("install_python.sh")}"


    tags {
        Name = "VPC NAT"
    }
}

resource "aws_eip" "nat" {
    instance = "${aws_instance.nat.id}"
    vpc = true
}




/*

P U B L I C     S U B N E T 

*/
resource "aws_subnet" "subnet_public" {
  vpc_id = "${var.vpc_id}"


  cidr_block = "${var.public_subnet_cidr}"
  map_public_ip_on_launch = "true"
  availability_zone = "${var.availability_zone}"
  tags {
    "Environment" = "${var.environment_tag}"
  }
}
/*

R O U T E   T A B L E

*/
resource "aws_route_table" "rtb_public" {
  vpc_id = "${var.vpc_id}"
route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }
tags {
    "Environment" = "${var.environment_tag}"
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = "${aws_subnet.subnet_public.id}"
  route_table_id = "${aws_route_table.rtb_public.id}"
}

/*

  P R I V A T E     S U B N E T 

*/
resource "aws_subnet" "subnet_private" {
    vpc_id = "${var.vpc_id}"

    cidr_block = "${var.private_subnet_cidr}"
    availability_zone = "us-east-1b"

    tags {
        Name = "Private Subnet"
    }
}

/*
R O U T E   T A B L E 

*/

resource "aws_route_table" "rtb_private" {
    vpc_id = "${var.vpc_id}"

    route {
        cidr_block = "0.0.0.0/0"
        instance_id = "${aws_instance.nat.id}"
    }

    tags {
        Name = "Private Subnet"
    }
}

resource "aws_route_table_association" "rta_subnet_private" {
    subnet_id = "${aws_subnet.subnet_private.id}"
    route_table_id = "${aws_route_table.rtb_private.id}"
}


/*

S E C U R I T Y    G R O U P

*/

resource "aws_security_group" "sg_22" {
  name = "sg_22"
  vpc_id = "${var.vpc_id}"

# SSH access from the VPC
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    "Environment" = "${var.environment_tag}"
  }
}

##Key-Pair to SSH on our EC2
resource "aws_key_pair" "ec2key" {
  key_name = "publicKey"
  public_key = "${file(var.public_key_path)}"
}

/*

E C 2   I N S T A N C E 

*/

resource "aws_instance" "Instance" {
  ami           = "${var.instance_ami}"
  instance_type = "${var.instance_type }"
  subnet_id = "${aws_subnet.subnet_public.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_22.id}"]
  key_name = "${aws_key_pair.ec2key.key_name}"
  

 tags {
  "Environment" = "${var.environment_tag}"
 }
  connection {
    private_key = "${file(var.private_key)}"
    user        = "${var.ansible_user}"
  }

  #user_data = "${file("../templates/install_jenkins.sh")}"

  # Ansible requires Python to be installed on the remote machine as well as the local machine.
  provisioner "remote-exec" {
    inline = ["${file("install_ansible.sh")}"]
  }

  # This is where we configure the instance with ansible-playbook
  # Jenkins requires Java to be installed 
  provisioner "local-exec" {
    command = <<EOT
      sleep 30;
	  >java.ini;
	  echo "[java]" | tee -a java.ini;
	  echo "${aws_instance.jenkins-ci.public_ip} ansible_user=${var.ansible_user} ansible_ssh_private_key_file=${var.private_key}" | tee -a java.ini;
      export ANSIBLE_HOST_KEY_CHECKING=False;
	  ansible-playbook -u ${var.ansible_user} --private-key ${var.private_key} -i java.ini ../playbooks/install_java.yaml
    EOT
  }
  # This is where we configure the instance with ansible-playbook
  provisioner "local-exec" {
    command = <<EOT
      sleep 600;
      >jenkins-ci.ini;
      echo "[jenkins-ci]" | tee -a jenkins-ci.ini;
      echo "${aws_instance.jenkins-ci.public_ip} ansible_user=${var.ansible_user} ansible_ssh_private_key_file=${var.private_key}" | tee -a jenkins-ci.ini;
      export ANSIBLE_HOST_KEY_CHECKING=False;
      ansible-playbook -u ${var.ansible_user} --private-key ${var.private_key} -i jenkins-ci.ini ../playbooks/install_jenkins.yaml
    EOT
  }

  tags {
    Name     = "jenkins-ci-${count.index +1 }"
    Location = "Bangalore"
  }
}

}
