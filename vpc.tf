# create a VPC
resource "aws_vpc" "bench_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  assign_generated_ipv6_cidr_block = true
  tags = {
    Name = "tf-bench-vpc"
  }
}

# create subnets
resource "aws_subnet" "bench_mgmt" {
  vpc_id            = aws_vpc.bench_vpc.id
  cidr_block        = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2a"
  ipv6_cidr_block = cidrsubnet(aws_vpc.bench_vpc.ipv6_cidr_block, 8, 1)
  assign_ipv6_address_on_creation = true

  tags = {
    Name = "tf-bench-mgmt"
  }
}
resource "aws_subnet" "bench_subnet1" {
  vpc_id            = aws_vpc.bench_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "tf-bench-subnet1"
  }
}
