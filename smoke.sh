#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

pushd $(dirname $(realpath "$0")) >/dev/null

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
# red
WARN='#e64553'

start_smoke() {
    prefix=$(gum style --foreground $FOCUS "🚬 Running test: ")
    body=$(gum style --foreground $TITLE $1)
    gum style --align left --padding "1 2" \
        "$prefix $body"
}

end_smoke() {
    gum style --align left --padding "1 2" \
        --foreground $FOCUS \
        "✅ Smoke test passed!"
}

cleanup() {
    eval "gum spin --spinner moon --title.foreground \"$WARN\" --title \"$1\" $2"
}

start_smoke "Basic container deployment with busybox"

kubectl run busybox --image=busybox:1.28 -q --command -- sleep 3600 | lolcat
kubectl wait --for=condition=ready pod -l run=busybox | lolcat
echo "Here's the running busybox:\n" | lolcat
kubectl get pods -l run=busybox | lolcat
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
echo "Here's the DNS lookup for kubernets service inside busybox pod:\n" | lolcat
kubectl exec -ti $POD_NAME -- nslookup kubernetes | lolcat

end_smoke

gum style \
    --align left --padding "0 2" \
    --foreground $WARN \
    "🚧 Cleaning test resources. This may take a few minutes. 🚧"

cleanup "Removing busybox pods..." "kubectl delete pod busybox"

gum style --align left --padding "0 2" \
    --foreground $SUCCESS \
    "✅ Cleaning done"

gum style --align left --padding "0 2" \
    --foreground $SUCCESS \
    "✅ All smoke tests pass! Congrats!"
