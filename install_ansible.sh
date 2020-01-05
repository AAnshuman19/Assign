sudo dnf -y install python3-pip
sudo pip3 install --upgrade pip
sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf -y install --enablerepo epel-playground  ansible
pip3 -y install ansible --user
cd /etc/ansible/ sudo vi hosts
echo “127.0.0.1” > hosts
