# disable firewall #
systemctl stop firewalld
systemctl disable firewalld

# disable swap #
swapoff -a
sed -i 's/.*swap.*/#&/'  /etc/fstab

# disable selinux #
## vim /etc/selinux/config ##
sed -i 's/enforcing/disabled/'  /etc/selinux/config

# enable ip forwarding #
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF

sysctl --system


##-------set repos--------##-------------##

wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.cloud.tencent.com/repo/centos7_base.repo
##

cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=kubernetes
baseurl=https://mirrors.tuna.tsinghua.edu.cn/kubernetes/yum/repos/kubernetes-el7-
name=Kubernetes
baseurl=https://mirrors.tuna.tsinghua.edu.cn/kubernetes/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/kubernetes/core:/stable:/v1.30/rpm/repodata/repomd.xml.key

[cri-o]
name=CRI-O
baseurl=https://mirrors.tuna.tsinghua.edu.cn/kubernetes/addons:/cri-o:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/kubernetes/addons:/cri-o:/prerelease:/main/rpm/repodata/repomd.xml.key

EOF
yum update -y
yum install -y yum-utils

yum-config-manager --add-repo https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/docker-ce.repo
sed -i 's+https://download.docker.com+https://mirrors.tuna.tsinghua.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo

yum update -y

# install softwares
yum install -y bash-completion wget vim-enhanced net-tools gcc conntrack ipvsadm

yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin



##config docker##
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://kly9344d.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "insecure-registries": ["192.168.3.18"]
}

EOF

systemctl enable docker && systemctl start docker

yum install -y ./cri-dockerd-0.3.14-3.el7.x86_64.rpm

# config cri-docker
cat > /usr/lib/systemd/system/cri-docker.service  << EOF
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=cri-docker.socket

[Service]
Type=notify
ExecStart=/usr/bin/cri-dockerd --network-plugin=cni --cni-bin-dir=/opt/cni/bin  --container-runtime-endpoint fd://  --pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.9
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable cri-docker --now

yum install -y kubelet kubeadm kubectl

cat <<EOF > /etc/sysconfig/kubelet                                
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"
EOF

systemctl enable kubelet

cat >> /etc/hosts << EOF
192.168.59.101 k8s-master1
192.168.59.102 kube-node1
192.168.59.103 kube-node2
EOF

kubeadm init \
--apiserver-advertise-address=192.168.59.101 \
--image-repository=registry.aliyuncs.com/google_containers \
--kubernetes-version v1.30.2 \
--service-cidr=10.96.0.0/12 \
--pod-network-cidr=10.244.0.0/16 \
--cri-socket=var/run/cri-dockerd.sock \
#--ignore-pddflight-errors=all

mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config
