#!/bin/bash

VPA_VERSION="0.9.2"

export DIR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi


if command -v svn 2>/dev/null; then
   svn export https://github.com/kubernetes/autoscaler/tags/vertical-pod-autoscaler-${VPA_VERSION}/vertical-pod-autoscaler/ "${DIR}"/vertical-pod-autoscaler
else
   echo "You don't have svn, please make sure you have svn"
fi

