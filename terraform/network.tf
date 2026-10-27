# ==============================================================================
# CAPA DE RED — VPC 10.0.0.0/16 · 3 capas × 2 AZs (RNF-1, D04, Etapa 1 Hito 2)
# ==============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # Necesario para resolver el endpoint DNS de RDS

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name}-igw" }
}

# --- Capa 1: Subredes públicas (ALB + NAT Gateway) ----------------------------
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Nada dentro de esta capa necesita IP pública automática: el ALB y los NAT
  # Gateways reciben su direccionamiento público de forma administrada.
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name}-subnet-public-${local.az_suffix[count.index]}"
    Tier = "public"
  }
}

# --- Capa 2: Subredes privadas de cómputo (EC2 del ASG) -----------------------
resource "aws_subnet" "compute" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.compute_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name}-subnet-compute-${local.az_suffix[count.index]}"
    Tier = "private-compute"
  }
}

# --- Capa 3: Subredes de datos aisladas (RDS Primary / Standby) ---------------
resource "aws_subnet" "data" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name}-subnet-data-${local.az_suffix[count.index]}"
    Tier = "private-data"
  }
}

# --- NAT Gateways (uno por AZ, en la subred pública de su AZ) -----------------
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = { Name = "${local.name}-eip-nat-${local.az_suffix[count.index]}" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${local.name}-nat-${local.az_suffix[count.index]}" }

  depends_on = [aws_internet_gateway.main]
}

# --- Tablas de rutas ----------------------------------------------------------

# Pública: 0.0.0.0/0 -> Internet Gateway (esto es lo que hace "pública" a la subred)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Cómputo: una tabla por AZ, 0.0.0.0/0 -> NAT Gateway de la MISMA AZ
# (si una AZ cae, la otra AZ conserva su salida a Internet)
resource "aws_route_table" "compute" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = { Name = "${local.name}-rt-compute-${local.az_suffix[count.index]}" }
}

resource "aws_route_table_association" "compute" {
  count          = length(aws_subnet.compute)
  subnet_id      = aws_subnet.compute[count.index].id
  route_table_id = aws_route_table.compute[count.index].id
}

# Datos: SOLO la ruta local implícita de la VPC. Cero salida a Internet.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name}-rt-data" }
}

resource "aws_route_table_association" "data" {
  count          = length(aws_subnet.data)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# --- NACL de la capa de datos: solo tráfico interno de la VPC -----------------
resource "aws_network_acl" "data" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.data[*].id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "${local.name}-nacl-data" }
}
