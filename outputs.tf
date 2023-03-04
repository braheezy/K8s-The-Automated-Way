output "aws_ec2_controller_info" {
  value = {
    ids         = ["${aws_instance.controller.*.id}"]
    public_dns  = ["${aws_instance.controller.*.public_dns}"]
    public_ips  = ["${aws_instance.controller.*.public_ip}"]
    private_ips = ["${aws_instance.controller.*.private_ip}"]
  }
}
output "aws_ec2_worker_info" {
  value = {
    ids         = ["${aws_instance.worker.*.id}"]
    public_dns  = ["${aws_instance.worker.*.public_dns}"]
    public_ips  = ["${aws_instance.worker.*.public_ip}"]
    private_ips = ["${aws_instance.worker.*.private_ip}"]
  }
}
