NAME="k8hard"

Vagrant.configure("2") do |config|
  config.vm.box = "generic/fedora37"
  config.ssh.forward_x11 = true

  config.vm.define NAME
  config.vm.hostname = NAME

  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider :libvirt do |l, override|
    l.graphics_type = "spice"
    l.video_type = "virtio"
    l.default_prefix = ""
    l.qemu_use_session = false
    l.cpus = 4
    l.memory = 4096

    l.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
    l.channel :type => 'spicevmc', :target_name => 'com.redhat.spice.0', :target_type => 'virtio'

    l.memorybacking :access, :mode => "shared"
    override.vm.synced_folder ".", "/vagrant", type: "virtiofs", disabled: false
    override.vm.synced_folder "~/dotfiles", "/dots", type: "virtiofs"
  end

  config.vm.provision "shell" do |s|
    s.inline = "sudo yum update -y"
  end

  config.vm.provision "setup", type: "ansible_local" do |a|
    a.playbook = "setup.yml"
  end

end
