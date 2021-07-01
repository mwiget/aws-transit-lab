# igw.tf
 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.bench_vpc.id
 
  tags = {
    "Name"  = "bench-igw"
  }
}
