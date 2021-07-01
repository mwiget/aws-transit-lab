# create benchr1 instance

# network interfaces
resource "aws_network_interface" "benchr1_mgmt" {
  subnet_id   = aws_subnet.bench_mgmt.id
  private_ips = ["10.0.0.150"]
  ipv6_address_count = 1
  security_groups = [aws_security_group.sg.id]

}
resource "aws_network_interface" "bench_benchr1_0" {
  subnet_id   = aws_subnet.bench_subnet1.id
  private_ips = ["10.0.1.100"]
  source_dest_check = false

  tags = {
    Name = "bench_benchr1_port0"
  }
}

resource "aws_eip" "one" {
   vpc                       = true
  network_interface         = aws_network_interface.benchr1_mgmt.id
  associate_with_private_ip = "10.0.0.150"
}

resource "aws_instance" "benchr1" {

  instance_type = "t2.micro"             # 1 core, 1GB RAM
  ami           = data.aws_ami.ubuntu.id

  tags = {
    Name = "benchr1"
  }

  network_interface {
    network_interface_id = aws_network_interface.benchr1_mgmt.id
    device_index         = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.bench_benchr1_0.id
    device_index         = 1
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  user_data =<<EOT
#cloud-config
hostname: benchr1
ssh_authorized_keys:
  - ${var.ssh_public_key}

package_update: true
package_upgrade: true
package_reboot_if_required: true

groups:
- docker

users:
- default
- name: mwiget
  lock_passwd: true
  shell: /bin/bash
  ssh-authorized_keys:
    - ${var.ssh_public_key}
  groups:
    - docker
    - sudo
  sudo:
    - ALL=(ALL) NOPASSWD:ALL

packages:
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common

runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add -
  - curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io tailscale net-tools
  - tailscale up -authkey=${var.tailscale_authkey}
  - systemctl start docker
  - systemctl enable docker
  - ip addr add 10.10.10.1/32 dev lo
  - ip route add 10.10.10.2/32 via 10.0.1.101

final_message: "The system is finally up, after $UPTIME seconds"
EOT

}
