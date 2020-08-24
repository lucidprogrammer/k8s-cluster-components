#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# shellcheck disable=SC2002,SC2128,SC2207,SC2034
ISTIO_RELEASE=1.7.0
export DIR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
CHARTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )/chart/cluster-components-operator/charts/" && pwd )"
CRDS="$( cd "$( dirname "${BASH_SOURCE[0]}" )/cluster-components/deploy/crds" && pwd )"

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
    fi
fi

if command -v svn 2>/dev/null; then
   if [ -n "$status" ]; then
    svn export --force https://github.com/istio/istio/tags/"${ISTIO_RELEASE}"/manifests/charts/istio-operator "${CHARTS}"/istio-operator
    sed 's|^hub:.*|hub: docker.io/istio|' -i "${CHARTS}"/istio-operator/values.yaml
    sed "s|^tag:.*|tag: ${ISTIO_RELEASE}|" -i "${CHARTS}"/istio-operator/values.yaml
   fi
else
   echo "You don't have svn, please make sure you have svn"; exit 1
fi

cp "${CRDS}"/*_crd.yaml "${DIR}"/chart/cluster-components-operator/templates/
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

$python "${DIR}"/update-templates.py

docker build -t lucidprogrammer/cluster-components-operator:"${TAG}" -f "${DIR}"/cluster-components/build/Dockerfile "${DIR}"/cluster-components/
docker login -u lucidprogrammer -p "${LUCID_DOCKER_HUB_PASSWORD}"
docker push lucidprogrammer/cluster-components-operator:"${TAG}"
if [[ "${TAG}" == v* ]]; then
   helm lint "${DIR}"/chart/cluster-components-operator
   helm package "${DIR}"/chart/cluster-components-operator --destination "${DIR}"/chart/
   helm repo index --url https://lucidprogrammer.github.io/k8s-cluster-components/chart/ "${DIR}"/chart/
   git config --local user.email "action@github.com"
   git config --local user.name "GitHub Action"
   git add .
   git commit -m "Changes for Release $TAG"
fi
