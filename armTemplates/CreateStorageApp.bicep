param appName string
param tableNames array
@allowed([
  'prod'
  'test'
])
param environment string = 'test'
param location string = resourceGroup().location
var isTestEnv = environment == 'test'
var storageReplicaiton = isTestEnv ? 'Standard_LRS' : 'Standard_GRS'
var resourceName = '${appName}${environment}'

resource storageApp 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: resourceName
  location: location
  tags: {
    account: resourceGroup().name
    app: appName
    environment: environment
  }
  sku: {
    name: storageReplicaiton
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          keyType: 'Account'
          enabled: true
        }
        table: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource Microsoft_Storage_storageAccounts_blobServices_storageApp_default 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageApp
  name: 'default'
  dependsOn: [
    storageApp
  ]
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

// remove trailing slash since cors rule asserts the origin without ending trailing
var deployedSiteUrl = substring(storageApp.properties.primaryEndpoints.web, 0, length(storageApp.properties.primaryEndpoints.web)-1)
var tableServiceConfigurationMap = {
  Test: {
    allowedOrigins: [
      deployedSiteUrl
      'https://localhost:5001'
    ]
    allowedMethods: [
      'GET'
      'HEAD'
      'MERGE'
      'POST'
      'OPTIONS'
      'PUT'
      'DELETE'
      'PATCH'
    ]
  }  
  Prod: {
    allowedOrigins: [
      deployedSiteUrl
    ]
    allowedMethods: [
      'GET'
      'HEAD'
      'MERGE'
      'POST'
      'OPTIONS'
      'PUT'
      'PATCH'
    ]
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_storageApp_default 'Microsoft.Storage/storageAccounts/tableServices@2021-06-01' = {
  parent: storageApp
  name: 'default'
  dependsOn: [
    storageApp
  ]
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: tableServiceConfigurationMap[environment].allowedOrigins
          allowedMethods: tableServiceConfigurationMap[environment].allowedMethods
          maxAgeInSeconds: 180
          exposedHeaders: [
            '*'
          ]
          allowedHeaders: [
            '*'
          ]
        }
      ]
    }
  }
}

resource storageApp_default_web 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  parent: Microsoft_Storage_storageAccounts_blobServices_storageApp_default
  name: '$web'
  dependsOn: [
    storageApp
  ]
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
}

resource storageApp_default_Tables 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-06-01' = [for tableName in tableNames: {
  parent: Microsoft_Storage_storageAccounts_tableServices_storageApp_default
  name: '${tableName}'
  dependsOn: [
    storageApp
  ]
}]

output storageAccount string = storageApp.name
output siteUrl string = deployedSiteUrl
output secondaryLocation string = isTestEnv ? '' : storageApp.properties.secondaryLocation
