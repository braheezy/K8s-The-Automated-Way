## k8s hard way
This is pure education :school:

It's a bunch of stuff automating this: https://github.com/prabhatsharma/kubernetes-the-hard-way-aws

## Usage
Assuming you are starting from absolute scratch:
1. Ensure Ansible is installed:

       sudo yum install ansible -y
2. Configure machine with required tools, like the AWS CLI, [`skate`](https://github.com/charmbracelet/skate), and Terraform:

       ansible-playbook setup.yml
3. Get an AWS account. Generate the access token secrets (there's 2) and put them in `skate` :

       skate set aws_access_key YOUR_KEY
       skate set aws_access_key_secret YOUR_SECRET
4. Install the base infrastructure in AWS to host a Kubernetes cluster:

       terraform plan
       terraform apply

5. Checkpoint! Confirm things are working so far:

       ansible aws_ec2 -m ping

6. Generate certs, kubeconfigs, and encryption config:

       sh generate.sh

7. Provision the compute instances.
    1. Provide generated files
    2. Bootstrap the key-value store for cluster state, `etcd`:

           ansible-playbook provision.yml

## Tips
- Don't use Ansible for rolling out cloud infrastructure. There's no clean way to delete/undo the damage done.
