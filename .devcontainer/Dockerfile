# Using the azure CLI container so we dont have to install that to start
FROM mcr.microsoft.com/azure-cli:latest

RUN apk update

# Install tools
RUN apk add nano vim tcpdump tmux

RUN apk add zsh \
&& sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
&& install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
&& rm kubectl

RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
&& chmod 700 get_helm.sh \
&& ./get_helm.sh \
&& rm get_helm.sh
