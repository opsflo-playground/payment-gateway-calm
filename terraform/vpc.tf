# CALM: Implicit network requirement for all infrastructure
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.project_tags, {
    Name = "calm-payment-vpc"
  })
}

# CALM: Implicit network requirement
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.project_tags, {
    Name = "calm-payment-igw"
  })
}

# CALM: Implicit network requirement -> Public subnets for load balancers
resource "aws_subnet" "public" {
  count = length(data.aws_availability_zones.available.names) > 2 ? 2 : length(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.project_tags, {
    Name = "calm-payment-public-subnet-${count.index + 1}"
  })
}

# CALM: Implicit network requirement -> Private subnets for services and databases
resource "aws_subnet" "private" {
  count = length(data.aws_availability_zones.available.names) > 2 ? 2 : length(data.aws_availability_zones.available.names)

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 11}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.project_tags, {
    Name = "calm-payment-private-subnet-${count.index + 1}"
  })
}

# CALM: Implicit network requirement -> EIP for NAT Gateway
resource "aws_eip" "nat_gateway" {
  count = length(aws_subnet.public)
  vpc   = true

  tags = merge(local.project_tags, {
    Name = "calm-payment-nat-eip-${count.index + 1}"
  })
}

# CALM: Implicit network requirement -> NAT Gateway for private subnet outbound access
resource "aws_nat_gateway" "main" {
  count = length(aws_subnet.public)

  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.project_tags, {
    Name = "calm-payment-nat-gateway-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# CALM: Implicit network requirement -> Public route table for internet access
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.project_tags, {
    Name = "calm-payment-public-rt"
  })
}

# CALM: Implicit network requirement -> Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# CALM: Implicit network requirement -> Private route table for NAT access
resource "aws_route_table" "private" {
  count = length(aws_subnet.private)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.project_tags, {
    Name = "calm-payment-private-rt-${count.index + 1}"
  })
}

# CALM: Implicit network requirement -> Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
