
FROM alpine:3.12.0 as downloader
RUN apk add --no-cache bash curl subversion \
    && mkdir /src
WORKDIR /src
COPY build/download.sh .
RUN  ./download.sh

FROM quay.io/operator-framework/ansible-operator:v0.19.0
COPY requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
    && chmod -R ug+rwx ${HOME}/.ansible
COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
USER root
RUN curl -L -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.16.8/bin/linux/amd64/kubectl \
    && chmod +x /usr/bin/kubectl \
    && curl -o /tmp/helm-v3.2.4-linux-amd64.tar.gz -sSL https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz \
    && tar xvf /tmp/helm-v3.2.4-linux-amd64.tar.gz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/ \
    && rm -rf /tmp/helm-v3.2.4-linux-amd64.tar.gz \
    && rm -rf /tmp/linux-amd64/
RUN yum install git openssl https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y \
    && yum install jq -y
COPY --from=downloader --chown=ansible-operator /src/vertical-pod-autoscaler/ ${HOME}/vertical-pod-autoscaler/
COPY build/create-*.sh ${HOME}/
ENV VPA ${HOME}/vertical-pod-autoscaler/
ENV PATH ${HOME}/.local/bin:${PATH}
ENV CREATE_ELB_MAPPING_AWS ${HOME}/create-elb-mapping.sh
USER ansible-operator
RUN pip3 install awscli --user


