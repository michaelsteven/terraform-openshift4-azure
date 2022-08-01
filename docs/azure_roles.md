If assigning Contributor or User Access Administator Roles to the Azure Service Princpal are not permitted, it is possible to define a more granular subset of Roles to install openshift. Here is a reference set of Roles that were used to sucessfully install openshift 4.6-4.10.

### Scenario 1 - An empty Cluster Resource Group (RG) and a pre-existing Network RG
The Openshift cluster is to be installed into 2 Resource Groups (RG). The Cluster RG is to hold cluster objects (VMs, Load Balancers, Disks, etc.) and the second is a pre-existing Network RG with a preexisting VNET and SUBNET. Since the VNET is shared with other deployed applications, we need to restrict the capabilities of the Service Principle to assure business continuity of pre-existing applications. Also, there is a pre-existing DNS so no permissions for DNS creation are required.

The following are 2 Custom Roles that can scoped to their respective RGs. 

Cluster Resource Group

<pre>
{
    "id": "/subscriptions/XX/providers/Microsoft.Authorization/roleDefinitions/YYY",
    "properties": {
        "roleName": "Custom SP Role",
        "description": "Custom Role for Openshift Cluster",
        "assignableScopes": [],
        "permissions": [
            {
                "actions": [
                "Microsoft.Resources/subscriptions/resourceGroups/read",
                    "Microsoft.Resources/subscriptions/resourcegroups/resources/read",
                    "Microsoft.Resources/subscriptions/resourceGroups/delete",
                    "Microsoft.Compute/availabilitySets/*",
                    "Microsoft.Compute/locations/*",
                    "Microsoft.Compute/virtualMachines/*",
                    "Microsoft.Compute/disks/*",
                    "Microsoft.Compute/snapshots/*",
                    "Microsoft.KeyVault/vaults/*",
                    "Microsoft.Network/applicationGateways/backendAddressPools/join/action",
                    "Microsoft.Network/loadBalancers/backendAddressPools/join/action",
                    "Microsoft.Network/loadBalancers/inboundNatPools/join/action",
                    "Microsoft.Network/loadBalancers/inboundNatRules/join/action",
                    "Microsoft.Network/loadBalancers/probes/join/action",
                    "Microsoft.Network/loadBalancers/*",
                    "Microsoft.Network/locations/*",
                    "Microsoft.Network/networkInterfaces/*",
                    "Microsoft.Network/networkSecurityGroups/*",
                    "Microsoft.Network/applicationSecurityGroups/*",
                    "Microsoft.Network/virtualNetworks/*",
                    "Microsoft.ResourceHealth/availabilityStatuses/read",
                    "Microsoft.Resources/deployments/*",
                    "Microsoft.Storage/storageAccounts/*",
                    "Microsoft.Resources/tags/*",
                    "*/read",
                    "Microsoft.Compute/images/*",
                    "Microsoft.Network/virtualNetworks/subnets/join/action",
                    "Microsoft.Network/virtualNetworks/read",
                    "Microsoft.Network/virtualNetworks/subnets/join/action",
                    "Microsoft.Network/virtualNetworks/subnets/joinViaServiceEndpoint/action",
                    "Microsoft.Network/virtualNetworks/*/read",
                    "Microsoft.Network/virtualNetworks/*/joinLoadBalancer/action",
                    "Microsoft.Network/virtualNetworks/*/contextualServiceEndpointPolicies/read",
                    "Microsoft.Network/loadBalancers/*/read",
                    "Microsoft.Network/loadBalancers/*/join/action",
                    "Microsoft.Network/networkInterfaces/*/join/action",
                    "Microsoft.Network/networkInterfaces/*/read",
                    "Microsoft.Network/networkInterfaces/join/action",
                    "Microsoft.Network/networkInterfaces/read",
                    "Microsoft.Resources/subscriptions/resourcegroups/read"
                    ## the following are optional if openshift_managed_infrastructure=false
                    "Microsoft.ManagedIdentity/userAssignedIdentities/*",
                    "Microsoft.Authorization/roleAssignments/*"
                ],
                "notActions": [],
                "dataActions": [],
                "notDataActions": []
            }
        ]
    }
}
</pre>

Network Resource Group
<pre>

{
    "id": "/subscriptions/XXX/providers/Microsoft.Authorization/roleDefinitions/ZZZ",
    "properties": {
        "roleName": "Network Role",
        "description": "Base permissions to join a virtual network",
        "assignableScopes": [],
        "permissions": [
            {
                "actions": [
                    "Microsoft.Network/virtualNetworks/subnets/join/action",
                    "Microsoft.Network/virtualNetworks/read",
                    "Microsoft.Resources/deployments/*",
                    "Microsoft.Network/virtualNetworks/subnets/join/action",
                    "Microsoft.Network/virtualNetworks/subnets/joinViaServiceEndpoint/action",
                    "Microsoft.Network/virtualNetworks/*/read",
                    "Microsoft.Network/virtualNetworks/*/joinLoadBalancer/action",
                    "Microsoft.Network/virtualNetworks/*/contextualServiceEndpointPolicies/read",
                    "Microsoft.Network/loadBalancers/*/read",
                    "Microsoft.Network/loadBalancers/*/join/action",
                    "Microsoft.Network/networkInterfaces/*/join/action",
                    "Microsoft.Network/networkInterfaces/*/read",
                    "Microsoft.Network/networkInterfaces/join/action",
                    "Microsoft.Network/networkInterfaces/read",
                    "Microsoft.Resources/subscriptions/resourcegroups/read"
                ],
                "notActions": [],
                "dataActions": [],
                "notDataActions": []
            }
        ]
    }
}
</pre>


