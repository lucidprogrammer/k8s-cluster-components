#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

# shellcheck disable=SC2143
os="$(uname -s)"
#lower case
os="${os,,}"
if [ "$os" != "linux" ]; then
    echo "Scripts are for linux";exit 1
fi
flavour="$(hostnamectl | awk '{$1=$1;print}'|awk '/^Opera/')"
flavour="${flavour,,}"
echo "$flavour"

if [[ "$flavour" != *ubuntu* ]]; then
    echo "Scripts are for ubuntu" exit 1
fi

RELEASE_VERSION=v1.7.2
# https://sdk.operatorframework.io/docs/installation/
export ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(uname -m) ;; esac)
export OS=$(uname | awk '{print tolower($0)}')
if ! command -v operator-sdk 2>/dev/null; then
    export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/${RELEASE_VERSION}
    curl -LO ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
    curl -LO ${OPERATOR_SDK_DL_URL}/ansible-operator_${OS}_${ARCH}
    curl -LO ${OPERATOR_SDK_DL_URL}/helm-operator_${OS}_${ARCH}
    
    chmod +x operator-sdk_${OS}_${ARCH} && sudo mv operator-sdk_${OS}_${ARCH} /usr/local/bin/operator-sdk
    chmod +x ansible-operator_${OS}_${ARCH} && sudo mv ansible-operator_${OS}_${ARCH} /usr/local/bin/ansible-operator
    chmod +x helm-operator_${OS}_${ARCH} && sudo mv helm-operator_${OS}_${ARCH} /usr/local/bin/helm-operator
fi

if ! command -v ansible 2>/dev/null; then
    pip install ansible
    pip install ansible-runner
    pip install ansible-runner-http
fi
if [ -z "$(pip list | grep openshift)" ]; then
     pip install openshift
     ansible-galaxy collection install -r "${DIR}"/cluster-components/requirements.yml
fi
helmRequiredVersion="v3.5.4"
if ! command -v helm 2>/dev/null; then
      
    bits="$(uname -m)"
    [[ $bits == *"64"* ]] && bits="64" || bits="32"

    hfile="helm-${helmRequiredVersion}-${os}-amd${bits}.tar.gz"
    url="https://get.helm.sh/$hfile"
    echo "downloading helm from $url"
    curl -o /tmp/"$hfile" -sSL "$url"
    tar xvf /tmp/"$hfile" -C /tmp
    sudo mv /tmp/"${os}"-amd"${bits}"/helm /usr/local/bin/
    rm /tmp/"$hfile"
    rm -rf /tmp/"${os}"-amd"${bits}"
      
fi
if ! command -v svn 2>/dev/null; then
    sudo apt install subversion -y
fi

check_docker(){
    # we are expecting a linux kernal greater than 4
    # numerical comparison
    kernal_version=("$(IFS=.; arr=($(uname -r)); echo "${arr[0]}";unset IFS;)")
    if [ "$kernal_version" -lt 4 ]; then
        echo "Kernal Version is less than 4, exiting";exit 1
    fi
    Distribution="$(lsb_release -si)"
    if [ "${Distribution,,}" != ubuntu ]; then
        echo " This script is created for Ubuntu, exiting";exit 1
    fi

    local docker_version_needed="${DOCKER_SEMVER:-"18.09.9"}"
    IFS=.;  read -r major minor patch <<<"$docker_version_needed" ;unset IFS;
    minor="$(printf %d "${minor#0}")"
    local available_docker_version
    available_docker_version="$(docker version --format '{{json .Client.Version}}' 2>/dev/null)"
    available_docker_version="${available_docker_version//\"/}"

    if  ! command -v docker 2>/dev/null  ; then
        sudo apt-get update && sudo apt-get install -y docker.io
        sudo groupadd docker 2>/dev/null
        sudo systemctl stop  docker.service
        sudo systemctl disable  docker.service
        # we need to setup the docker daemon to support ipv6
        if [ -f /lib/systemd/system/docker.service ]; then
            line="$(cat < /lib/systemd/system/docker.service | awk -v pat="ExecStart" '$0 ~ pat {print $0}')"
            replace="${line} --ipv6=true --fixed-cidr-v6=2001:db8:1::/64"
            sudo sed -i "s|${line}|${replace}|" /lib/systemd/system/docker.service
        fi
        sudo systemctl daemon-reload
        sudo systemctl start docker.service
        sudo systemctl enable  docker.service
        
        # Human users have UIDs starting at 1000, so you can use that fact to filter out the non-humans:
        human_users="$(cut -d: -f1,3 /etc/passwd | grep -E ':[0-9]{4}$' | cut -d: -f1)"
        # let's all human users to use docker without sudo
        while read -r user
        do
            sudo usermod -aG docker "$user"
        done<<<"$human_users"
    fi
}
check_docker