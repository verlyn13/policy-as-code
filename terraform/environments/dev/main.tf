terraform {
  required_version = ">= 1.13.2"
  
  backend "local" {
    path = "terraform.tfstate"
  }
}

module "naming_standards" {
  source = "../../modules/naming-standards"
  
  resource_abbreviation = "hcs"
  workload_name        = "platform"
  environment          = "dev"
  region_code          = "hel1"
  instance_number      = 1
}

module "tagging_policy" {
  source = "../../modules/tagging-policy"
  
  owner_email           = "platform@verlyn13.com"
  cost_center          = "CC0001"
  environment          = "dev"
  application_id       = "PAC001"
  data_classification  = "internal"
  project_code         = "PAC"
  backup_required      = true
  compliance_requirements = ["SOC2", "ISO27001"]
  sla_percentage       = "99.5"
}