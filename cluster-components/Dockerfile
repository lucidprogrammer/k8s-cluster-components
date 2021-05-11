FROM alpine:3.12.0 as downloader
RUN apk add --no-cache bash curl subversion \
    && mkdir /src
WORKDIR /src
COPY custom-scripts/download.sh .
RUN  ./download.sh

FROM quay.io/operator-framework/ansible-operator:v1.7.2
ENV KUBECTL_VERSION="v1.19.3"
ENV HELM_VERSION="v3.5.4"
COPY requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY playbooks/ ${HOME}/playbooks/
USER root
RUN curl -L -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && chmod +x /usr/bin/kubectl \
    && curl -o /tmp/helm-${HELM_VERSION}-linux-amd64.tar.gz -sSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz \
    && tar xvf /tmp/helm-${HELM_VERSION}-linux-amd64.tar.gz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/ \
    && rm -rf /tmp/helm-${HELM_VERSION}-linux-amd64.tar.gz \
    && rm -rf /tmp/linux-amd64/
RUN yum install git openssl https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y \
    && yum install jq -y
COPY --from=downloader  --chown=1001:0 /src/vertical-pod-autoscaler/ ${HOME}/vertical-pod-autoscaler/
COPY custom-scripts/create-*.sh ${HOME}/
ENV VPA ${HOME}/vertical-pod-autoscaler/
ENV PATH ${HOME}/.local/bin:${PATH}
ENV CREATE_ELB_MAPPING_AWS ${HOME}/create-elb-mapping.sh
USER 1001
RUN pip3 install awscli --user
