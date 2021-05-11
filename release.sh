#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# shellcheck disable=SC2002,SC2128,SC2207,SC2034
ISTIO_RELEASE=1.9.4
export DIR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
CHARTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )/chart/cluster-components-operator/charts/" && pwd )"

if [ -z "${LUCID_DOCKER_HUB_PASSWORD}" ]; then
   echo env LUCID_DOCKER_HUB_PASSWORD not found; exit 1
fi
export TAG
TAG="${TAG:-"latest"}"
status="download"
if [ -f "${CHARTS}"/istio-operator/values.yaml ]; then
    current="$(cat "${CHARTS}"/istio-operator/values.yaml | awk '/^tag/')"
    if [ "$current" == "tag: ${ISTIO_RELEASE}" ]; then
      status=""  
    else
      rm -rf "${CHARTS}"/istio-operator
    fi
fi

if command -v svn 2>/dev/null; then
   if [ -n "$status" ]; then
    svn export --force https://github.com/istio/istio/tags/"${ISTIO_RELEASE}"/manifests/charts/istio-operator "${CHARTS}"/istio-operator
    sed "s|^tag:.*|tag: ${ISTIO_RELEASE}|" -i "${CHARTS}"/istio-operator/values.yaml
   fi
else
   echo "You don't have svn, please make sure you have svn"; exit 1
fi


sed "s|^imageTag:.*|imageTag: ${TAG}|" -i "${DIR}"/chart/cluster-components-operator/values.yaml
if [[ "${TAG}" == v* ]]; then
   chart_version="$(echo "${TAG}" | tr -d v)"
   app_version="${TAG}"
   sed "s|^version:.*|version: ${chart_version}|" -i "${DIR}"/chart/cluster-components-operator/Chart.yaml
   sed "s|^appVersion:.*|appVersion: ${app_version}|" -i "${DIR}"/chart/cluster-components-operator/Chart.yaml
fi

python="python"
version="$(python -c 'import sys; print(sys.version_info[0])')"
if [[ "$version" == 2 ]]; then
   python="python3"
fi

VERSION="$(echo "${TAG}" | tr -d v)"
VERSION="${VERSION}" make -C "$DIR/"cluster-components docker-build
docker login -u lucidprogrammer -p "${LUCID_DOCKER_HUB_PASSWORD}"
VERSION="${VERSION}" make -C "$DIR"/cluster-components docker-push
VERSION="${VERSION}" make -C "$DIR"/cluster-components update-chart
if [[ "${TAG}" == v* ]]; then
   helm lint "${DIR}"/chart/cluster-components-operator
   helm package "${DIR}"/chart/cluster-components-operator --destination "${DIR}"/chart/
   helm repo index --url https://lucidprogrammer.github.io/k8s-cluster-components/chart/ "${DIR}"/chart/
   git config --local user.email "action@github.com"
   git config --local user.name "GitHub Action"
   git add .
   git commit -m "Changes for Release $TAG"
fi
