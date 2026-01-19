ARG ARG_UBUNTU_BASE_IMAGE="ubuntu"
ARG ARG_UBUNTU_BASE_IMAGE_TAG="24.04"
ARG ARG_VSTS_AGENT_VERSION=4.264.2
ARG ARG_TERRAFORM_VERSION=1.14.3
ARG TARGETARCH

FROM ${ARG_UBUNTU_BASE_IMAGE}:${ARG_UBUNTU_BASE_IMAGE_TAG}

WORKDIR /azp

ENV DEBIAN_FRONTEND=noninteractive
RUN echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90assumeyes

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        curl \
        git \
        git-lfs \
        iputils-ping \
        jq \
        lsb-release \
        software-properties-common \
        maven \
        wget \
        unzip \
        sudo \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get -y upgrade

RUN case "$TARGETARCH" in \
        amd64) AGENT_ARCH=linux-x64 ;; \
        arm64) AGENT_ARCH=linux-arm64 ;; \
        *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    echo "Downloading Azure DevOps Agent version ${ARG_VSTS_AGENT_VERSION} for $AGENT_ARCH" && \
    curl -LsS https://download.agent.dev.azure.com/agent/${ARG_VSTS_AGENT_VERSION}/vsts-agent-${AGENT_ARCH}-${ARG_VSTS_AGENT_VERSION}.tar.gz | tar -xz

RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
    && az extension add --name azure-devops

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

RUN KUBEARCH=$(dpkg --print-architecture) && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$KUBEARCH/kubectl" && \
    mv ./kubectl /usr/bin/kubectl && chmod +x /usr/bin/kubectl

RUN YQARCH=$(dpkg --print-architecture) && \
    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$YQARCH && \
    mv ./yq_linux_$YQARCH /usr/bin/yq && chmod +x /usr/bin/yq

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli

RUN case "$TARGETARCH" in \
        amd64) TERRAFORM_ARCH=amd64 ;; \
        arm64) TERRAFORM_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    echo "Downloading Terraform version ${ARG_TERRAFORM_VERSION} for $TERRAFORM_ARCH" && \
    curl -SL "https://releases.hashicorp.com/terraform/${ARG_TERRAFORM_VERSION}/terraform_${ARG_TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip" -o /tmp/terraform.zip && \
    unzip /tmp/terraform.zip -d /usr/bin/ && \
    rm -f /tmp/terraform.zip && \
    terraform -version


COPY ./start.sh .
RUN chmod +x start.sh

RUN useradd -m -s /bin/bash -u "6969" azdouser \
    && groupadd docker && usermod -aG docker azdouser \
    && echo "azdouser ALL=(root) NOPASSWD:ALL" >> /etc/sudoers \
    && chown -R azdouser /azp /home/azdouser /var/run/docker.sock || true

USER azdouser
WORKDIR /azp

ENTRYPOINT ["./start.sh"]
