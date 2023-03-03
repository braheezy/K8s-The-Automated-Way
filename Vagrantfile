CNAME = "con"
WNAME = "work"

cow_dir = '/usr/share/cowsay/cows'
cowfiles = Dir.entries(cow_dir).select { |f| !File.directory? f }
random_cowfile = File.join(cow_dir, cowfiles.sample)
ENV['ANSIBLE_COW_SELECTION']= random_cowfile

Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2004"
  config.ssh.forward_x11 = true

  config.vm.define CNAME do |c|
    c.vm.hostname = WNAME
  end
  config.vm.define WNAME do |c|
    c.vm.hostname = WNAME
  end

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
    override.vm.synced_folder ".", "/vagrant", disabled: true
  end

  config.vm.provision "shell" do |s|
    s.inline = <<-SCRIPT
      sudo apt update -y
      sudo apt install bat -y
    SCRIPT
  end

  config.vm.provision "provision", type: "ansible", run: "never" do |a|
    a.playbook = "provision.yml"
    a.groups = {
        "controllers" => [CNAME],
        "workers" => [WNAME]
    }
    a.host_vars = {
      CNAME => {"vm_name" => CNAME},
      WNAME => {"vm_name" => WNAME}
    }
  end

end
