RESOURCE_GROUP="ghost-container-app"
STORAGE_ACCOUNT_NAME="ghostinzecloudaca"
APP_NAME=ghost-in-zecloud
LOCATION="westeurope"
#LOG_ANALYTICS_WORKSPACE="ghost-container-app-logs"
CONTAINERAPPS_ENVIRONMENT="ghost-container-app-env"
MYSQL_SERVER_NAME="ghost-dbserver"
DB_USER="toto"
DB_PASSWORD="GyHrEtlOmpq"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
az containerapp env create --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP --location $LOCATION
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2
STORAGE_ACCOUNT_KEY=`az storage account keys list -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --query [0].{Value:value} -o tsv`
az storage share create --account-name $STORAGE_ACCOUNT_NAME --name $STORAGE_ACCOUNT_NAME-fileshare
az containerapp env storage set --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP \
                                --storage-name $STORAGE_ACCOUNT_NAME-files \
                                --azure-file-account-name $STORAGE_ACCOUNT_NAME \
                                --azure-file-account-key $STORAGE_ACCOUNT_KEY \
                                --azure-file-share-name $STORAGE_ACCOUNT_NAME-fileshare \
                                --access-mode ReadWrite 

az mysql flexible-server create --location $LOCATION --resource-group  $RESOURCE_GROUP \
  --name $MYSQL_SERVER_NAME --admin-user $DB_USER --admin-password $DB_PASSWORD \
  --sku-name Standard_B1s  --public-access 0.0.0.0  --storage-auto-grow Enabled \
  --iops 320 --tier Burstable --storage-size 32 --version 8.0
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --image ghost:latest \
  --target-port 2368 \
  --ingress 'external' \
  --query configuration.ingress.fqdn \
  --env-vars 'database__client=mysql' "database__connection__host=$MYSQL_SERVER_NAME.mysql.database.azure.com" \
       "database__connection__user=$DB_USER" "database__connection__password=$DB_PASSWORD" \
       'database__connection__database=ghost' 'database__connection__port=3306' 'database__connection__ssl__rejectUnauthorized=true'

az containerapp show -n $APP_NAME -g $RESOURCE_GROUP -o yaml > app.yaml