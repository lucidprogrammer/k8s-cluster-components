
FROM jgsqware/svn-client:latest as downloader
RUN apk add --no-cache bash
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
    && chmod +x /usr/bin/kubectl
RUN yum install git openssl -y
COPY --from=downloader --chown=ansible-operator /src/vertical-pod-autoscaler/ ${HOME}/vertical-pod-autoscaler/
ENV VPA ${HOME}/vertical-pod-autoscaler/
USER ansible-operator

