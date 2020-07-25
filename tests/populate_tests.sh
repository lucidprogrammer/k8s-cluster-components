#!/usr/bin/env bash
# -*- coding: utf-8 -*-
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

CC="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
# shellcheck disable=SC2038
dirs="$(find "${CC}"/cluster-components/deploy/crds/ -type f -name '*_cr.yaml'|xargs -L 1 basename | sed 's/cluster.components_v1alpha1_//; s/_cr.yaml//')"

for dir in $dirs; do
 if [ ! -d "$DIR/$dir" ]; then
    mkdir -p "$DIR/$dir"
 fi
 if [ ! -f "$DIR/$dir/cluster.components_v1alpha1_${dir}_cr.yaml" ]; then
    cp "${CC}"/cluster-components/deploy/crds/cluster.components_v1alpha1_"${dir}"_cr.yaml "$DIR/$dir"/
 fi
done