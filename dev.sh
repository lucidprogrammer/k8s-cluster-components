#!/usr/bin/env bash
# -*- coding: utf-8 -*-
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
action="${1:-""}"

function make_cr_absent(){
local CC=$1
# shellcheck disable=SC2038
crs="$(find "${CC}"/cluster-components/deploy/crds/ -type f -name '*_cr.yaml'|xargs -L 1 basename | sed 's/cluster.components_v1alpha1_//; s/_cr.yaml//')"

for cr in $crs; do
entry="$(kubectl get "$cr" --all-namespaces -o=custom-columns='namespace:metadata.namespace,name:metadata.name' 2>/dev/null | awk 'FNR ==1 {next} {print $0}')"
if [ -n "$entry" ]; then
        # d="$(echo "$entry" | awk -v cr="$cr" '{print "kubectl -n " $1 " delete " cr " "  $2  }')"
        patch="$(echo "$entry" | awk -v cr="$cr" '{print "kubectl -n " $1 " patch " cr " "  $2  }')"
        patch="$patch --type='json' -p"
        payload=$(cat <<EOT
'[{"path": "/spec/state","op":"replace","value":"absent"}]'
EOT
)
        op="$patch $payload"
        echo "$op" 
        eval "$op" &
        op_pid=$!
        wait "$op_pid"

fi
done

}




if [ "${action}" == start ]; then
    find "${DIR}"/cluster-components/deploy/crds/ -type f -name '*_crd.yaml' | awk '{print  $1}' | xargs -L 1 kubectl  apply -f
    kubectl apply -f "${DIR}"/cluster-components/deploy/
    cd "${DIR}"/cluster-components || exit 1
    operator-sdk run --watch-namespace "" local 
elif [ "${action}" == stop ]; then
    dep="$(kubectl get deployments -l app=cluster-components-operator --all-namespaces 2>/dev/null)"
    operator_process=""
    if [ -z "$dep" ]; then
        find "${DIR}"/cluster-components/deploy/crds/ -type f -name '*_crd.yaml' | awk '{print  $1}' | xargs -L 1 kubectl  apply -f
        kubectl apply -f "${DIR}"/cluster-components/deploy/
        cd "${DIR}"/cluster-components || exit 1
        operator-sdk run --watch-namespace "" local  &
        operator_process=$!
        sleep 20
    fi
    make_cr_absent "$DIR" &
    kill_process=$!
    wait "$kill_process"
    if [ -n "$operator_process" ]; then
        # find "${DIR}"/cluster-components/deploy/crds/ -type f -name '*_crd.yaml' | awk '{print  $1}' | xargs -L 1 kubectl  delete -f
        # kubectl delete -f "${DIR}"/cluster-components/deploy/
        echo "

        Wait to see the operator logs that it settles and kill the process $operator_process and remove crds
        
        "
        
    else
        echo "Check the deployment, or remove helm release associated with $dep"
    fi
fi


