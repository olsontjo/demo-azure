provider "azurerm" {
  client_id       = "${var.azurerm_client_id}"
  client_secret   = "${var.azurerm_client_secret}"
  subscription_id = "${var.azurerm_subscription_id}"
  tenant_id       = "${var.azurerm_tenant_id}"
}

resource "azurerm_resource_group" "demo" {
  name     = "demo-resource-group"
  location = "${var.azurerm_location}"
}

resource "azurerm_virtual_network" "demo" {
  name          = "demo-virtual-network"
  address_space = ["10.0.0.0/16"]
  location      = "${var.azurerm_location}"

  resource_group_name = "${azurerm_resource_group.demo.name}"
}

resource "azurerm_subnet" "demo" {
  name                 = "demo-subnet"
  resource_group_name  = "${azurerm_resource_group.demo.name}"
  virtual_network_name = "${azurerm_virtual_network.demo.name}"
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_public_ip" "demo" {
  name                         = "demo-public-ip"
  location                     = "${var.azurerm_location}"
  resource_group_name          = "${azurerm_resource_group.demo.name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_network_interface" "demo" {
  count               = "${var.azurerm_instances}"
  name                = "demo-interface-${count.index}"
  location            = "${var.azurerm_location}"
  resource_group_name = "${azurerm_resource_group.demo.name}"

  ip_configuration {
    name                                    = "demo-ip-${count.index}"
    subnet_id                               = "${azurerm_subnet.demo.id}"
    private_ip_address_allocation           = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.demo.id}"]
  }
}

resource "azurerm_lb" "demo" {
  name                = "demo-lb"
  location            = "${var.azurerm_location}"
  resource_group_name = "${azurerm_resource_group.demo.name}"

  frontend_ip_configuration {
    name                          = "default"
    public_ip_address_id          = "${azurerm_public_ip.demo.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_lb_rule" "demo" {
  name                    = "demo-lb-rule-80-80"
  resource_group_name     = "${azurerm_resource_group.demo.name}"
  loadbalancer_id         = "${azurerm_lb.demo.id}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.demo.id}"
  probe_id                = "${azurerm_lb_probe.demo.id}"

  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "default"

  // TODO: https://github.com/hashicorp/terraform/issues/12183
  // frontend_ip_configuration_name = "${lookup(element(azurerm_lb.demo.frontend_ip_configuration, 0), "name")}"
  // frontend_ip_configuration_name = "${lookup(azurerm_lb.demo.frontend_ip_configuration[0], "name")}"
}

resource "azurerm_lb_probe" "demo" {
  name                = "demo-lb-probe-80-up"
  loadbalancer_id     = "${azurerm_lb.demo.id}"
  resource_group_name = "${azurerm_resource_group.demo.name}"
  protocol            = "Http"
  request_path        = "/"
  port                = 80
}

resource "azurerm_lb_backend_address_pool" "demo" {
  name                = "demo-lb-pool"
  resource_group_name = "${azurerm_resource_group.demo.name}"
  loadbalancer_id     = "${azurerm_lb.demo.id}"
}

resource "azurerm_availability_set" "demo" {
  name                = "demo-availability-set"
  location            = "${var.azurerm_location}"
  resource_group_name = "${azurerm_resource_group.demo.name}"
}

# Generate a random_id for the account name. Storage account names must be
# unique across the entire scope of Azure. Here we are generating a random hex
# value of length 8 (4*2) that is prefixed with the static string "demo". For
# example: "demo3d1b9d47".
resource "random_id" "storage_account" {
  prefix      = "demo"
  byte_length = "4"
}

resource "azurerm_storage_account" "demo" {
  name                = "${lower(random_id.storage_account.hex)}"
  resource_group_name = "${azurerm_resource_group.demo.name}"
  location            = "${var.azurerm_location}"
  account_type        = "Standard_LRS"
}

resource "azurerm_storage_container" "demo" {
  count                 = "${var.azurerm_instances}"
  name                  = "demo-storage-container-${count.index}"
  resource_group_name   = "${azurerm_resource_group.demo.name}"
  storage_account_name  = "${azurerm_storage_account.demo.name}"
  container_access_type = "private"
}

resource "azurerm_virtual_machine" "demo" {
  count                 = "${var.azurerm_instances}"
  name                  = "demo-instance-${count.index}"
  location              = "${var.azurerm_location}"
  resource_group_name   = "${azurerm_resource_group.demo.name}"
  network_interface_ids = ["${element(azurerm_network_interface.demo.*.id, count.index)}"]
  vm_size               = "Standard_A0"
  availability_set_id   = "${azurerm_availability_set.demo.id}"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "14.04.2-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = "demo-disk-${count.index}"
    vhd_uri       = "${azurerm_storage_account.demo.primary_blob_endpoint}${element(azurerm_storage_container.demo.*.name, count.index)}/mydisk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  os_profile {
    computer_name  = "demo-instance-${count.index}"
    admin_username = "demo"
    admin_password = "${var.azurerm_vm_admin_password}"
    custom_data    = "${base64encode(file("${path.module}/templates/install.sh"))}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}
