#!/bin/bash

set -euo pipefail

pushd $(dirname $(realpath "$0")) >/dev/null

# gold
STATUS='#f6c177'
# green
SUCCESS='#31748f'
# purple
INFO='#c4a7e7'

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "San Diego",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "California"
    }
  ]
}
EOF

gum style --foreground $STATUS "Creating Certificate Authority to generate TLS certs..."
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
gum style --foreground $SUCCESS "✅ Created Certificate Authority!"

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "San Diego",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "California"
    }
  ]
}
EOF

gum style --foreground $STATUS "Generating admin user client certificate and private key..."
cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    admin-csr.json | cfssljson -bare admin
gum style --foreground $SUCCESS "✅ Generated admin cert/key!"

for i in 0 1 2; do
    instance="worker-${i}"
    instance_hostname="ip-10-0-1-2${i}"
    cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance_hostname}",
  "keycat": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "San Diego",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "California"
    }
  ]
}
EOF

    external_ip=$(aws ec2 describe-instances --filters \
        "Name=tag:Id,Values=${instance}" \
        "Name=instance-state-name,Values=running" \
        --output text --query 'Reservations[].Instances[].PublicIpAddress')

    internal_ip=$(aws ec2 describe-instances --filters \
        "Name=tag:Id,Values=${instance}" \
        "Name=instance-state-name,Values=running" \
        --output text --query 'Reservations[].Instances[].PrivateIpAddress')

    gum style --foreground $INFO "Node: $instance
External IP: $external_ip
Internal IP: $internal_ip
"

    gum style --foreground $STATUS "Generating $instance's certs/keys..."

    cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -hostname=${instance},${external_ip},${internal_ip} \
        -profile=kubernetes \
        ${instance}-csr.json | cfssljson -bare ${instance}
    gum style --foreground $SUCCESS "✅ Generated $instance's certs/keys!"
done

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "San Diego",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "California"
    }
  ]
}
EOF

gum style --foreground $STATUS "Generating 'kube-controller-manager' cert/key..."
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
gum style --foreground $SUCCESS "✅ Generated 'kube-controller-manager' cert/key..."

cat >  kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "San Diego",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "California"
    }
  ]
}
EOF
gum style --foreground $STATUS "Generating 'kube-proxy' cert/key..."
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
gum style --foreground $SUCCESS "✅ Generated 'kube-proxy' cert/key..."

cat >  kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "San Diego",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "California"
    }
  ]
}
EOF
gum style --foreground $STATUS "Generating 'kube-scheduler' cert/key..."
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
gum style --foreground $SUCCESS "✅ Generated 'kube-scheduler' cert/key..."

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local
KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
    --names kubernetes \
    --query 'LoadBalancers[*].[DNSName]' --output text)

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "San Diego",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "California"
    }
  ]
}
EOF
gum style --foreground $STATUS "Generating Kubernetes API Server cert/key..."
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.0.1.10,10.0.1.11,10.0.1.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
gum style --foreground $SUCCESS "✅ Generated Kubernetes API Server cert/key..."

cat >  service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "San Diego",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "California"
    }
  ]
}
EOF
gum style --foreground $STATUS "Generating 'service-account' cert/key..."
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
gum style --foreground $SUCCESS "✅ Generated 'service-account' cert/key..."

popd >/dev/null