output "k8s_address" {
  description = "Cluster Networking has been configured! Here's the public address for the cluster"
  value       = aws_lb.main.dns_name
}
output "aws_ec2_controller_info" {
  value = {
    ids        = ["${aws_instance.controller.*.id}"]
    public_dns = ["${aws_instance.controller.*.public_dns}"]
    public_ips = ["${aws_instance.controller.*.public_ip}"]
  }
}
output "aws_ec2_worker_info" {
  value = {
    ids        = ["${aws_instance.worker.*.id}"]
    public_dns = ["${aws_instance.worker.*.public_dns}"]
    public_ips = ["${aws_instance.worker.*.public_ip}"]
  }
}
