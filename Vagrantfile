VAGRANTFILE_API_VERSION = "2"
Vagrant.require_version ">= 1.6.5"

if ARGV[0] == 'up'
  #forward local 80 to local 8080 (required for VIP and nice for others)
  puts "Adding port forward for running on port 80: you may be asked for sudo password..."
  `sudo ipfw add 12345 fwd 127.0.0.1,8080 tcp from any to me 80`
elsif ARGV[0] == 'halt'
  puts "Removing port forward: you may be asked for sudo password..."
  `sudo ipfw delete 12345`
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "ubuntu/trusty64"

  config.vm.provider "vmware_fusion" do |v|
    v.vmx["memsize"] = "2048"
    v.vmx["numvcpus"] = "2"
  end

  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--ostype", "Ubuntu_64"]
    v.customize ["modifyvm", :id, "--chipset", "ich9"]
    v.customize ["modifyvm", :id, "--pae", "on"]
    v.memory = 2048
    v.cpus = 2
    v.customize ["modifyvm", :id, "--nictype1", "virtio"]
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  #forward to non-privileged host port (redirected by above firewall rules)
  config.vm.network :forwarded_port, guest: 80, host: 8080

  config.vm.provision "shell", run: "always" do |s|
    #auto detect the git repo on the host to decide which CMS to provision
    s.path = "provision.sh"
  end
end
