#!/bin/bash

set -euo pipefail

pushd $(dirname $(realpath "$0")) >/dev/null

PKI_DIR=pki
KUBECONFIG_DIR=kubeconfigs

# gold
STATUS='#f6c177'
# green
SUCCESS='#31748f'
# purple
INFO='#c4a7e7'
# pink
TITLE='#ea76cb'
# cyan
FOCUS='#04a5e5'

if ! command -v gum &>/dev/null
then
    echo "Installing Gum. This may take a minute..."
    sudo bash -c 'echo "[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key" > /etc/yum.repos.d/charm.repo'
    sudo yum install -y gum &>/dev/null
fi

script_name=$(gum style --foreground $FOCUS "pki/generate_certs.sh")
gum style \
    --foreground $TITLE \
    --border-foreground $TITLE \
    --border double \
	--align left --width 50 --padding "1 4" \
    "Executing: $script_name

Generates all the certs need to secure communication between the k8s components."
sh pki/generate_certs.sh

script_name=$(gum style --foreground $FOCUS "kubeconfigs/generate_configs.sh")
gum style \
    --foreground $TITLE \
    --border-foreground $TITLE \
    --border double \
	--align left --width 50 --padding "1 4" \
    "Executing: $script_name

Generates kubeconfigs, enabling k8s clients to locate and authenticate to the k8s API Servers"
sh kubeconfigs/generate_configs.sh