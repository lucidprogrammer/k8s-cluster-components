
# Migrate from v0.19.0 to v1.7.2

The easy migration path is to initialize a new project, re-recreate APIs, then copy pre-v1.0.0 configuration files into the new project.

## Initialize the operator

```bash
operator-sdk init --plugins=ansible --domain cluster.components
```

## Recreate the operators

```bash
declare -a arr=("CertificateManager" "ClusterAutoscaler" "VerticalPodAutoscaler" "ExternalDns" "MetricServer" "Route53NestedSubdomain" "ClusterNamedIstioIngress")

## now loop through the above array
for kind in "${arr[@]}"
do
   echo "Creating Api for $kind"
   operator-sdk create api \
    --group=apps \
    --version=v1 \
    --kind="$kind" \
    --generate-playbook \
    --generate-role 
    
done
```