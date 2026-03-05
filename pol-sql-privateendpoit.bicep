// Azure Policy Definition: Deploy DNS A record for SQL Database Private Endpoint
// This policy deploys a private DNS zone group when a SQL Database private endpoint
// is created, which automatically creates the required DNS A record in the
// SQL Database private DNS zone (privatelink.database.windows.net).

targetScope = 'subscription'

resource sqlPrivateEndpointDnsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'deploy-sql-private-endpoint-dns-record'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Deploy DNS A record for SQL Database private endpoint'
    #disable-next-line no-hardcoded-env-urls
    description: 'Deploys a private DNS zone group for SQL Database private endpoints, which automatically creates the DNS A record in the privatelink.database.windows.net zone.'
    metadata: {
      category: 'SQL'
      version: '1.0.0'
    }
    parameters: {
      privateDnsZoneId: {
        type: 'String'
        metadata: {
          displayName: 'Private DNS Zone ID'
          #disable-next-line no-hardcoded-env-urls
          description: 'The resource ID of the private DNS zone for SQL Database. Example: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net'
          strongType: 'Microsoft.Network/privateDnsZones'
        }
      }
      effect: {
        type: 'String'
        defaultValue: 'DeployIfNotExists'
        allowedValues: [
          'DeployIfNotExists'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Network/privateEndpoints'
          }
          {
            count: {
              field: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*]'
              where: {
                field: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*].privateLinkServiceId'
                contains: 'Microsoft.Sql/servers'
              }
            }
            greaterOrEquals: 1
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups'
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  privateEndpointName: {
                    type: 'string'
                  }
                  privateDnsZoneId: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups'
                    apiVersion: '2021-05-01'
                    name: '[concat(parameters(\'privateEndpointName\'), \'/default\')]'
                    properties: {
                      privateDnsZoneConfigs: [
                        {
                          name: 'privatelink-database-windows-net'
                          properties: {
                            privateDnsZoneId: '[parameters(\'privateDnsZoneId\')]'
                          }
                        }
                      ]
                    }
                  }
                ]
              }
              parameters: {
                privateEndpointName: {
                  value: '[field(\'name\')]'
                }
                privateDnsZoneId: {
                  value: '[parameters(\'privateDnsZoneId\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

output policyDefinitionId string = sqlPrivateEndpointDnsPolicy.id
