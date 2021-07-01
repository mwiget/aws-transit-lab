# rt.tf

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.bench_vpc.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }
 
  tags = {
    "Name"  = "bench-rt"
  }
}

resource "aws_route_table_association" "rt_subnet_asso" {
  subnet_id      = aws_subnet.bench_mgmt.id
  route_table_id = aws_route_table.rt.id
}
