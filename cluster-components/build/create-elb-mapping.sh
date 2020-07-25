#!/usr/bin/env bash

BINDIR="${BASH_SOURCE%/*}"
if [[ ! -d "$BINDIR" ]]; then BINDIR="$PWD"; fi

# this is the subdomain for your services. could be the namespace where your services are running
subdomain="${1:-""}"
hostedZoneDomain="${2:-""}"

r53=""
elb=""

route_53_assume_role="${ROUTE_53_ASSUME_ROLE:-""}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-""}"

if [ -z "$route_53_assume_role" ]; then
    info="$(kubectl -n kube-system get configmap cluster-info -o json 2>/dev/null)"
    if [ -n "$info" ]; then
        if [ -z "${3:-""}" ]; then
            route_53_assume_role="$(echo "$info" | jq '.data.route53_role_arn' | tr -d '"' | sed 's/null//')"
        fi
        if [ -z "${AWS_DEFAULT_REGION}" ];then
            AWS_DEFAULT_REGION="$(echo "$info" | jq '.data.region' | tr -d '"' | sed 's/null//')"
        fi
        if [ -z "${hostedZoneDomain}" ]; then
            hostedZoneDomain="$(echo "$info" | jq '.data.route53_hosted_zone' | tr -d '"' | sed 's/null//')"
        fi
    fi
fi

if [ -n "$route_53_assume_role" ]; then
    r53="$(printf "\n[r53]\nrole_arn = %s\ncredential_source = Ec2InstanceMetadata\n" "${route_53_assume_role}")"
fi

if [ -z "${r53}" ] && [ -n "${AWS_ACCESS_KEY_ID_R53}" ] && [ -n "${AWS_SECRET_ACCESS_KEY_R53}" ] && [ -n "${AWS_DEFAULT_REGION_R53}" ]; then
    r53="$(printf "\n[r53]\naws_access_key_id = %s\naws_secret_access_key = %s\nregion = %s\n" "${AWS_ACCESS_KEY_ID_R53}" "${AWS_SECRET_ACCESS_KEY_R53}" "${AWS_DEFAULT_REGION_R53}")"
fi
if [ -n "${AWS_ACCESS_KEY_ID_ELB}" ] && [ -n "${AWS_SECRET_ACCESS_KEY_ELB}" ] && [ -n "${AWS_DEFAULT_REGION_ELB}" ]; then
    elb="$(printf "\n[elb]\naws_access_key_id = %s\naws_secret_access_key = %s\nregion = %s\n" "${AWS_ACCESS_KEY_ID_ELB}" "${AWS_SECRET_ACCESS_KEY_ELB}" "${AWS_DEFAULT_REGION_ELB}")"
fi
if [ -n "${r53}" ] && [ -n "${elb}" ]; then
    config_file="$(mktemp)"
    printf "%s\n%s" "${r53}" "${elb}" >> "$config_file"
    chmod 600 "$config_file"
    export AWS_CONFIG_FILE="$config_file"
    export AWS_SHARED_CREDENTIALS_FILE="$config_file"
    echo "Using aws config file $config_file"
    cat "$config_file"
    # change the input variables
    action="${5:-""}" #as we are mutating input, let's have them all
    set -- "$subdomain" "$hostedZoneDomain" "r53" "elb" "$action"
    
fi
if [ -z "${r53}" ] && [ -n "${elb}" ]; then
    config_file="$(mktemp)"
    printf "%s"  "${elb}" >> "$config_file"
    chmod 600 "$config_file"
    export AWS_CONFIG_FILE="$config_file"
    export AWS_SHARED_CREDENTIALS_FILE="$config_file"
    echo "Using aws config file $config_file"
    cat "$config_file"
    # change the input variables
    action="${5:-""}" #as we are mutating input, let's have them all
    set -- "$subdomain" "$hostedZoneDomain" "default" "elb" "$action"
    
fi
if [ -n "${r53}" ] && [ -z "${elb}" ]; then
    config_file="$(mktemp)"
    printf "%s"  "${r53}" >> "$config_file"
    chmod 600 "$config_file"
    export AWS_CONFIG_FILE="$config_file"
    export AWS_SHARED_CREDENTIALS_FILE="$config_file"
    echo "Using aws config file $config_file"
    cat "$config_file"
    # change the input variables
    action="${5:-""}" #as we are mutating input, let's have them all
    set -- "$subdomain" "$hostedZoneDomain" "r53" "default" "$action"
    
fi

profileForRoute53Changes="${3:-""}"
# if your aws resources are owned by another aws account.
profileOwningELB="${4:-""}"
action="${5:-"UPSERT"}"


EDGE_PROXY_NAMESPACE="${EDGE_PROXY_NAMESPACE:-""}"
EDGE_PROXY_SERVICE_NAME="${EDGE_PROXY_SERVICE_NAME:-"gateway-proxy"}"

if [ "${action}" == UPSERT ] && [[ "${EDGE_PROXY_SERVICE_NAME}" == gateway-proxy ]] && [ -z "${EDGE_PROXY_NAMESPACE}" ]; then
    echo "
    Assuming you have gloo installed, Considering EDGE_PROXY_SERVICE_NAME as gateway-proxy,
    provide EDGE_PROXY_NAMESPACE env variable to know where to look for loadbalancer.
    EDGE_PROXY_SERVICE_NAME env is missing.

    If you are not using gloo, provide EDGE_PROXY_SERVICE_NAME and EDGE_PROXY_NAMESPACE env variables.
    "; exit 1
fi
usage=" Arguments Needed
1: subdomain
2: hostedZoneDomain
3: profileForRoute53Changes (or provide env  AWS_ACCESS_KEY_ID_R53,AWS_SECRET_ACCESS_KEY_R53,AWS_DEFAULT_REGION_R53)
4: profileOwningELB (or provide env AWS_ACCESS_KEY_ID_ELB,AWS_SECRET_ACCESS_KEY_ELB,AWS_DEFAULT_REGION_ELB)
5: action (default is UPSERT, otherwise give DELETE)
Environment Variables:
EDGE_PROXY_NAMESPACE: if gloo you need to know where gloo is running, if istio it could be istio-system
EDGE_PROXY_SERVICE_NAME: by default we take gateway-proxy considering gloo, if istio, make it istio-ingressgateway
"
if [ "${action}" == UPSERT ] && [ -n "${hostedZoneDomain}" ] && [ -n "${subdomain}" ] && [ -n "${profileForRoute53Changes}" ]; then
    mappingTarget="$(kubectl -n "${EDGE_PROXY_NAMESPACE}" get service "${EDGE_PROXY_SERVICE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    if [ -z "$mappingTarget" ]; then
        echo "Mapping target is not yet assigned";exit 1
    fi
    "${BINDIR}"/create-domain-mappings-aws.sh "$profileForRoute53Changes" "${hostedZoneDomain}" "${subdomain}" "${mappingTarget}" "$action" "A" "yes" "$profileOwningELB"
elif [ "${action}" == DELETE ] && [ -n "${hostedZoneDomain}" ] && [ -n "${subdomain}" ] && [ -n "${profileForRoute53Changes}" ]; then
    "${BINDIR}"/create-domain-mappings-aws.sh "$profileForRoute53Changes" "${hostedZoneDomain}" "${subdomain}" "" "$action" "A" "yes"
else 
    echo "Unknown $usage";exit 1
fi
