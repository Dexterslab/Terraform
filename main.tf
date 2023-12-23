provider "azurerm" {
  features {}
}

module "azure_vm" {
  source = "./module1"  
}