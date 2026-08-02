[bastion]
bastion01 ansible_host=${bastion_public_ip}

[master]
master01 ansible_host=${master_ip}

[worker]
%{ for idx, ip in worker_ips ~}
worker0${idx + 1} ansible_host=${ip}
%{ endfor ~}

[k8s_cluster:children]
master
worker

[k8s_cluster:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=./ansiblekey.pem

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ./ansiblekey.pem -W %h:%p ec2-user@${bastion_public_ip}"'
