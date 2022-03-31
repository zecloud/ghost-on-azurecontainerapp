#az extension add \
#  --source https://workerappscliextension.blob.core.windows.net/azure-cli-extension/containerapp-0.2.4-py2.py3-none-any.whl
#az provider register --namespace Microsoft.Web
az extension add -n containerapp
RESOURCE_GROUP="ghost-container-app"
LOCATION="westeurope"
LOG_ANALYTICS_WORKSPACE="ghost-container-app-logs"
CONTAINERAPPS_ENVIRONMENT="ghost-container-app-env"
MYSQL_SERVER_NAME="ghost-dbserver"
DB_USER="toto"
DB_PASSWORD="GyHrEtlOmpq"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE
LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'`
LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'`
az containerapp env create \
  --name $CONTAINERAPPS_ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
  --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
  --location $LOCATION
CONTAINER_APP_ENV_IP=`az containerapp env show -g $RESOURCE_GROUP -n $CONTAINERAPPS_ENVIRONMENT --query properties.staticIp -o tsv`
az mysql flexible-server create --location $LOCATION --resource-group  $RESOURCE_GROUP \
  --name $MYSQL_SERVER_NAME --admin-user $DB_USER --admin-password $DB_PASSWORD \
  --sku-name Standard_B1s  --public-access 0.0.0.0  --storage-auto-grow Enabled \
  --iops 320 --tier Burstable --storage-size 32
az containerapp create \
  --name ghost-in-zecloud \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --image ghost:4.37 \
  --target-port 2368 \
  --ingress 'external' \
  --query configuration.ingress.fqdn \
  --env-vars 'database__client=mysql' "database__connection__host=$MYSQL_SERVER_NAME.mysql.database.azure.com" \
       "database__connection__user=$DB_USER" "database__connection__password=$DB_PASSWORD" \
       'database__connection__database=ghost' 'database__connection__ssl=true' 'database__connection__port=3306'