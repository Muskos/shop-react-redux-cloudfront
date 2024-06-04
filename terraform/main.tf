terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.92.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

//  Static resource group

resource "azurerm_resource_group" "front_end_rg" {
  name     = "rg-frontend-sand-ne-002"
  location = "northeurope"
}

resource "azurerm_storage_account" "front_end_storage_account" {
  name                     = "amakas003"
  location                 = "northeurope"

  account_replication_type = "LRS"
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  resource_group_name      = azurerm_resource_group.front_end_rg.name

  static_website {
    index_document = "index.html"
  }
}

// Product service resource group

resource "azurerm_resource_group" "product_service_rg" {
  location = "northeurope"
  name     = "rg-product-service-sand-ne-001"
}

resource "azurerm_storage_account" "products_service_fa" {
  name     = "amakasproducts003"
  location = "northeurope"

  account_replication_type = "LRS"
  account_tier             = "Standard"
  account_kind             = "StorageV2"

  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_storage_share" "products_service_fa" {
  name  = "fa-products-service-share"
  quota = 2

  storage_account_name = azurerm_storage_account.products_service_fa.name
}

resource "azurerm_service_plan" "product_service_plan" {
  name     = "asp-product-service-sand-ne-001"
  location = "northeurope"

  os_type  = "Windows"
  sku_name = "Y1"

  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_application_insights" "products_service_fa" {
  name             = "appins-fa-products-service-sand-ne-001"
  application_type = "web"
  location         = "northeurope"


  resource_group_name = azurerm_resource_group.product_service_rg.name
}


resource "azurerm_windows_function_app" "products_service" {
  name     = "amakas-products-service-ne-003"
  location = "northeurope"

  service_plan_id     = azurerm_service_plan.product_service_plan.id
  resource_group_name = azurerm_resource_group.product_service_rg.name

  storage_account_name       = azurerm_storage_account.products_service_fa.name
  storage_account_access_key = azurerm_storage_account.products_service_fa.primary_access_key

  functions_extension_version = "~4"
  builtin_logging_enabled     = false

  site_config {
    always_on = false

    application_insights_key               = azurerm_application_insights.products_service_fa.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.products_service_fa.connection_string

    # For production systems set this to false, but consumption plan supports only 32bit workers
    use_32_bit_worker = true

    # Enable function invocations from Azure Portal.
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }

    application_stack {
      node_version = "~16"
    }
  }

  app_settings = {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.products_service_fa.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.products_service_fa.name
  }

  # The app settings changes cause downtime on the Function App. e.g. with Azure Function App Slots
  # Therefore it is better to ignore those changes and manage app settings separately off the Terraform.
  lifecycle {
    ignore_changes = [
      app_settings,
      site_config["application_stack"], // workaround for a bug when azure just "kills" your app
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
      tags["hidden-link: /app-insights-conn-string"]
    ]
  }
}

// API MANAGEMENT
resource "azurerm_api_management" "core_apim" {
  location        = "northeurope"
  name            = "amakas-apim-sand-ne-003"
  publisher_email = "aliaksei_makas@epam.com"
  publisher_name  = "Aliaksei Makas"

  resource_group_name = "rg-product-service-sand-ne-001"
  sku_name            = "Consumption_0"
}

resource "azurerm_api_management_api" "products_api" {
  api_management_name = azurerm_api_management.core_apim.name
  name                = "products-service-api"
  resource_group_name = "rg-product-service-sand-ne-001"
  revision            = "1"
  subscription_required = false

  display_name = "Products Service API"

  protocols = ["https"]
}

data "azurerm_function_app_host_keys" "products_keys" {
  name = azurerm_windows_function_app.products_service.name
  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_api_management_backend" "products_fa" {
  name = "products-service-backend-1"
  resource_group_name = "rg-product-service-sand-ne-001"
  api_management_name = azurerm_api_management.core_apim.name
  protocol = "http"
  url = "https://${azurerm_windows_function_app.products_service.name}.azurewebsites.net/api"
  description = "Products API"

  credentials {
    certificate = []
    query = {}

    header = {
      "x-functions-key" = data.azurerm_function_app_host_keys.products_keys.default_function_key
    }
  }
}

resource "azurerm_api_management_api_policy" "api_policy" {
  api_management_name = azurerm_api_management.core_apim.name
  api_name            = azurerm_api_management_api.products_api.name
  resource_group_name = "rg-product-service-sand-ne-001"

  xml_content = <<XML
 <policies>
    <inbound>
        <set-backend-service backend-id="${azurerm_api_management_backend.products_fa.name}"/>
        <base/>
        <cors>
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>*</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
            <expose-headers>
                <header>*</header>
            </expose-headers>
        </cors>
    </inbound>
    <backend>
        <base/>
    </backend>
    <outbound>
        <base/>
    </outbound>
    <on-error>
        <base/>
    </on-error>
 </policies>
XML
}

resource "azurerm_api_management_api_operation" "get_products" {
  api_management_name = azurerm_api_management.core_apim.name
  api_name            = azurerm_api_management_api.products_api.name
  display_name        = "Get Products"
  method              = "GET"
  operation_id        = "get-products"
  resource_group_name = "rg-product-service-sand-ne-001"
  url_template        = "/products"
}

resource "azurerm_api_management_api_operation" "get_product_by_id" {
  api_management_name = azurerm_api_management.core_apim.name
  api_name            = azurerm_api_management_api.products_api.name
  display_name        = "Get Product"
  method              = "GET"
  operation_id        = "get-product-by-id"
  resource_group_name = "rg-product-service-sand-ne-001"
  url_template        = "/products/{productId}"

  template_parameter {
    name     = "productId"
    type     = "number"
    required = true
  }
}

resource "azurerm_api_management_api_operation" "get_products_total" {
  api_management_name = azurerm_api_management.core_apim.name
  api_name            = azurerm_api_management_api.products_api.name
  display_name        = "Get Products Total"
  method              = "GET"
  operation_id        = "get-product-total"
  resource_group_name = "rg-product-service-sand-ne-001"
  url_template        = "/product/total"
}

resource "azurerm_api_management_api_operation" "post_products" {
  api_management_name = azurerm_api_management.core_apim.name
  api_name            = azurerm_api_management_api.products_api.name
  display_name        = "Post Products"
  method              = "POST"
  operation_id        = "post-products"
  resource_group_name = "rg-product-service-sand-ne-001"
  url_template        = "/products"
}

// DB
resource "azurerm_cosmosdb_account" "product_test_app" {
  location            = "northeurope"
  name                = "cos-app-sand-ne-001"
  offer_type          = "Standard"
  resource_group_name = azurerm_resource_group.product_service_rg.name
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Eventual"
  }

  capabilities {
    name = "EnableServerless"
  }

  geo_location {
    failover_priority = 0
    location          = "North Europe"
  }
}

resource "azurerm_cosmosdb_sql_database" "products_app" {
  account_name        = azurerm_cosmosdb_account.product_test_app.name
  name                = "products-db"
  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_cosmosdb_sql_container" "products" {
  account_name        = azurerm_cosmosdb_account.product_test_app.name
  database_name       = azurerm_cosmosdb_sql_database.products_app.name
  name                = "products"
  partition_key_path  = "/id"
  resource_group_name = azurerm_resource_group.product_service_rg.name

  # Cosmos DB supports TTL for the records
  default_ttl = -1

  indexing_policy {
    excluded_path {
      path = "/*"
    }
  }
}

resource "azurerm_cosmosdb_sql_container" "stocks" {
  account_name        = azurerm_cosmosdb_account.product_test_app.name
  database_name       = azurerm_cosmosdb_sql_database.products_app.name
  name                = "stocks"
  partition_key_path  = "/product_id"
  resource_group_name = azurerm_resource_group.product_service_rg.name

  # Cosmos DB supports TTL for the records
  default_ttl = -1

  indexing_policy {
    excluded_path {
      path = "/*"
    }
  }
}

// Storage account

resource "azurerm_resource_group" "rg" {
  name     = "rg-product-import-sand-ne-002"
  location = "northeurope"
}

resource "azurerm_storage_account" "sa" {
  name                             = "amakasimports003"
  resource_group_name              = azurerm_resource_group.rg.name
  location                         = azurerm_resource_group.rg.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  account_kind                     = "StorageV2"
  enable_https_traffic_only        = true
  allow_nested_items_to_be_public  = true
  shared_access_key_enabled        = true
  public_network_access_enabled    = true
  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["PUT", "GET"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 0
    }
  }

}

resource "azurerm_storage_container" "sa_container" {
  name                  = "my-container"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_share" "import_service_fa" {
  name  = "fa-import-service-share"
  quota = 2

  storage_account_name = azurerm_storage_account.sa.name
}

resource "azurerm_service_plan" "import_service_plan" {
  name     = "asp-import-service-sand-ne-001"
  location = "northeurope"

  os_type  = "Windows"
  sku_name = "Y1"

  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_application_insights" "import_service_fa" {
  name             = "appins-fa-import-service-sand-ne-001"
  application_type = "web"
  location         = "northeurope"


  resource_group_name = azurerm_resource_group.rg.name
}


resource "azurerm_windows_function_app" "import_service" {
  name     = "amakas-import-service-ne-003"
  location = "northeurope"

  service_plan_id     = azurerm_service_plan.import_service_plan.id
  resource_group_name = azurerm_resource_group.rg.name

  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key

  functions_extension_version = "~4"
  builtin_logging_enabled     = false

  site_config {
    always_on = false

    application_insights_key               = azurerm_application_insights.import_service_fa.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.import_service_fa.connection_string

    # For production systems set this to false, but consumption plan supports only 32bit workers
    use_32_bit_worker = true

    # Enable function invocations from Azure Portal.
    cors {
      allowed_origins = ["https://portal.azure.com","https://amakas003.z16.web.core.windows.net"]
    }

    application_stack {
      node_version = "~16"
    }
  }

  app_settings = {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.sa.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.import_service_fa.name
  }

  # The app settings changes cause downtime on the Function App. e.g. with Azure Function App Slots
  # Therefore it is better to ignore those changes and manage app settings separately off the Terraform.
  lifecycle {
    ignore_changes = [
      app_settings,
      site_config["application_stack"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
      tags["hidden-link: /app-insights-conn-string"]
    ]
  }
}

# Service bus
resource "azurerm_servicebus_namespace" "sb" {
  name                          = "my-new-servicebus"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  sku                           = "Standard"
  public_network_access_enabled = true /* can be changed to false for premium */
}

resource "azurerm_servicebus_queue" "example" {
  name                                    = "my_new_servicebus_queue"
  namespace_id                            = azurerm_servicebus_namespace.sb.id
}

resource "azurerm_servicebus_topic" "products_import_topic" {
  name         = "products-import-topic"
  namespace_id = azurerm_servicebus_namespace.sb.id
}

resource "azurerm_servicebus_subscription" "products_import_subscription" {
  name               = "products-import-subscription-001"
  topic_id           = azurerm_servicebus_topic.products_import_topic.id
  max_delivery_count = 1
}

resource "azurerm_servicebus_subscription_rule" "products_import_subscription_rule" {
  name            = "products-import-subscription-rule-001"
  subscription_id = azurerm_servicebus_subscription.products_import_subscription.id
  filter_type     = "CorrelationFilter"
  correlation_filter {
    label          = "product"
  }
}

// Container
resource "azurerm_resource_group" "simple-server-rg" {
  name     = "makas-rg-simple-server-001"
  location = "northeurope"
}

resource "azurerm_log_analytics_workspace" "simple_server_log_analytics_workspace" {
  name                = "makas-log-analytics-chatbot-001"
  location            = azurerm_resource_group.simple-server-rg.location
  resource_group_name = azurerm_resource_group.simple-server-rg.name
}

resource "azurerm_container_registry" "simple-server" {
  name                = "makassimpleserver"
  resource_group_name = azurerm_resource_group.simple-server-rg.name
  location            = azurerm_resource_group.simple-server-rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_container_app_environment" "simple_server_cae" {
  name                       = "makas-cae-simple-server-001"
  location                   = azurerm_resource_group.simple-server-rg.location
  resource_group_name        = azurerm_resource_group.simple-server-rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.simple_server_log_analytics_workspace.id
}

resource "azurerm_container_app" "simple_server_ca_docker_acr" {
  name                         = "makas-chatbot-ca-acr"
  container_app_environment_id = azurerm_container_app_environment.simple_server_cae.id
  resource_group_name          = azurerm_resource_group.simple-server-rg.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.simple-server.login_server
    username             = azurerm_container_registry.simple-server.admin_username
    password_secret_name = "acr-password"
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 3000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

  }

  template {
    container {
      name   = "makas-simple-sever-container-acr"
      image  = "${azurerm_container_registry.simple-server.login_server}/simple-server:v1"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "CONTAINER_REGISTRY_NAME"
        value = "Azure Container Registry"
      }
    }
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.simple-server.admin_password
  }
}

// DOCKER
resource "azurerm_container_app" "simple_server_ca_docker_hub" {
  name                         = "makas-simple-server-ca-dh"
  container_app_environment_id = azurerm_container_app_environment.simple_server_cae.id
  resource_group_name          = azurerm_resource_group.simple-server-rg.name
  revision_mode                = "Single"

  registry {
    server               = "docker.io"
    username             = "muskos"
    password_secret_name = "docker-io-pass"
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 3000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

  }

  template {
    container {
      name   = "makas-simple-server-container-dh"
      image  = "muskos/simple-server:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "CONTAINER_REGISTRY_NAME"
        value = "Docker Hub"
      }
    }
  }

  secret {
    name  = "docker-io-pass"
    value = "ucf9pmu@zwg_ABU0wqa"
  }
}

