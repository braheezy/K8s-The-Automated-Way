# K8s The Automated Way
This is pure education :school:

It's a bunch of stuff automating this in AWS: https://github.com/kelseyhightower/kubernetes-the-hard-way/

## Usage
Assuming you are starting from absolute scratch:
1. Ensure Ansible is installed:

       sudo yum install ansible -y
2. Get an AWS account. Generate the access token secrets (there's 2) and put them in [`skate`](https://github.com/charmbracelet/skate) :

       skate set aws_access_key YOUR_KEY
       skate set aws_access_key_secret YOUR_SECRET
3. Configure machine with required tools, like the AWS CLI, `kubectl`, Terraform:

       ansible-playbook setup.yml

4. Install the base infrastructure in AWS to host a Kubernetes cluster:

       terraform plan -target aws_instance.worker
       terraform apply -target aws_instance.worker
       terraform apply

5. Checkpoint! Confirm things are working so far:

       ansible aws_ec2 -m ping

6. Generate certs, kubeconfigs, and encryption config:

       bash generate.sh

7. Provision the compute instances.

       ansible-playbook provision.yml
   1. Provide generated cert/config files
   2. To persist cluster state data, bootstrap the key-value store `etcd`.
   3. Install and configure Control Plane components:
      - `kube-apiserver`: Handle API request in/out of the control plane
      - `kube-controller-manager`: Manage all control loops, the things that watch and converge state
      - `kube-scheduler`: Control Pod deployment to Nodes
      - `kubectl`: CLI to interact with Kube API
   4. Setup RBAC for API Server to Kubelet communication
   5. Install and configure Node components:
      - `kubelet`: Agent that manages Pods
      - `kube-proxy`: Network proxy, which helps turn the node into a Service-friendly HTTP participant on a network
      - `runc`: Low level tool to manage OCI images
      - `containerd`: High level tool to manage OCI images
      - `CNI`: Container networking plugins. They configure networking inside containers
      - `kubectl`
   6. `kubectl` remote admin access
   7. `coredns` deployment to cluster for DNS support

8. Smoke test the cluster

       bash smoke.sh

9. You now have a working, HA, secure K8s cluster running in AWS. Do things with it.
10. When you're done, remove everything:

        terraform destroy

## Lessons Learned
- Don't use Ansible for rolling out cloud infrastructure. There's no clean way to delete/undo the damage done.
- Terraform is drunk with configuration powers.
- Run `ExecStart` command from service files by hand first.
