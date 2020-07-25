# Overview

To start development, run the following command

```bash
# first make your AWS_PROFILE is is exported
export AWS_PROFILE=profilename
./dev.sh start
```

Then apply the required cr to see its working and apply changes accordingly.

When you are done, clean resources applied (cr) and do the following.

```bash
./dev.sh stop
```
## Testing chart during development

```bash
./release.sh
./dev.sh stop
helm install cluster-components chart/cluster-components-operator
```

## Creating a new api

```bash
operator-sdk add api --api-version=cluster.components/v1alpha1 --kind=Route53NestedSubdomain
```