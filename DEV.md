# Overview

To start development, 

```bash
# first make your AWS_PROFILE is is exported
export AWS_PROFILE=profilename
make -C cluster-components install run
```

Then apply the required cr to see its working and apply changes accordingly.

When you are done, clean resources applied (cr) and do the following.

```bash
make -C cluster-components uninstall
```

## Creating a new api

```bash
kind=yournewapi
 operator-sdk create api \
    --group=apps \
    --version=v1 \
    --kind="$kind" \
    --generate-playbook \
    --generate-role 
```