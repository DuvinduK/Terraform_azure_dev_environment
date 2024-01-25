# data "azurerm_virtual_network" "mtc-vn" {
#   name                = "mtc-network"
#   resource_group_name = azurerm_resource_group.mtc-rg.name
# }

# resource "azurerm_subnet" "mtc-subnet_3" {
#   name                 = "mtc-subnet_3"
#   resource_group_name  = azurerm_resource_group.mtc-rg.name
#   virtual_network_name = azurerm_virtual_network.mtc-vn.name
#   address_prefixes     = ["10.0.2.0/24"]
#   }

