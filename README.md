# OpenShift 4 UPI on Azure Cloud




This [terraform](terraform.io) implementation will deploy OpenShift 4.x into an Azure Managed Subscription.  Traffic to the master nodes is handled via a pair of loadbalancers, one for internal traffic and another for external API traffic.  Application loadbalancing is handled by a third loadbalancer that talks to the router pods on the infra nodes.  Worker, Infra and Master nodes are deployed across 3 Availability Zones. 

** Note that this version can implement the following custom scenarios as needed:
1. leverage an existing Azure Storage Account for coreos vhd, boot logs, and installer ignition files
2. predefine the load balancer IPs for the existing DNS record sets (api, api-int, and *.app)
3. remove cluster self-manangement capabilites and deploy using terraform only.
4. use a managed disk to stage coreos vhd instead of an Azure Storage Account.
5. Deploy rhcos from Azure market place. To do so use `azure_shared_image = false` and `azure_image_id = "true"` and perform step 3 beloe before applying Terraform



![Topology](./media/topology.svg)

## Prerequisites

1. [Create a Service Principal](https://github.com/openshift/installer/blob/d0f7654bc4a0cf73392371962aef68cd9552b5dd/docs/user/azure/credentials.md) with proper IAM roles. Note that more granular Azure Roles can be used. Please see related [doc](docs/azure_roles.md)


## Minimal TFVARS file

```terraform
azure_region = "eastus2"
cluster_name = "ocp4"

# From Prereq. Step #1
base_domain                           = "azure.example.com"
azure_base_domain_resource_group_name = "openshift4-common-rg"

# From Prereq. Step #2
azure_subscription_id  = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
azure_tenant_id        = "YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY"
azure_client_id        = "ZZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ"
azure_client_secret    = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"

# Storage Account
azure_storage_rg                  = "XXXX"
azure_storage_account_name        = "XXXX"


```

## Customizable Variables

| Variable                              | Description                                                    | Default         | Type   |
| ------------------------------------- | -------------------------------------------------------------- | --------------- | ------ |
| azure_subscription_id                 | Subscription ID for Azure Account                              | -               | string |
| azure_tenant_id                       | Tenant ID for Azure Subscription                               | -               | string |
| azure_client_id                       | Application Client ID (from Prereq Step #2)                    | -               | string |
| azure_client_secret                   | Application Client Secret (from Prereq Step #2)                | -               | string |
| azure_region                          | Azure Region to deploy to                                      | -               | string |
| cluster_name                          | Cluster Identifier                                             | -               | string |
| master_count                          | Number of master nodes to deploy                               | 3               | string |
| worker_count                          | Number of worker nodes to deploy                               | 3               | string |
| infra_count                           | Number of infra nodes to deploy                                | 0               | string |
| infra_number_of_disks_per_node        | Number of data disk per infra node                             | 1               | string |
| infra_data_disk_size_GB               | Size of data disk for infra node                               | 0               | string |
| machine_v4_cidrs                      | IPv4 CIDR for OpenShift VNET                                   | \[10.0.0.0/16\] | list   |
| machine_v6_cidrs                      | IPv6 CIDR for OpenShift VNET                                   | \[\]               | list   |
| base_domain                           | DNS name for your deployment                                   | -               | string |
| azure_base_domain_resource_group_name | Resource group where DNS is hosted.  Must be on zame region.   | -               | string |
| azure_bootstrap_vm_type               | Size of bootstrap VM                                           | Standard_D4s_v3 | string |
| azure_master_vm_type                  | Size of master node VMs                                        | Standard_D8s_v3 | string |
| azure_infra_vm_type                   | Size of infra node VMs                                         | Standard_D16s_v3 | string |
| azure_worker_vm_type                  | Sizs of worker node VMs                                        | Standard_D8s_v3 | string |
| openshift_cluster_network_cidr        | CIDR for Kubernetes pods                                       | 10.128.0.0/14   | string |
| openshift_cluster_network_host_prefix | Detemines the number of pods a node can host.  23 gives you 510 pods per node. | 23 | string |
| openshift_service_network_cidr        | CIDR for Kubernetes services                                   | 172.30.0.0/16   | string |
| openshift_pull_secret                 | Filename that holds your OpenShift [pull-secret](https://cloud.redhat.com/openshift/install/azure/installer-provisioned) | - | string |
| openshift_pull_secret_string          | pull-secret as a string and escaped for doubled quotes. Can be used instead of openshift_pull_secret. Ex: {\\"auths\\": {\\"cloud.openshift.com\\": {\\"auth\\": \\"XYZ\\"}}}  | "" | string |
| azure_master_root_volume_size         | Size of master node root volume                                | 512             | string |
| azure_worker_root_volume_size         | Size of worker node root volume                                | 128             | string |
| azure_infra_root_volume_size          | Size of infra node root volume                                 | 128             | string |
| azure_master_root_volume_type         | Storage type for master root volume                            | Premium_LRS     | string |
| openshift_version                     | Version of OpenShift to deploy.                                | 4.6.13          | strig |
| bootstrap_completed                   | Control variable to delete bootstrap node after initialization | false           | bool |
| azure_private                         | If set to `true` will deploy `api` and `*.apps` endpoints as private LoadBalancers | - | bool |
| azure_extra_tags                      | Extra Azure tags to be applied to created resources            | {}              | map |
| airgapped                             | Configuration for an AirGapped environment                     | [AirGapped](AIRGAPPED.md) | map |
| azure_environment                     | The target Azure cloud environment for the cluster             | public | string |
| azure_master_availability_zones       | The availability zones in which to create the masters. The length of this list must match `master_count`| ["1","2","3"]| list |
| azure_preexisting_network             | Specifies whether an existing network should be used or a new one created for installation. | false | bool |
| azure_resource_group_name             | The name of the resource group for the cluster. If this is set, the cluster is installed to that existing resource group otherwise a new resource group will be created using cluster id. | -               | string |
| azure_network_resource_group_name     | The name of the network resource group, either existing or to be created | `null` | string |
| azure_virtual_network                 | The name of the virtual network, either existing or to be created | `null` | string |
| azure_control_plane_subnet            | The name of the subnet for the control plane, either existing or to be created | `null` | string |
| azure_compute_subnet                  | The name of the subnet for worker nodes, either existing or to be created | `null` | string |
| azure_emulate_single_stack_ipv6       | This determines whether a dual-stack cluster is configured to emulate single-stack IPv6 | false | bool |
| azure_outbound_user_defined_routing   | This determined whether User defined routing will be used for egress to Internet. When `false`, Standard LB will be used for egress to the Internet. | false | bool |
| use_ipv4                              | This determines wether your cluster will use IPv4 networking | true | bool |
| use_ipv6                              | This determines wether your cluster will use IPv6 networking | false | bool |
| proxy_config                          | Configuration for Cluster wide proxy | [AirGapped](AIRGAPPED.md)| map |
| openshift_ssh_key | Your own SSH Public Key as a String.  If none provided it will create one for you | - | string |
| openshift_additional_trust_bundle | Path to your trusted CA bundle in pem format | - | string |
| openshift_additional_trust_bundle_string | Contents of the your trusted CA bundle in pem format | - | string |
| azure_image_id | The azure image id for the coreos vm boot image | - | string |
| azure_shared_image                    | Should the coreos image be stored in a repository | true | bool |
| azure_shared_image_repo_name          | If a repository is being used for the image, the name of the repository | - | string |
| azure_shared_image_name               | If a repository is being used for the image, The name of the existing image | - | string |
| azure_image_storage_rg | Existing Storage Account Resource Group for the VM Image | - | string |
| azure_image_storage_account_name | Existing Storage Account Name for the VM Image | - | string |
| azure_image_blob_uri | The azure image blog uri for the vm vhd file. The vhd must be in the same subscription as the vm | - | string |
| azure_image_container_name | Azure Container name storing the VM Image vhd file | - | string |
| azure_image_blob_name | Azure blob which is the coreos vhd file | - | string |
| azure_ignition_storage_rg | Existing Storage Account Resource Group for the ignition files | - | string |
| azure_ignition_storage_account_name | Existing Storage Account Name for the ignition files | - | string |
| azure_ignition_sas_container_name | Azure Container name storing the ignition files | - | string |
| azure_ignition_sas_token | The SAS storage token string for the ignition files | - | string |
| azure_bootlogs_storage_rg | Existing Storage Account Resource Group for the boot diagnostic files | - | string |
| azure_bootlogs_storage_account_name | Existing Storage Account Name for the boot diagnostic files | - | string |
| azure_bootlogs_sas_token | The SAS storage token string for the boot diagnostic files | - | string |
| phased_approach                       | If `phased_approach=true` then no machines are deployed. This allows user to get the generated load balancer IP to populate DNS entries before proceeding. This is not needed if using defining IP value for `api_and_api-int_dns_ip`. Note that if set to true then `phase1_complete` should be used as well.   | `false` | bool
| phase1_complete        | Used with `phased_approach`. Set to true once DNS records are created | `false` | bool
| api_and_api-int_dns_ip  | Used to define the front end IP of the Load Balancer created during install | `null` | string 
| apps_dns_ip | Used to set the front end IP of the internal load-balancer for *.apps record set. | `null` | string
| azure_role_id_cluster | If needed, provide the ID of the Azure Custom Role scoped for the main Cluster Resource Group | `null` | string
| azure_role_id_network | If needed, provide the ID of the Azure Custom Role scoped for the network Resource Group | `null` | string
| use_default_imageregistry | Define if you want to use the default imageregistry that is created with the install | `true` | bool
| openshift_managed_infrastructure | Define if the infrastructure is managed by openshift (IPI) | `true` | bool
| azure_worker_root_volume_type | The type of the volume the root block device of worker nodes | Premium_LRS | string
| openshift_dns_provider | Specify whether 'azure', 'infoblox', or '' should be used as the dns provider.  If manual or none, set to '' | azure | string
| infoblox_fqdn | The Infoblox host fully qualified domain name or ip address | - | string
| infoblox_username | The Infoblox credentials username | - | string
| infoblox_password | The Infoblox credentials password | - | string
| infoblox_allow_any | Is the Infoblox allow any policy set to default, allowing wildcard dns names" | `false` | bool
| infoblox_apps_dns_entries | The list of openshift *.apps dns entires if wildcards are not supported by Infoblox | ["oauth-openshift","console-openshift-console","downloads-openshift-console","canary-openshift-ingress-canary","alertmanager-main-openshift-monitoring","grafana-openshift-monitoring","prometheus-k8s-openshift-monitoring","thanos-querier-openshift-monitoring"] | list(string)
| azure_network_introspection | If the network is pre-defined, retrieve the network components via the subscription dynamically | `false` | bool
| azure_resource_group_name_substring | Azure Resource Group Name filter using the provided substring for dynamically populating the resource group name | - | string
| azure_control_plane_subnet_substring | Azure Subnet Name filter using the provided substring for dynamically populating the control plane subnet | - | string
| azure_compute_subnet_substring | Azure Subnet Name filter using the provided substring for dynamically populating the compute subnet | - | string
| bootstrap_cleanup | Specify as true if you want to do a second run and remove the bootstrap machine | `false` | bool



## Deploy with Terraform

1. Clone github repository

    ```bash
    git clone git@github.com:ibm-cloud-architecture/terraform-openshift4-azure.git
    ```

2. Create your `terraform.tfvars` file

3. If using rhcos from azure market place then assure that your Service Principle has accepted terms.

    ```bash
    az vm image list --all --offer rh-ocp-worker --publisher redhat-limited -o table | grep rh-ocp
    az vm image show --urn redhat:rh-ocp-worker:rh-ocp-worker:4.8.2021122100
    az vm image terms show --urn redhat:rh-ocp-worker:rh-ocp-worker:4.8.2021122100
    az vm image terms accept --urn redhat:rh-ocp-worker:rh-ocp-worker:4.8.2021122100
    ```

    Details can be found here: https://docs.openshift.com/container-platform/4.10/installing/installing_azure/installing-azure-customizations.html#installation-azure-marketplace-subscribe_installing-azure-customizations

4. Deploy with terraform

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

5. To access your cluster

    ```bash
    $ export KUBECONFIG=$PWD/installer-files/auth/kubeconfig
    ```
    ```
    $ oc get nodes
    NAME                                 STATUS   ROLES          AGE   VERSION
    fs2021-hv0eu-infra-eastus21-6kqlt    Ready    infra,worker   20m   v1.19.0+3b01205
    fs2021-hv0eu-infra-eastus22-m826l    Ready    infra,worker   20m   v1.19.0+3b01205
    fs2021-hv0eu-infra-eastus23-qf4kc    Ready    infra,worker   19m   v1.19.0+3b01205
    fs2021-hv0eu-master-0                Ready    master         30m   v1.19.0+3b01205
    fs2021-hv0eu-master-1                Ready    master         30m   v1.19.0+3b01205
    fs2021-hv0eu-master-2                Ready    master         30m   v1.19.0+3b01205
    fs2021-hv0eu-worker-eastus21-bw8nq   Ready    worker         19m   v1.19.0+3b01205
    fs2021-hv0eu-worker-eastus22-rtwwh   Ready    worker         20m   v1.19.0+3b01205
    fs2021-hv0eu-worker-eastus23-tsw44   Ready    worker         20m   v1.19.0+3b01205
    ```

## Infra and Worker Node Deployment

Check Deployment of Openshift Worker and Infra nodes is handled by the machine-operator-api cluster operator.

```bash
$ oc get machineset -n openshift-machine-api
NAME                           DESIRED   CURRENT   READY   AVAILABLE   AGE
fs2021-hv0eu-infra-eastus21    1         1         1       1           35m
fs2021-hv0eu-infra-eastus22    1         1         1       1           35m
fs2021-hv0eu-infra-eastus23    1         1         1       1           35m
fs2021-hv0eu-worker-eastus21   1         1         1       1           35m
fs2021-hv0eu-worker-eastus22   1         1         1       1           35m
fs2021-hv0eu-worker-eastus23   1         1         1       1           35m

$ oc get machines -n openshift-machine-api
NAME                                 PHASE     TYPE              REGION    ZONE   AGE
fs2021-hv0eu-infra-eastus21-6kqlt    Running   Standard_D4s_v3   eastus2   1      31m
fs2021-hv0eu-infra-eastus22-m826l    Running   Standard_D4s_v3   eastus2   2      31m
fs2021-hv0eu-infra-eastus23-qf4kc    Running   Standard_D4s_v3   eastus2   3      31m
fs2021-hv0eu-master-0                Running   Standard_D8s_v3   eastus2   1      37m
fs2021-hv0eu-master-1                Running   Standard_D8s_v3   eastus2   2      37m
fs2021-hv0eu-master-2                Running   Standard_D8s_v3   eastus2   3      37m
fs2021-hv0eu-worker-eastus21-bw8nq   Running   Standard_D8s_v3   eastus2   1      31m
fs2021-hv0eu-worker-eastus22-rtwwh   Running   Standard_D8s_v3   eastus2   2      31m
fs2021-hv0eu-worker-eastus23-tsw44   Running   Standard_D8s_v3   eastus2   3      31m
```

The infra nodes host the router/ingress pods, all the monitoring infrastrucutre, and the image registry.

Check Status of Cluster Operators

```bash
oc get co 
```
<pre>
NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.8.35    True        False         False      23h
baremetal                                  4.8.35    True        False         False      40d
cloud-credential                           4.8.35    True        False         False      40d
cluster-autoscaler                         4.8.35    True        False         False      40d
config-operator                            4.8.35    True        False         False      40d
console                                    4.8.35    True        False         False      14d
csi-snapshot-controller                    4.8.35    True        False         False      40d
dns                                        4.8.35    True        False         False      38d
etcd                                       4.8.35    True        False         False      40d
image-registry                             4.8.35    True        False         False      40d
ingress                                    4.8.35    True        False         False      40d
insights                                   4.8.35    True        False         False      40d
kube-apiserver                             4.8.35    True        False         False      40d
kube-controller-manager                    4.8.35    True        False         False      40d
kube-scheduler                             4.8.35    True        False         False      40d
kube-storage-version-migrator              4.8.35    True        False         False      33d
machine-api                                4.8.35    True        False         False      40d
machine-approver                           4.8.35    True        False         False      40d
machine-config                             4.8.35    True        False         False      26d
marketplace                                4.8.35    True        False         False      40d
monitoring                                 4.8.35    True        False         False      40d
network                                    4.8.35    True        False         False      40d
node-tuning                                4.8.35    True        False         False      26d
openshift-apiserver                        4.8.35    True        False         False      115m
openshift-controller-manager               4.8.35    True        False         False      9d
openshift-samples                          4.8.35    True        False         False      40d
operator-lifecycle-manager                 4.8.35    True        False         False      40d
operator-lifecycle-manager-catalog         4.8.35    True        False         False      40d
operator-lifecycle-manager-packageserver   4.8.35    True        False         False      40d
service-ca                                 4.8.35    True        False         False      40d
storage                                    4.8.35    True        False         False      38d
</pre>
