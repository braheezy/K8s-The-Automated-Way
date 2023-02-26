## k8s hard way
This is pure education :school:

It's a bunch of ~~Ansible~~Terraform automating this: https://github.com/prabhatsharma/kubernetes-the-hard-way-aws

## Usage
Assuming you are starting from absolute scratch:
1. Install [`skate`](https://github.com/charmbracelet/skate) for secret storage.
2. Get an AWS account. Generate the access token secrets (there's 2) and put them in `skate` :

       skate set aws_access_key YOUR_KEY
       skate set aws_access_key_secret YOUR_SECRET
3. Ensure Ansible is installed:

       sudo yum install ansible -y
4. Configure machine with required tools, like the AWS CLI and Terraform:

       ansible-playbook setup.yml
5. Install the base infrastructure in AWS to host a Kubernetes cluster:

       terraform plan
       terraform apply

6. Checkpoint! Confirm things are working so far:

       ansible aws_ec2 -m ping

7. Generate all the certs need to secure communication between the k8s components:

       sh pki/generate-certs.sh

8. Provision the compute instances:

       ansible-playbook provision.yml

## Tips
- Don't use Ansible for rolling out cloud infrastructure. There's no clean way to delete/undo the damage done.
