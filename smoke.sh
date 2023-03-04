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
    eval "gum spin --spinner moon --title.foreground \"$WARN\" --title \"$1\" -- $2"
}

start_smoke "Very basic container deployment with busybox"

kubectl run busybox --image=busybox:1.28 -q --command -- sleep 3600 | lolcat
kubectl wait --for condition=ready pod -l run=busybox | lolcat
echo "Here's the running busybox:\n" | lolcat
kubectl get pods -l run=busybox | lolcat
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
echo "Here's the DNS lookup for kubernets service inside busybox pod:\n" | lolcat
kubectl exec -ti $POD_NAME -- nslookup kubernetes | lolcat

end_smoke

start_smoke "Verify the cluster can encrypt data at rest"

kubectl create secret generic kubernetes-the-hard-way --from-literal="secret=password" | lolcat
ansible controllers[0] -m shell -a "sudo ETCDCTL_API=3 etcdctl get --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem /registry/secrets/default/kubernetes-the-hard-way | hexdump -C" | lolcat

end_smoke

start_smoke "Verify the cluster can create/manage Deployments"

kubectl create deployment nginx --image=nginx | lolcat
kubectl wait pod -l app=nginx --for condition=ready | lolcat
kubectl get pods -l app=nginx | lolcat

end_smoke

start_smoke "Verify port forwarding"

POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8080:80 | lolcat &
pid=$!
sleep 2
curl -s --head http://127.0.0.1:8080 | lolcat
kill $((pid-1))

end_smoke

start_smoke "Verify log retrieval"

kubectl logs $POD_NAME | lolcat

end_smoke

start_smoke "Verify commands can be run in containers"

kubectl exec -ti $POD_NAME -- nginx -v | lolcat

end_smoke

start_smoke "Verify deployment can be exposed as a NodePort Service"

kubectl expose deployment nginx --port 80 --type NodePort | lolcat
NODE_PORT=$(kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
--filters "Name=tag:Name,Values=kubernetes" \
--output text --query 'SecurityGroups[0].GroupId')
aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port ${NODE_PORT} \
  --cidr 0.0.0.0/0 | lolcat
EXTERNAL_IP=$(ansible-inventory --host workers[0]  | jq -r '.public_ip_address')
curl -s -I http://$EXTERNAL_IP:$NODE_PORT | lolcat

end_smoke

gum style \
    --align left --padding "0 2" \
    --foreground $WARN \
    "🚧 Cleaning test resources. This may take a few minutes. 🚧"

cleanup "Removing busybox pods..." "kubectl delete pod busybox"
cleanup "Deleting generated secret..." "kubectl delete secret kubernetes-the-hard-way"
cleanup "Removing generated ec2 ingress rule..." "aws ec2 revoke-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port ${NODE_PORT} --cidr 0.0.0.0/0"
cleanup "Deleting nginx exposed service" "kubectl delete service nginx"
cleanup "Deleting nginx deployment..." "kubectl delete deployment nginx"

gum style --align left --padding "0 2" \
    --foreground $SUCCESS \
    "✅ Cleaning done"

gum style --align left --padding "0 2" \
    --foreground $SUCCESS \
    "✅ All smoke tests pass! Congrats!"
