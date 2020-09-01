![Release Actions](https://github.com/lucidprogrammer/k8s-cluster-components/workflows/Release%20Actions/badge.svg)

# Overview

An operator for useful Kubernetes Cluster Components.

It should work on most of the clusters, however, tested only on EKS.


## Installation

### Helm

```bash
helm repo add lucid https://lucidprogrammer.github.io/k8s-cluster-components/chart/
# if you wish to search the versions available
helm search repo -l lucid/cluster-components-operator
# with great power comes great responsibility. make sure you create a namespace with access only to admins
kubectl create namespace cluster-operator # resources are created there, so avoid service account leak for non admins
# install, by default it installs istio-operator also
helm install -n cluster-operator cluster-components-operator lucid/cluster-components-operator
# install without isio-operator
helm install cluster-components-operator --set istioOperator.install=false lucid/cluster-components-operator
```

## Non Mandatory configmap

While creating the cluster, say terraform, if you create a configmap like the following, you may be able to use most of the Custom Resources without even providing any specific values, helpful if you are managing multiple clusters and using gitops to manage the same file for multiple clusters for consistency.
```yaml
apiVersion: v1
data:
  cluster_name: name
  provider: aws
  region: us-east-1
  route53_hosted_zone: some.com  # if applicable
  route53_role_arn: arn:aws:iam::xxxx:role/some_route53_role # if you have multiple aws accounts and need to assume role
kind: ConfigMap
metadata:
  name: cluster-info
  namespace: kube-system
```

## Declaratively specify to install or not

You could specify present/absent on the yaml instead of deleting or commenting out the yaml in gitops scenarios.

## Cluster Autoscaler

```yaml
apiVersion: cluster.components/v1alpha1
kind: ClusterAutoscaler
metadata:
  name: cluster-autoscaler
spec:
  # cluster_name: "clname" # if you don't provide this, will look for a configmap cluster-info in kube-system
  state: "absent"  # give the value present if the operator need to create the autoscaler.
```
## Vertical Pod Autoscaler

```yaml
apiVersion: cluster.components/v1alpha1
kind: VerticalPodAutoscaler
metadata:
  name: example-verticalpodautoscaler
spec:
  # Add fields here
  state: "absent"
```

## Metric Server
If your cluster does not have metric-server already installed, you need it for the proper working of both the VPA and HPA

```yaml
apiVersion: cluster.components/v1alpha1
kind: MetricServer
metadata:
  name: example-metricserver
spec:
  # Add fields here
  state: "present"
```
## External DNS

```yaml
apiVersion: cluster.components/v1alpha1
kind: ExternalDns
metadata:
  name: example-externaldns
spec:
  # Add fields here
  state: "absent"
  cluster_info: "present" # will pick up details from your cluster-info and configures automatically or specify other params
  # cloud_provider: aws
  # domain_filter: "domain.com"
  # assume_role_arn:
  # owner_id: # if cluster-info configmap is there, we will pick up cluster_name and use it as the owner_id
```
## Certificate Manager
This will look for cert-manager namespace and will not create that automatically.
```yaml
apiVersion: cluster.components/v1alpha1
kind: CertificateManager
metadata:
  name: example-certificatemanager
spec:
  state: "absent"
  cluster_issuer:
    cluster_info: "present" # if this is present, everything is set automatically
    state: "absent"
    namespace: "default" # namespace where you want the clusterissuer ex: istio-system
    name: "letsencrypt-production-issuer"
    acme:
      email: "lucid@somewhere.com"
      server: "https://acme-v02.api.letsencrypt.org/directory"
      # solvers:
      # - selector:
      #     dnsZones:
      #     - "yourzone"
      #   dns01:
      #     route53:
      #       region: us-east-2
      #       role: arn:aws:iam::xxx:role/external_route53_role    
```
## Route53NestedSubdomain
External Dns does not satisfy all use cases as it does not support some of the major Gateway implementations.

This operator fills that gap. Support same account or cross account route53 resources.

```yaml
apiVersion: cluster.components/v1alpha1
kind: Route53NestedSubdomain
metadata:
  name: example-route53nestedsubdomain
spec:
  # Add fields here
  state: "absent"
  # this should create something.somewhere.example.com and *.something.somewhere.example.com
  # you should have setup instance profile for aws security to avoid any keys passed for this to work.
  subdomain: "something.somewhere"
  edge_proxy_namespace: "default"
  # route53_hosted_zone: "example.com" # these commented items could come from cluster-info if you setup that.
  # edge_proxy_service_name: "gateway-proxy"
  # aws_default_region: "us-east-1"
```
## ClusterNamedIstioIngress

One common use case is where you want to use the name of the cluster to say expose grafana or such common services. 

If you are managing multiple clusters and want a simple way to manage it without the need to manage multiple files/folders(gitops), you could just drop in this type of a cr in your monitoring/observability namespace.

```yaml
apiVersion: cluster.components/v1alpha1
kind: ClusterNamedIstioIngress
metadata:
  name: example-clusternamedistioingress
spec:
  # Add fields here
  state: "present"
  service_namespace: "observability"
  service_name: "grafana"
  service_port: 3000
  subdomain: "grafana"
  # the above configuration assumes a cluster-info configmap 
  # if cluster_name is my-cluster and route53_hosted_zone is example.com, you should get my-cluster.grafana.example.com
```
## Istio
If you haven't disabled istio-operator, you could create istio deployment too.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
---
# https://istio.io/docs/reference/config/istio.operator.v1alpha1/#IstioOperatorSpec
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: istiocontrolplane
spec:
  profile: default

```