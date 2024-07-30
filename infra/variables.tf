variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnet" {
  default = "10.0.0.0/24"
}

variable "private_subnet" {
  default = "10.0.1.0/24"
}

variable "ami" {
  default = "ami-0427090fd1714168b"
}

variable "instance_type" {
  default = "t2.micro"
}

