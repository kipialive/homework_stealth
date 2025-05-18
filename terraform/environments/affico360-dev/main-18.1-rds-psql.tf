/*
###### ###### ###### ###### ###### 
### Amazon RDS for PostgreSQL ###
###### ###### ###### ###### ###### 

Based on source:: https://github.com/terraform-aws-modules/terraform-aws-rds
# example # https://github.com/terraform-aws-modules/terraform-aws-rds/blob/master/examples/complete-postgres/main.tf

# Strapi CMS - Manage Any Content of your site (Content Management System) #

## Recommendations After installation PostgreSQL ##
Automated backups::	        Enable automated backups.	
Enhanced monitoring off::   Enhanced Monitoring is not enabled on your DB instance. We recommend enabling Enhanced Monitoring.
Multi az instance::	        We recommend that you use Multi-AZ deployment. The Multi-AZ deployments enhance the availability and durability of the DB instance. Click Info for more details about Multi-AZ deployment and pricing.	
Performance insights off::	Performance Insights is not enabled on your DB instance. We recommend enabling Performance Insights.
*/

# /*
### This part tested, and work OK !!! ###

locals {
  db_identifier_name_psql         = "psql-strapi-cms-${var.env_name_short}"
  database_subnet_group_name_psql = "psql-database"
}

# # Example: https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/main.tf
# resource "aws_db_subnet_group" "postgresql-database" {
#   name        = lower(coalesce(local.database_subnet_group_name_psql, local.db_identifier_name_psql))
#   description = "Database subnet group for ${local.db_identifier_name_psql}"
#   subnet_ids  = module.create-private-subnets["psql-private"].private_subnets

#   tags = merge(
#     {
#       "Name" = lower(coalesce(local.database_subnet_group_name_psql, local.db_identifier_name_psql))
#     },
#     local.tags,
#   )
# }


# Based on source:: https://github.com/terraform-aws-modules/terraform-aws-rds/blob/master/modules/db_subnet_group/main.tf
module "creates_RDS_PSQL_DB_subnet_group" {
  source = "terraform-aws-modules/rds/aws//modules/db_subnet_group"

  # count = length(module.create-private-subnets["psql-private"].private_subnets) > 0 ? 1 : 0

  name            = lower(coalesce(local.database_subnet_group_name_psql, local.db_identifier_name_psql))
  use_name_prefix = false
  description     = "Database subnet group for ${local.db_identifier_name_psql}"
  subnet_ids      = module.create-private-subnets["psql-private"].private_subnets

  tags = local.tags

  depends_on = [
    module.create-private-subnets["psql-private"]
  ]
}

### Comment Start Here ### /*
module "psql-strapi-cms" {
  source = "terraform-aws-modules/rds/aws"
  version = "6.1.1"

  identifier                     = "${local.db_identifier_name_psql}"
  instance_use_identifier_prefix = false

  create_db_option_group    = false
  create_db_parameter_group = false

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "12.17"
  family               = "postgres12" # DB parameter group
  major_engine_version = "12"         # DB option group
  instance_class       = "db.m6g.large" # vCPU: 2, RAM: 8GB, Network: 4750Mbps

  allocated_storage = 20
  max_allocated_storage = 100

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "postgres" # "StrapiCMSPostgresql"
  username = "postgres" # "strapi_cms_postgresql"
  password = "password"
  port     = 5432

  multi_az               = false
  db_subnet_group_name   = module.creates_RDS_PSQL_DB_subnet_group.db_subnet_group_id # this is from example above --> aws_db_subnet_group.postgresql-database.name
  vpc_security_group_ids = [module.psql-security-group.security_group_id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 0

  tags = merge(
    {
        Name = local.db_identifier_name_psql
    },
    local.tags,
  )

  depends_on = [
    module.create-private-subnets["psql-private"]
  ]
}

################################################################################
# Supporting Resources
################################################################################

# Based on source:: https://github.com/terraform-aws-modules/terraform-aws-security-group
# example # https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/examples/complete/main.tf

# Define the security group for PostgreSQL (RDS Service)
module "psql-security-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = ">= 5.1.0"

  name        = "${local.db_identifier_name_psql}-sg"
  description = "Strapi CMS PostgreSQL security group"
  vpc_id      = module.vpc.vpc_id

  use_name_prefix = false

  # ingress :: Open to CIDRs blocks (rule or from_port+to_port+protocol+description)
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = var.vpc_cidr
    },
  ]

  tags = local.tags
}
### Comment End Here ### */