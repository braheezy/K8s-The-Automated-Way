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

while getopts 'f' flag; do
    case ${flag} in
        'f')
            FORCE='true'
            ;;
    esac
done

if [ -n "$(ls -A $PKI_DIR)" ] && [ -z "${FORCE+x}" ]; then
    gum confirm \
        --prompt.foreground $INFO \
        "$PKI_DIR directory is not empty. Are you sure you want to delete these certs and generate new ones?" \
        && true || exit 0
fi

export KUBERNETES_PUBLIC_ADDRESS=$(cat k8s-public-address)

script_name=$(gum style --foreground $FOCUS "$PKI_DIR/generate_certs.sh")
gum style \
    --foreground $TITLE \
    --border-foreground $TITLE \
    --border double \
	--align left --width 50 --padding "1 2" \
    "Executing: $script_name

Generates all the certs need to secure communication between the k8s components."
sh $PKI_DIR/generate_certs.sh

script_name=$(gum style --foreground $FOCUS "$KUBECONFIG_DIR/generate_configs.sh")
gum style \
    --foreground $TITLE \
    --border-foreground $TITLE \
    --border double \
	--align left --width 50 --padding "1 2" \
    "Executing: $script_name

Generates kubeconfigs, enabling k8s clients to locate and authenticate to the k8s API Servers"
sh $KUBECONFIG_DIR/generate_configs.sh

gum style \
    --foreground $TITLE \
    --border-foreground $TITLE \
    --border double \
	--align left --width 50 --padding "1 2" \
    "Generating config to encrypt k8s data at rest"

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > encryption-config.yml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

gum style --foreground $SUCCESS "✅ Generated encryption-config!"