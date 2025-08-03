```sh
# Install the OS packages lvm2, iptables, sysstat, and net-tools by executing

sudo dnf install lvm2 iptables sysstat net-tools

# Remove docker and previously installed podman packages (if previously installed)
sudo dnf remove docker docker-ce podman podman-remote containerd.io

# As a sudoers user, disable SELinux by adding the following parameter to /etc/selinux/config
SELINUX=disabled

# Install podman
sudo dnf install podman podman-remote


# If podman requires a proxy in your infrastructure setup, modify the /usr/share/containers/containers.conf file and add the HTTP_PROXY and HTTPS_PROXY environment variables in the [engine] section. Please note that multiple env variables in that configuration file exists — use the one in the [engine] section.
# Example:
[engine]
env = ["HTTP_PROXY=http://{proxy-ip}:{proxy-port}", "HTTPS_PROXY=http://{proxy-ip}:{proxy-port}"]

# Reload systemd configuration
sudo systemctl daemon-reload

# Create OS groups, if they do not exist yet
# Reference: Users and permissions
sudo groupadd elastic
sudo groupadd podman

# Add user elastic to the podman group
# Reference: Users and permissions
sudo useradd -g "elastic" -G "podman" elastic

# As a sudoers user, add the following line to /etc/sudoers.d/99-ece-users
# Reference: Users and permissions
elastic ALL=(ALL) NOPASSWD:ALL

# Add the required options to the kernel boot arguments
sudo /sbin/grubby --update-kernel=ALL --args='cgroup_enable=memory cgroup.memory=nokmem swapaccount=1'

# Create the directory
sudo mkdir -p /etc/systemd/system/podman.socket.d

# As a sudoers user, create the file /etc/systemd/system/podman.socket.d/podman.conf with the following content. Set the correct ownership and permission.
# Both ListenStream= and ListenStream=/var/run/docker.sock parameters are required!
# File content:
[Socket]
ListenStream=
ListenStream=/var/run/docker.sock
SocketMode=770
SocketUser=elastic
SocketGroup=podman

# File ownership and permission:
sudo chown root:root /etc/systemd/system/podman.socket.d/podman.conf
sudo chmod 0644 /etc/systemd/system/podman.socket.d/podman.conf

# As a sudoers user, create the (text) file /usr/bin/docker with the following content. Verify that the regular double quotes in the text file are used (ASCII code Hex 22)

#!/bin/bash
podman-remote --url unix:///var/run/docker.sock "$@"

# Set the file permissions on /usr/bin/docker
sudo chmod 0755 /usr/bin/docker

# As a sudoers user, add the following two lines to section [storage] in the file /etc/containers/storage.conf. Verify that those parameters are only defined once. Either remove or comment out potentially existing parameters.
runroot = "/mnt/data/docker/runroot/"
graphroot = "/mnt/data/docker"

# Enable podman so that itself and running containers start automatically after a reboot
sudo systemctl enable podman.service
sudo systemctl enable podman-restart.service

# Enable the overlay kernel module (check Use the OverlayFS storage driver) that the Podman overlay storage driver uses (check Working with the Container Storage library and tools in Red Hat Enterprise Linux).

# In Docker world there are two overlay drivers, overlay and overlay2, today most users use the overlay2 driver, so we just use that one, and called it overlay.

# -- https://docs.docker.com/storage/storagedriver/overlayfs-driver/
echo "overlay" | sudo tee -a /etc/modules-load.d/overlay.conf

# Format the additional data partition
sudo mkfs.xfs /dev/nvme1n1

# Create the /mnt/data/ directory used as a mount point
sudo install -o elastic -g elastic -d -m 700 /mnt/data

# As a sudoers user, modify the entry for the XFS volume in the /etc/fstab file to add pquota,prjquota. The default filesystem path used by Elastic Cloud Enterprise is /mnt/data.
# Replace /dev/nvme1n1 in the following example with the corresponding device on your host, and add this example configuration as a single line to /etc/fstab.

/dev/nvme1n1	/mnt/data	xfs	defaults,nofail,x-systemd.automount,prjquota,pquota  0 2

# Restart the local-fs target

sudo systemctl daemon-reload
sudo systemctl restart local-fs.target

# Set the permissions on the newly mounted device

ls /mnt/data
sudo chown elastic:elastic /mnt/data

# Create the /mnt/data/docker directory for the Docker service storage
sudo install -o elastic -g elastic -d -m 700 /mnt/data/docker

#Disable the firewalld service. The service is not compatible with Podman and interferes with the installation of ECE. You must disable firewalld before installing or reinstalling ECE.
# If firewalld does not exist on your VM, you can skip this step.

sudo systemctl disable firewalld

# Configure kernel parameters
cat <<EOF | sudo tee -a /etc/sysctl.conf
# Required by Elasticsearch 5.0 and later
vm.max_map_count=262144
# enable forwarding so the Docker networking works as expected
net.ipv4.ip_forward=1
# Decrease the maximum number of TCP retransmissions to 5 as recommended for Elasticsearch TCP retransmission timeout.
# See https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config-tcpretries.html
net.ipv4.tcp_retries2=5
# Make sure the host doesn't swap too early
vm.swappiness=1
EOF

# Apply the new sysctl settings
sudo sysctl -p
sudo systemctl restart NetworkManager

# As a sudoers user, adjust the system limits. Add the following configuration values to the /etc/security/limits.conf file.

*                soft    nofile         1024000
*                hard    nofile         1024000
*                soft    memlock        unlimited
*                hard    memlock        unlimited
elastic          soft    nofile         1024000
elastic          hard    nofile         1024000
elastic          soft    memlock        unlimited
elastic          hard    memlock        unlimited
root             soft    nofile         1024000
root             hard    nofile         1024000
root             soft    memlock        unlimited

# Authenticate the elastic user to pull images from the docker registry you use, by creating the file /home/elastic/.docker/config.json. This file needs to be owned by the elastic user. If you are using a user name other than elastic, adjust the path accordingly.

# Example: In case you use docker.elastic.co, the file content looks like as follows:

{
 "auths": {
   "docker.elastic.co": {
     "auth": "<auth-token>"
   }
 }
}

# Restart the podman service by running this command:
sudo systemctl daemon-reload
sudo systemctl restart podman

# Reboot the RHEL host
sudo reboot
```
