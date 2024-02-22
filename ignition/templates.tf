data "template_file" "install_config_yaml" {
  template = <<EOF
apiVersion: v1
baseDomain: ${var.base_domain}
compute:
- hyperthreading: Enabled
  name: worker
  platform:
    azure:
      type: ${var.worker_vm_type}
      osDisk:
        diskSizeGB: ${var.worker_os_disk_size}
        diskType: Premium_LRS
  replicas: ${var.node_count}
controlPlane:
  hyperthreading: Enabled
  name: master
  platform:
    azure:
      type: ${var.master_vm_type}
      osDisk:
        diskSizeGB: ${var.master_os_disk_size}
        diskType: Premium_LRS
      zones:
      - "1"
      - "2"
      - "3"
  replicas: ${var.master_count}
metadata:
  creationTimestamp: null
  name: ${var.cluster_name}
networking:
  clusterNetwork:
  - cidr: ${var.cluster_network_cidr}
    hostPrefix: ${var.cluster_network_host_prefix}
  machineNetwork:
  - cidr: ${var.machine_cidr}
  networkType: OpenShiftSDN
  serviceNetwork:
  - ${var.service_network_cidr}
platform:
  azure:
    region: ${var.azure_region}
    baseDomainResourceGroupName: ${var.azure_dns_resource_group_name}
    networkResourceGroupName: ${var.network_resource_group_name}
    virtualNetwork: ${var.virtual_network_name}
    controlPlaneSubnet: ${var.control_plane_subnet}
    computeSubnet: ${var.compute_subnet}
    outboundType: ${var.outbound_udr ? "UserDefinedRouting" : "Loadbalancer"}
publish: ${var.private ? "Internal" : "External"}
pullSecret: %{if (var.openshift_pull_secret_string != "")}'${var.openshift_pull_secret_string}' %{ else } '${chomp(file(var.openshift_pull_secret))}'%{endif}
sshKey: '${var.public_ssh_key}'
%{if var.airgapped["enabled"]}imageContentSources:
- mirrors:
  - ${var.airgapped["repository"]}
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - ${var.airgapped["repository"]}
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
%{endif}
%{if var.proxy_config["enabled"]}proxy:
  httpProxy: ${var.proxy_config["httpProxy"]}
  httpsProxy: ${var.proxy_config["httpsProxy"]}
  noProxy: ${var.proxy_config["noProxy"]}
%{endif}
%{if var.trust_bundle != ""}
${indent(2, "additionalTrustBundle: |\n${file(var.trust_bundle)}")}
%{ else }
%{if var.trust_bundle_string != ""}
${indent(2, "additionalTrustBundle: |\n${var.trust_bundle_string}")}
%{endif}
%{endif}
EOF
}

resource "local_file" "install_config_yaml" {
  content  = data.template_file.install_config_yaml.rendered
  filename = "${local.installer_workspace}/install-config.yaml"
  depends_on = [
    null_resource.download_binaries,
  ]
}

data "template_file" "cluster-infrastructure-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Infrastructure
metadata:
  creationTimestamp: null
  name: cluster
spec:
  cloudConfig:
    key: config
    name: cloud-provider-config
status:
  apiServerInternalURI: https://api-int.${var.cluster_name}.${var.base_domain}:6443
  apiServerURL: https://api.${var.cluster_name}.${var.base_domain}:6443
  etcdDiscoveryDomain: ${var.cluster_name}.${var.base_domain}
  infrastructureName: ${var.cluster_id}
  platform: Azure
  platformStatus:
    azure:
      resourceGroupName: ${var.resource_group_name}
    type: Azure
EOF
}

resource "local_file" "cluster-infrastructure-02-config" {
  content  = data.template_file.cluster-infrastructure-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-infrastructure-02-config.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-dns-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: DNS
metadata:
  creationTimestamp: null
  name: cluster
spec:
  baseDomain: ${var.cluster_name}.${var.base_domain}
%{if var.byo_dns == false && var.openshift_dns_provider == "azure"}
  privateZone:
    id: /subscriptions/${var.azure_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/privateDnsZones/${var.cluster_name}.${var.base_domain}
%{if var.private == false && var.openshift_dns_provider == "azure"}
  publicZone:
    id: /subscriptions/${var.azure_subscription_id}/resourceGroups/${var.azure_dns_resource_group_name}/providers/Microsoft.Network/dnszones/${var.base_domain}
%{endif}
%{endif}
status: {}
EOF
}

resource "local_file" "cluster-dns-02-config" {
  content  = data.template_file.cluster-dns-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-dns-02-config.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cloud-provider-config" {
  template = <<EOF
apiVersion: v1
data:
  config: "{\n\t\"cloud\": \"AzurePublicCloud\",\n\t\"tenantId\": \"${var.azure_tenant_id}\",\n\t\"aadClientId\":
    \"\",\n\t\"aadClientSecret\": \"\",\n\t\"aadClientCertPath\": \"\",\n\t\"aadClientCertPassword\":
    \"\",\n\t\"useManagedIdentityExtension\": true,\n\t\"userAssignedIdentityID\":
    \"\",\n\t\"subscriptionId\": \"${var.azure_subscription_id}\",\n\t\"resourceGroup\":
    \"${var.resource_group_name}\",\n\t\"location\": \"${var.azure_region}\",\n\t\"vnetName\": \"${var.virtual_network_name}\",\n\t\"vnetResourceGroup\":
    \"${var.network_resource_group_name}\",\n\t\"subnetName\": \"${var.compute_subnet}\",\n\t\"securityGroupName\":
    \"${var.cluster_id}-nsg\",\n\t\"routeTableName\": \"${var.cluster_id}-node-routetable\",\n\t\"primaryAvailabilitySetName\":
    \"\",\n\t\"vmType\": \"\",\n\t\"primaryScaleSetName\": \"\",\n\t\"cloudProviderBackoff\":
    true,\n\t\"cloudProviderBackoffRetries\": 0,\n\t\"cloudProviderBackoffExponent\":
    0,\n\t\"cloudProviderBackoffDuration\": 6,\n\t\"cloudProviderBackoffJitter\":
    0,\n\t\"cloudProviderRateLimit\": true,\n\t\"cloudProviderRateLimitQPS\": 12,\n\t\"cloudProviderRateLimitBucket\":
    10,\n\t\"cloudProviderRateLimitQPSWrite\": 12,\n\t\"cloudProviderRateLimitBucketWrite\":
    10,\n\t\"useInstanceMetadata\": true,\n\t\"loadBalancerSku\": \"standard\",\n\t\"excludeMasterFromStandardLB\":
    null,\n\t\"disableOutboundSNAT\": null,\n\t\"maximumLoadBalancerRuleCount\": 0\n}\n"
kind: ConfigMap
metadata:
  name: cloud-provider-config
  namespace: openshift-config
EOF
}

resource "local_file" "cloud-provider-config" {
  content  = data.template_file.cloud-provider-config.rendered
  filename = "${local.installer_workspace}/manifests/cloud-provider-config.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-ingress-default-ingresscontroller" {
  template = <<EOF
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  finalizers:
  - ingresscontroller.operator.openshift.io/finalizer-ingresscontroller
  name: default
  namespace: openshift-ingress-operator
spec:
  endpointPublishingStrategy: 
    type: HostNetwork
  replicas: 2
status: {}
EOF
}

resource "local_file" "cluster-ingress-default-ingresscontroller" {
  content  = data.template_file.cluster-ingress-default-ingresscontroller.rendered
  filename = "${local.installer_workspace}/manifests/cluster-ingress-default-ingresscontroller.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "openshift-cluster-api_master-machines" {
  count    = !var.managed_infrastructure ? var.master_count : 0
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: Machine
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: master
    machine.openshift.io/cluster-api-machine-type: master
  name: ${var.cluster_id}-master-${count.index}
  namespace: openshift-machine-api
spec:
  metadata:
    creationTimestamp: null
  providerSpec:
    value:
      apiVersion: azureproviderconfig.openshift.io/v1beta1
      credentialsSecret:
        name: %{ if var.managed_infrastructure }azure-cloud-credentials%{ else }""%{ endif } 
        namespace: openshift-machine-api
      image:
        offer: ""
        publisher: ""
        resourceID: /resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/images/${var.cluster_id}
        sku: ""
        version: ""
      internalLoadBalancer: ""
      kind: AzureMachineProviderSpec
      location: ${var.azure_region}
      managedIdentity: %{ if var.managed_infrastructure }${var.cluster_id}-identity%{ else }""%{ endif }
      metadata:
        creationTimestamp: null
      natRule: null
      networkResourceGroup: ${var.network_resource_group_name}
      osDisk:
        diskSizeGB: ${var.master_os_disk_size}
        managedDisk:
          storageAccountType: Premium_LRS
        osType: Linux
      publicIP: false
      publicLoadBalancer: ""
      resourceGroup: ${var.resource_group_name}
      sshPrivateKey: ""
      sshPublicKey: ""
      subnet: ${var.control_plane_subnet}
      userDataSecret:
        name: master-user-data
      vmSize: ${var.master_vm_type}
      vnet: ${var.virtual_network_name}
      %{if length(var.availability_zones) > 1}zone: "${var.availability_zones[count.index]}"%{endif}
EOF
}

resource "local_file" "openshift-cluster-api_master-machines" {
  count    = !var.managed_infrastructure ? var.master_count : 0
  content  = data.template_file.openshift-cluster-api_master-machines.*.rendered[count.index]
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_master-machines-${count.index}.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}
locals {
  zone_node_replicas  = [for idx in range(length(var.availability_zones)) : floor(var.node_count / length(var.availability_zones)) + (idx + 1 > (var.node_count % length(var.availability_zones)) ? 0 : 1)]
  zone_infra_replicas = [for idx in range(length(var.availability_zones)) : floor(var.infra_count / length(var.availability_zones)) + (idx + 1 > (var.infra_count % length(var.availability_zones)) ? 0 : 1)]
  node_count          = var.node_count + var.infra_count
}

data "template_file" "openshift-cluster-api_worker-machineset" {
  count    = var.managed_infrastructure ? length(var.availability_zones) : 0
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: worker
    machine.openshift.io/cluster-api-machine-type: worker
  name: ${var.cluster_id}-worker-${var.azure_region}${count.index + 1}
  namespace: openshift-machine-api
spec:
  replicas: ${local.zone_node_replicas[count.index]}
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
      machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-worker-${var.azure_region}${count.index + 1}
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-worker-${var.azure_region}${count.index + 1}
    spec:
      metadata:
        creationTimestamp: null
      providerSpec:
        value:
          apiVersion: azureproviderconfig.openshift.io/v1beta1
          credentialsSecret:
            name: %{ if var.managed_infrastructure }azure-cloud-credentials%{ else }""%{ endif } 
            namespace: openshift-machine-api
          image:
            offer: ""
            publisher: ""
            resourceID: /resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/images/${var.cluster_id}
            sku: ""
            version: ""
          internalLoadBalancer: ""
          kind: AzureMachineProviderSpec
          location: ${var.azure_region}
          managedIdentity: %{ if var.managed_infrastructure }${var.cluster_id}-identity%{ else }""%{ endif }
          metadata:
            creationTimestamp: null
          natRule: null
          networkResourceGroup: ${var.network_resource_group_name}
          osDisk:
            diskSizeGB: ${var.worker_os_disk_size}
            managedDisk:
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          publicLoadBalancer: ""
          resourceGroup: ${var.resource_group_name}
          sshPrivateKey: ""
          sshPublicKey: ""
          subnet: ${var.compute_subnet}
          userDataSecret:
            name: worker-user-data
          vmSize: ${var.worker_vm_type}
          vnet: ${var.virtual_network_name}
          %{if length(var.availability_zones) > 1}zone: "${var.availability_zones[count.index]}"%{endif}
EOF
}

data "template_file" "openshift-cluster-api_worker-machines" {
  count    =  !var.managed_infrastructure ? var.node_count : 0
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: Machine
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: worker
    machine.openshift.io/cluster-api-machine-type: worker
  name: ${var.cluster_id}-worker-${count.index}
  namespace: openshift-machine-api
spec:
  metadata:
    creationTimestamp: null
  providerSpec:
    value:
      apiVersion: azureproviderconfig.openshift.io/v1beta1
      credentialsSecret:
        name: %{ if var.managed_infrastructure }azure-cloud-credentials%{ else }""%{ endif } 
        namespace: openshift-machine-api
      image:
        offer: ""
        publisher: ""
        resourceID: /resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/images/${var.cluster_id}
        sku: ""
        version: ""
      internalLoadBalancer: ""
      kind: AzureMachineProviderSpec
      location: ${var.azure_region}
      managedIdentity: %{ if var.managed_infrastructure }${var.cluster_id}-identity%{ else }""%{ endif }
      metadata:
        creationTimestamp: null
      natRule: null
      networkResourceGroup: ${var.network_resource_group_name}
      osDisk:
        diskSizeGB: ${var.worker_os_disk_size}
        managedDisk:
          storageAccountType: Premium_LRS
        osType: Linux
      publicIP: false
      publicLoadBalancer: ""
      resourceGroup: ${var.resource_group_name}
      sshPrivateKey: ""
      sshPublicKey: ""
      subnet: ${var.compute_subnet}
      userDataSecret:
        name: worker-user-data
      vmSize: ${var.worker_vm_type}
      vnet: ${var.virtual_network_name}
      %{if length(var.availability_zones) > 1}zone: "${var.availability_zones[count.index%length(var.availability_zones)]}"%{endif}
EOF
}

resource "local_file" "openshift-cluster-api_worker-machineset" {
  count    = var.managed_infrastructure ? length(var.availability_zones) : 0
  content  = data.template_file.openshift-cluster-api_worker-machineset.*.rendered[count.index]
#  content  = element(data.template_file.openshift-cluster-api_worker-machineset.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_worker-machineset-${count.index}.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

resource "local_file" "openshift-cluster-api_worker-machines" {
  count    = !var.managed_infrastructure ? var.node_count : 0
  content  = data.template_file.openshift-cluster-api_worker-machines.*.rendered[count.index]
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_worker-machines-${count.index}.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "openshift-cluster-api_infra-machineset" {
  count    = var.managed_infrastructure && var.infra_count > 0 ? length(var.availability_zones) : 0
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: infra
    machine.openshift.io/cluster-api-machine-type: infra
  name: ${var.cluster_id}-infra-${var.azure_region}${count.index + 1}
  namespace: openshift-machine-api
spec:
  replicas: ${local.zone_infra_replicas[count.index]}
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
      machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-infra-${var.azure_region}${count.index + 1}
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: infra
        machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-infra-${var.azure_region}${count.index + 1}
    spec:
      metadata:
        creationTimestamp: null
        labels:
          node-role.kubernetes.io/infra: ""
      providerSpec:
        value:
          apiVersion: azureproviderconfig.openshift.io/v1beta1
          credentialsSecret:
            name:  %{ if var.managed_infrastructure }azure-cloud-credentials%{ else }""%{ endif } 
            namespace: openshift-machine-api
          image:
            offer: ""
            publisher: ""
            resourceID: /resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/images/${var.cluster_id}
            sku: ""
            version: ""
          internalLoadBalancer: ""
          kind: AzureMachineProviderSpec
          location: ${var.azure_region}
          managedIdentity: %{ if var.managed_infrastructure }${var.cluster_id}-identity%{ else }""%{ endif }
          metadata:
            creationTimestamp: null
          natRule: null
          networkResourceGroup: ${var.network_resource_group_name}
          osDisk:
            diskSizeGB: ${var.infra_os_disk_size}
            managedDisk:
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          publicLoadBalancer: ""
          resourceGroup: ${var.resource_group_name}
          sshPrivateKey: ""
          sshPublicKey: ""
          subnet: ${var.compute_subnet}
          userDataSecret:
            name: worker-user-data
          vmSize: ${var.infra_vm_type}
          vnet: ${var.virtual_network_name}
          %{if length(var.availability_zones) > 1}zone: "${var.availability_zones[count.index]}"%{endif}
EOF
}

data "template_file" "openshift-cluster-api_infra-machines" {
  count    = !var.managed_infrastructure && var.infra_count > 0 ? var.infra_count : 0
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: Machine
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: infra
    machine.openshift.io/cluster-api-machine-type: infra
  name: ${var.cluster_id}-infra-${count.index}
  namespace: openshift-machine-api
spec:
  metadata:
    creationTimestamp: null
    labels:
      node-role.kubernetes.io/infra: ""
  providerSpec:
    value:
      apiVersion: azureproviderconfig.openshift.io/v1beta1
      credentialsSecret:
        name:  %{ if var.managed_infrastructure }azure-cloud-credentials%{ else }""%{ endif } 
        namespace: openshift-machine-api
      image:
        offer: ""
        publisher: ""
        resourceID: /resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/images/${var.cluster_id}
        sku: ""
        version: ""
      internalLoadBalancer: ""
      kind: AzureMachineProviderSpec
      location: ${var.azure_region}
      managedIdentity: %{ if var.managed_infrastructure }${var.cluster_id}-identity%{ else }""%{ endif }
      metadata:
        creationTimestamp: null
      natRule: null
      networkResourceGroup: ${var.network_resource_group_name}
      osDisk:
        diskSizeGB: ${var.infra_os_disk_size}
        managedDisk:
          storageAccountType: Premium_LRS
        osType: Linux
      publicIP: false
      publicLoadBalancer: ""
      resourceGroup: ${var.resource_group_name}
      sshPrivateKey: ""
      sshPublicKey: ""
      subnet: ${var.compute_subnet}
      userDataSecret:
        name: worker-user-data
      vmSize: ${var.infra_vm_type}
      vnet: ${var.virtual_network_name}
      %{if length(var.availability_zones) > 1}zone: "${var.availability_zones[count.index]}"%{endif}
EOF
}

resource "local_file" "openshift-cluster-api_infra-machineset" {
  count    = var.managed_infrastructure && var.infra_count > 0 ? length(var.availability_zones) : 0
  content  = data.template_file.openshift-cluster-api_infra-machineset.*.rendered[count.index]
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_infra-machineset-${count.index}.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

resource "local_file" "openshift-cluster-api_infra-machines" {
  count    = !var.managed_infrastructure && var.infra_count > 0 ? var.infra_count : 0
  content  = data.template_file.openshift-cluster-api_infra-machines.*.rendered[count.index]
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_infra-machines-${count.index}.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cloud-creds-secret-kube-system" {
  template = <<EOF
kind: Secret
apiVersion: v1
metadata:
  namespace: kube-system
  name: azure-credentials
data:
  azure_subscription_id: ${base64encode(var.azure_subscription_id)}
  azure_client_id: ${base64encode(var.azure_client_id)}
  azure_client_secret: ${base64encode(var.azure_client_secret)}
  azure_tenant_id: ${base64encode(var.azure_tenant_id)}
  azure_resource_prefix: ${base64encode(var.cluster_id)}
  azure_resourcegroup: ${base64encode(var.resource_group_name)}
  azure_region: ${base64encode(var.azure_region)}
EOF
}

resource "local_file" "cloud-creds-secret-kube-system" {
  count = var.managed_infrastructure ? 1 : 0
  content  = data.template_file.cloud-creds-secret-kube-system.rendered
  filename = "${local.installer_workspace}/openshift/99_cloud-creds-secret.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-monitoring-configmap" {
  template = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |+
    alertmanagerMain:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    prometheusK8s:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    prometheusOperator:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    grafana:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    k8sPrometheusAdapter:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    kubeStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    telemeterClient:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    openshiftStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    thanosQuerier:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
EOF
}

resource "local_file" "cluster-monitoring-configmap" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.cluster-monitoring-configmap.rendered
  filename = "${local.installer_workspace}/openshift/99_cluster-monitoring-configmap.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}


data "template_file" "configure-image-registry-job-serviceaccount" {
  template = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: infra
  namespace: openshift-image-registry
EOF
}

resource "local_file" "configure-image-registry-job-serviceaccount" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.configure-image-registry-job-serviceaccount.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-image-registry-job-serviceaccount.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "configure-image-registry-job-clusterrole" {
  template = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:ibm-patch-cluster-storage
rules:
- apiGroups: ['imageregistry.operator.openshift.io']
  resources: ['configs']
  verbs:     ['get','patch']
  resourceNames: ['cluster']
EOF
}

resource "local_file" "configure-image-registry-job-clusterrole" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.configure-image-registry-job-clusterrole.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-image-registry-job-clusterrole.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "configure-image-registry-job-clusterrolebinding" {
  template = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:ibm-patch-cluster-storage
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:ibm-patch-cluster-storage
subjects:
  - kind: ServiceAccount
    name: default
    namespace: openshift-image-registry
EOF
}

resource "local_file" "configure-image-registry-job-clusterrolebinding" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.configure-image-registry-job-clusterrolebinding.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-image-registry-job-clusterrolebinding.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "configure-image-registry-job" {
  template = <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ibm-configure-image-registry
  namespace: openshift-image-registry
spec:
  parallelism: 1
  completions: 1
  template:
    metadata:
      name: configure-image-registry
      labels:
        app: configure-image-registry
    serviceAccountName: infra
    spec:
      containers:
      - name:  client
        image: quay.io/openshift/origin-cli:latest
        command: ["/bin/sh","-c"]
        args: ["while ! /usr/bin/oc get configs.imageregistry.operator.openshift.io cluster >/dev/null 2>&1; do sleep 1;done;/usr/bin/oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{\"spec\": {\"nodeSelector\": {\"node-role.kubernetes.io/infra\": \"\"}}}'"]
      restartPolicy: Never
EOF
}

resource "local_file" "configure-image-registry-job" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.configure-image-registry-job.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-image-registry-job.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

### Internal registry

data "template_file" "configure-image-registry" {
  count    = !var.use_default_imageregistry ? 1 : 0
  template = <<EOF
apiVersion: imageregistry.operator.openshift.io/v1
kind: Config
metadata:
  finalizers:
  - imageregistry.operator.openshift.io/finalizer
  name: cluster
spec:
  logLevel: Normal
  managementState: Removed
  nodeSelector:
    node-role.kubernetes.io/infra: ""
  observedConfig: null
  operatorLogLevel: Normal
  proxy: {}
  replicas: 0
  requests:
    read:
      maxWaitInQueue: 0s
    write:
      maxWaitInQueue: 0s
  rolloutStrategy: RollingUpdate
  storage:
    azure:
      emptyDir:
  unsupportedConfigOverrides: null
EOF
}

resource "local_file" "configure-image-registry" {
  count    = !var.use_default_imageregistry ? 1 : 0
  content  = element(data.template_file.configure-image-registry.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_configure-image-registry.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "configure-ingress-job-serviceaccount" {
  template = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: infra
  namespace: openshift-ingress-operator
EOF
}

resource "local_file" "configure-ingress-job-serviceaccount" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.configure-ingress-job-serviceaccount.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-ingress-job-serviceaccount.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "configure-ingress-job-clusterrole" {
  template = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:ibm-patch-ingress
rules:
- apiGroups:     ['operator.openshift.io']
  resources:     ['ingresscontrollers']
  verbs:         ['get','patch']
  resourceNames: ['default']
EOF
}

resource "local_file" "configure-ingress-job-clusterrole" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.configure-ingress-job-clusterrole.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-ingress-job-clusterrole.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "configure-ingress-job-clusterrolebinding" {
  template = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:ibm-patch-ingress
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:ibm-patch-ingress
subjects:
  - kind: ServiceAccount
    name: default
    namespace: openshift-ingress-operator
EOF
}

resource "local_file" "configure-ingress-job-clusterrolebinding" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.configure-ingress-job-clusterrolebinding.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-ingress-job-clusterrolebinding.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "configure-ingress-job" {
  template = <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ibm-configure-ingress
  namespace: openshift-ingress-operator
spec:
  parallelism: 1
  completions: 1
  template:
    metadata:
      name: configure-ingress
      labels:
        app: configure-ingress
    serviceAccountName: infra
    spec:
      containers:
      - name:  client
        image: quay.io/openshift/origin-cli:latest
        command: ["/bin/sh","-c"]
        args: ["while ! /usr/bin/oc get ingresscontrollers.operator.openshift.io default -n openshift-ingress-operator >/dev/null 2>&1; do sleep 1;done;/usr/bin/oc patch ingresscontrollers.operator.openshift.io default -n openshift-ingress-operator --type merge --patch '{\"spec\": {\"nodePlacement\": {\"nodeSelector\": {\"matchLabels\": {\"node-role.kubernetes.io/infra\": \"\"}}}}}'"]
      restartPolicy: Never
EOF
}

resource "local_file" "configure-ingress-job" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.configure-ingress-job.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-ingress-job.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}


data "template_file" "private-cluster-outbound-service" {
  template = <<EOF
---
apiVersion: v1	
kind: Service	
metadata:	
  namespace: openshift-config-managed	
  name: outbound-provider
spec:	
  type: LoadBalancer	
  ports:	
  - port: 27627	
EOF	
}

resource "local_file" "private-cluster-outbound-service" {
  count    = var.private ? (var.outbound_udr ? 0 : 1) : 0
  content  = data.template_file.private-cluster-outbound-service.rendered
  filename = "${local.installer_workspace}/openshift/99_private-cluster-outbound-service.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}


data "template_file" "airgapped_registry_upgrades" {
  count    = var.airgapped["enabled"] ? 1 : 0
  template = <<EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: airgapped
spec:
  repositoryDigestMirrors:
  - mirrors:
    - ${var.airgapped["repository"]}
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - ${var.airgapped["repository"]}
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF
}

resource "local_file" "airgapped_registry_upgrades" {
  count    = var.airgapped["enabled"] ? 1 : 0
  content  = data.template_file.airgapped_registry_upgrades.*.rendered[count.index]
  filename = "${local.installer_workspace}/openshift/99_airgapped_registry_upgrades.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

### Auto Approve

data "template_file" "csr_auto_approve_namespace" {
  count    = !var.managed_infrastructure ? 1 : 0
  template = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: csr-auto-approve
EOF
}

resource "local_file" "csr_auto_approve_namespace_yaml" {
  count    = !var.managed_infrastructure ? 1 : 0
  content  = data.template_file.csr_auto_approve_namespace[0].rendered
  filename = "${local.installer_workspace}/manifests/csr-auto-approve-namespace.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "csr_auto_approve_serviceaccount" {
  count    = !var.managed_infrastructure ? 1 : 0
  template = <<EOF
kind: ServiceAccount
apiVersion: v1
metadata:
  name: csr-auto-approve-service-account
  namespace: csr-auto-approve
EOF
}

resource "local_file" "csr_auto_approve_serviceaccount_yaml" {
  count    = !var.managed_infrastructure ? 1 : 0
  content  = data.template_file.csr_auto_approve_serviceaccount[0].rendered
  filename = "${local.installer_workspace}/manifests/csr-auto-approve-serviceaccount.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "csr_auto_approve_clusterrole" {
  count    = !var.managed_infrastructure ? 1 : 0
  template = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    openshift.io/description: "Cluster Role for CSR Auto Approve"
  name: csr-auto-approve-cluster-role
  namespace: csr-auto-approve
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
EOF
}

resource "local_file" "csr_auto_approve_clusterrole_yaml" {
  count    = !var.managed_infrastructure ? 1 : 0
  content  = data.template_file.csr_auto_approve_clusterrole[0].rendered
  filename = "${local.installer_workspace}/manifests/csr-auto-approve-clusterrole.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "csr_auto_approve_clusterrolebinding" {
  count    = !var.managed_infrastructure ? 1 : 0
  template = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: csr-auto-approve-cluster-role-binding
subjects:
- kind: ServiceAccount
  name: csr-auto-approve-service-account
  namespace: csr-auto-approve
roleRef:
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
  name: csr-auto-approve-cluster-role
EOF
}

resource "local_file" "csr_auto_approve_clusterrolebinding_yaml" {
  count    = !var.managed_infrastructure ? 1 : 0
  content  = data.template_file.csr_auto_approve_clusterrolebinding[0].rendered
  filename = "${local.installer_workspace}/manifests/csr-auto-approve-clusterrolebinding.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "csr_auto_approve_configmap" {
  count    = !var.managed_infrastructure ? 1 : 0
  template = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: data
  namespace: csr-auto-approve
data:
  node.count: "${local.node_count}"
  approve.sh: |-
    #!/bin/bash
    EXPECTED_NODE_COUNT=`cat /data/node.count`
    CURRENT_NODE_COUNT=`oc get nodes | grep worker | grep ' Ready' | wc -l`
    while [ "$CURRENT_NODE_COUNT" -lt "$EXPECTED_NODE_COUNT"  ] ;
    do
        PENDING_CSRS=`oc get csr | grep Pending | awk '{ print $1 }'`
        for CSR in $PENDING_CSRS
        do
          echo "CSR auto approve approving CSR: $CSR"
          oc adm certificate approve $CSR
        done
        echo "CSR auto approve sleeping for 30 seconds..."
        sleep 30
        CURRENT_NODE_COUNT=`oc get nodes | grep worker | grep ' Ready' | wc -l`
    done
EOF
}

resource "local_file" "csr_auto_approve_configmap_yaml" {
  count    = !var.managed_infrastructure ? 1 : 0
  content  = data.template_file.csr_auto_approve_configmap[0].rendered
  filename = "${local.installer_workspace}/manifests/csr-auto-approve-configmap.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "csr_auto_approve_job" {
  count    = !var.managed_infrastructure ? 1 : 0
  template = <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: csr-auto-approve-job
  labels:
    app: csr-auto-approve-job
  namespace: csr-auto-approve
spec:
  parallelism: 1
  completions: 1
  activeDeadlineSeconds: 7200
  ttlSecondsAfterFinished: 3600
  backoffLimit: 6
  template:
    metadata:
      name: csr-auto-approve
      labels:
        app: csr-auto-approve
      namespace: csr-auto-approve
    spec:
      serviceAccountName: csr-auto-approve-service-account
      nodeSelector:
        node-role.kubernetes.io/master: ""
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
        operator: Exists
      containers:
      - name: auto-approve
        image: registry.redhat.io/openshift4/ose-cli
        command:
          - /data/approve.sh
        volumeMounts:
        - name: data
          mountPath: /data/node.count
          subPath: node.count
        - name: data
          mountPath: /data/approve.sh
          subPath: approve.sh
      volumes:
        - name: data
          configMap:
            name: data
            defaultMode: 0755
      restartPolicy: Never
EOF
}

resource "local_file" "csr_auto_approve_job_yaml" {
  count    = !var.managed_infrastructure ? 1 : 0
  content  = data.template_file.csr_auto_approve_job[0].rendered
  filename = "${local.installer_workspace}/manifests/csr-auto-approve-job.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}
