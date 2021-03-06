#!/bin/bash
apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
touch /etc/fstab
update-alternatives --set iptables /usr/sbin/iptables-legacy
echo 'service docker start' >> /etc/init.d/dockeradm
chmod +x /etc/init.d/dockeradm
ln -s /etc/init.d/dockeradm /etc/rc1.d/S01dockeradm