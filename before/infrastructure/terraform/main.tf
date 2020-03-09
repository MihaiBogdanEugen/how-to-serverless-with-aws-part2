terraform {
  required_version = "0.12.23"
}

provider aws {
  region  = var.aws_region
  version = "2.52.0"
}
