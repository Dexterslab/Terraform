provider "azurerm" {
  features {}
}

module "create_vms" {
  source = "./aws"  
}