# Migration process from RKE to Kubespray

## Disclaimer

Although we have used this process to migrate many clusters (from 3 to tens of nodes) without any issue and without downtime, the stay a delicate tasks and we do not provide any guarantee of success. You should always try first on a "crash test" cluster to make sure the process works in your specific configuration :-) 

> **WARNING**: This process can't be reverted. Even with a full DR, thi would be tricky. Make sure to not skip **any** step and perform regular checks to ensure that the cluster remain healthy during the operation.

> **WARNING**: REVIEW CAREFULLY THE INVENTORY. Some value are not default of kubespray in order to migrate (they can safely removed aftersometimes), such as the one below for token compatibility. Before removing them, make sure to follow the official k8s process on how to rotate/change these:
```
kube_kubeadm_apiserver_extra_args:
  api-audiences: "unknown,https://kubernetes.default.svc.cluster.local"
  service-account-issuer: "rke"
```

## Requirements
The process has only been tested with these particular requirements and won't be supported from anything else. If this require a phased upgrade to reach these first, please do so. Again, **do not take shortcuts.**

Requirements:
- OS: Ubuntu 20.04LTS 
- K8S version: v1.23.14-rancher1
- Kubespray: v2.21.0
- Access: 
  - root access to the nodes via SSH.
  - cluster-admin rights on the cluster via CRB

On top of these 2 requirements, run the etcd_explorer (latest version) on a backup of the etcd, and ensure that no core component are returned (rook will most likely trigger if psp are still enabled, disable them!)

## Step 0 - Upgrade ETCD to 3.5.6
- **Expected impact**: Minor to none during etcd restart. ~5-10s per server (x3)
- **Reason**: Kubespray will upgrade etcd to 3.5.6, and it's probably best to avoid having mixed version between the original 3.5.3 of rancher and the 3.5.6 of kubespray. 

First ensure that you are in the `000_etcd` directory. Then edit the `0_get_state.sh` file and adjust the IP of your masters. This will allow you to fetch the status of the etcd and ensure the cluster is healthy between operation.
> **INFO**: Please note that the script will always target the 3rd master, so if you use this script later one to check the status of a node joining the cluster, this will not work anymore during the replacement of the last master. 

The result should be something like this:
```
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT           |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.252.145.178:2379 | 41fb2d246cabae9b |   3.5.3 |  7.9 MB |     false |      false |         3 |       7501 |               7501 |        |
| https://10.252.145.163:2379 | 164523ad28e8c0d6 |   3.5.3 |  7.9 MB |      true |      false |         3 |       7501 |               7501 |        |
| https://10.252.145.190:2379 | bb64a845f1b2890a |   3.5.3 |  7.9 MB |     false |      false |         3 |       7501 |               7501 |        |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
+------------------+---------+------------------------------+-----------------------------+-----------------------------+------------+
|        ID        | STATUS  |             NAME             |         PEER ADDRS          |        CLIENT ADDRS         | IS LEARNER |
+------------------+---------+------------------------------+-----------------------------+-----------------------------+------------+
| 164523ad28e8c0d6 | started | etcd-kubespray-test-master-2 | https://10.252.145.163:2380 | https://10.252.145.163:2379 |      false |
| 41fb2d246cabae9b | started | etcd-kubespray-test-master-1 | https://10.252.145.178:2380 | https://10.252.145.178:2379 |      false |
| bb64a845f1b2890a | started | etcd-kubespray-test-master-3 | https://10.252.145.190:2380 | https://10.252.145.190:2379 |      false |
+------------------+---------+------------------------------+-----------------------------+-----------------------------+------------+
```
Ensure that all instance are "started" and are sync for the `RAFT INDEX` and `RAFT APPLIED INDEX`.

Then for each node (the master **last**), run the following command:
`bash 1_upgrade_node.sh <node_ip>`. If the process crash saying that the container is unknown after stoping it, comment the line of the docker inspect and run it again.

The result will look to something like this:
```
Connecting to node 10.252.145.178 and fetching the docker info
Parsing the docker inspect result and generating the command
Prepulling the new image
v3.5.6: Pulling from rancher/mirrored-coreos-etcd
dbba69284b27: Already exists
d0864aad2241: Pulling fs layer
da5fce333fb3: Pulling fs layer
071dc7600683: Pulling fs layer
fa9c7393081f: Pulling fs layer
d13ad88db53a: Pulling fs layer
f0715a64fa3d: Pulling fs layer
d13ad88db53a: Waiting
f0715a64fa3d: Waiting
fa9c7393081f: Waiting
da5fce333fb3: Verifying Checksum
da5fce333fb3: Download complete
071dc7600683: Verifying Checksum
071dc7600683: Download complete
d0864aad2241: Verifying Checksum
d0864aad2241: Download complete
fa9c7393081f: Verifying Checksum
fa9c7393081f: Download complete
d13ad88db53a: Verifying Checksum
d13ad88db53a: Download complete
f0715a64fa3d: Verifying Checksum
f0715a64fa3d: Download complete
d0864aad2241: Pull complete
da5fce333fb3: Pull complete
071dc7600683: Pull complete
fa9c7393081f: Pull complete
d13ad88db53a: Pull complete
f0715a64fa3d: Pull complete
Digest: sha256:c39e96f43b58fc6fe85c6712f0b0c4958ebdd57acb54e7a73965cf3c4d8a3320
Status: Downloaded newer image for rancher/mirrored-coreos-etcd:v3.5.6
docker.io/rancher/mirrored-coreos-etcd:v3.5.6
Stoping the old etcd container
etcd
Waiting 1 second before removing the old container
Removing the old etcd container
etcd
Starting the new etcd container
69ba4ecd98c0ca269aaae680638bda128b40e2b2fe79f9d770b0bc2eb0ac3a12
```
Then check again via `0_get_state.sh` and repeat the process for all the remaining nodes.

Once done for all nodes, ensure all is ok and well, then you can proceed to the next step!

## Step 1 - CoreDNS downgrade and reconfiguration
- **Expected impact**: Minor impact during the restart of the process. An image prepull will be done on the nodes in order to minimise it.
- **Reason**: Kubespray uses kubeadm to control the upgrade. RKE installed CoreDNS using version 1.9.0, but this version is not supported by kubeadm for K8S 1.23 and K8S 1.24. So we need to downgrade it to version 1.8.6. The upgrade to 1.25 will bump it back to 1.9.3. 

> **INFO**: RKE use the ".10" IP for it's DNS service (propagated in kubelet configs), while kubepray uses ".3". In order to have issue, the service we recreate will be using the ".3" IP as kubespray expect. However, doing this alone would break the current service. So we'll spawn a second DNS service that will have .10 ip and use the name expected by kubeadm. This service will be used until the end of the migration and will be left "as it is" at the very end, as it doesn't do anything wrong.

In your current terminal, move to the `001_coredns` directory. 

Edit the 1_migrate.sh file to fill your node IP for the prepull (leave empty if you don't want to prepul) then just run `1_migrate.sh`

> **WARNING**: Before continuing, please check that the DNS is still working from within the cluster. Move to next step if all is ok!

## Step 2 - Metrics server reconfiguration
- **Expected impact**: Around 60s the time for the metrics server to restart. This would only affect HPA and have no customer impact.
- **Reason**: We don't take risk here, we delete what RKE spawned and reapply the same via the generated manifest of Kubespray. This will also mean that kubespray won't detect changes during the upgrade later and leave it untouched.

In your current terminal, move to the `002_metrics_server` directory and run `1_migrate.sh`. Nothing special here it's straightforward!

> **WARNING**: Before continuing, please check that the metrics server is healthy! This could take up to a minute until it collects all the metrics

## Step 3 - Canal replacement with Calico
- **Expected impact**: No impact foreseen or visible in the initial test, however if there is anything weird post upgrade, do `ip link set down flannel.1` on all servers a workaround as the interface won't be removed... The restart takes around 45s without visible impacts
- **Reason**: Canal was deprecated a while ago it seems. While under the hood, canal is calico + flannel. We'll just take the oportunity to migrate to calico-ipam and get rid of flannel. This will allow us to have double stack and some other neat functionality later on (such as grouping container ip per ns)

> **WARNING**: This upgrade is one of the risky one, be **extra** careful when doing it and crosscheck that network works after the upgrade. This is extremely easy to miss any issue with this one as nothing will be "red/down" in K8S kube-system and it will look alright. But connectivity might be fully broken. If you range is not 10.42.0.0/16 for the PODS, please edit the file `calico.conflist.template`. This shouldn't be needed but better safe than sorry!

In your current terminal, move to the `002_cni_calico` directory and edit the file `1_migrate_calico.sh` with the correct node IP. This is used to prepush the config file and prepull some of the images for faster restart.

One done, run `1_migrate_calico.sh` wait for ALL the pods to be back up, check network then run `2_migrate_controller.sh` then check again.

## Stet 4 - Control-plane replacement
> **WARNING**: This is were the rollback process will be almost impossible. As we will start running the kubespray playbooks and upgrade/purge some of the nodes. The most dangerous part is probably the very first node, as it uses a custom playbook made for this migration. Please follow this process carefully!

- **Expected impact**: Flaps during the api-servers restart and some of the operation. To be quantified.

As usual, move to the `004_replace_control_plane` folder in order to have the correct scripts ready. 

The process will be the following one (detailed a bit further down):
- Remove the 1st master of the cluster (Possible impacts)
- Remove it's reference in the api-server and restart them (Possible impacts)
- Delete all docker data and upgrade the server (No impact)
- Reboot the server then jump to ubuntu 22.04 (No impact)
- Backup the certificates and re-add via etcdctl the old master ip.
- Add the master via the tuned playbook. (No impact in theory)

Once this is done the cluster will be hybrid between RKE and Kubespray, but as the version are aligned and as long as kube-proxy isn't restarted on the old nodes, no impact is foreseen in that state

Make sure to get the correct version of Kubespray:
`git clone https://github.com/kubernetes-sigs/kubespray.git --branch v2.21.0 --single-branch`

### Preparation
> **INFO**: This can (should) be done before the maintenance in order to have all ready when needed. They only impact file on your own computer

**Copy the content of the patches directory inside the kubespray directory. This is needed to patch the files to the correct values for later.**

Then proceed to run the following commands in order to create the custom playbook:

```bash
cd kubespray
mkdir migrations_playbook
cp -rp roles migrations_playbook/
cp -rp library/ migrations_playbook/library/
cp -p ansible_version.yml migrations_playbook/
cp -p legacy_groups.yml migrations_playbook/
cp -p facts.yml migrations_playbook/
cp -p cluster.yml migrations_playbook/
patch migrations_playbook/roles/etcd/tasks/configure.yml 1_migration_playbook_roles.patch
patch migrations_playbook/cluster.yml 2_cluster.yml.patch
patch -o migrations_playbook/2_cluster.yml cluster.yml 3_2_cluster.yml.patch
``` 

> **INFO**: If you want to use mirrors, there is an issue in that version of kubespray, you'll need to edit the following files (I didn't make a patch for it). First: kubespray/roles/container-engine/containerd/tasks/main.yml and remove these 2 task : "containerd ｜ Create registry directories, containerd ｜ Write hosts.toml file". Second: kubespray/roles/container-engine/containerd/templates/config.toml.j2 , empty line 51 (      config_path = "{{ containerd_cfg_dir }}/certs.d"). This issue is fixed in kubespray v2.22.1 I believe if you want to see another version of the fix.

Once done, you should have all the needed files in the correct state for the migration with Kubespray. The only step left to prepare is the inventory. Most of the default values in the inventory folder should work for the migrations, review them just in case (max amount of pods, etc)

### Removal of the 1st node
Once all is ready and you are sure all is ready, we can remove the first node with the following process:
```bash
bash 1_delete_node.sh <node_name>
bash 2_fix_api_servers.sh <ip_remaining_1> <ip_remaining_2>
bash 2_fix_api_servers.sh <ip_remaining_2> <ip_remaining_1>
ssh <node_name>
# Teardown the node
docker rm -f $(docker ps -qa)
docker volume rm $(docker volume ls -q)

# I recomend to restart here before the next command, to ensure the command below doesn't traverse a mountpoint that would still be there, you can do the dist-upgrade here to gain some times

for mount in $(mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') /var/lib/kubelet /var/lib/rancher; do umount $mount; done
rm -rf /etc/cni \
       /etc/kubernetes \
       /opt/cni \
       /opt/rke \
       /run/secrets/kubernetes.io \
       /run/calico \
       /run/flannel \
       /var/lib/calico \
       /var/lib/etcd \
       /var/lib/cni \
       /var/lib/kubelet \
       /var/lib/rancher/rke/log \
       /var/log/containers \
       /var/log/kube-audit \
       /var/log/pods \
       /var/run/calico
```

Peform any other cleaning operation here. Such as PVC cleaning, OSD purging, etc.

### Upgrade to Ubunu 22.04LTS of the 1st node

Now proceed to upgrade the node:
```bash
apt-mark unhold $(apt-mark showhold)
apt-get update && apt-get dist-upgrade
reboot
do-release-upgrade
```

### Add the 1st node back via kubespray
> **WARNING**: DO NOT MISS THIS STEP OR YOU WILL NEED TO START OVER

Before starting, we'll backup the CA and move it to the new server. If we are not doing this, the api-server will be failing to communicate toghter, same for the etcd.

Just run the `bash 3_bootstrap_new_node.sh <master_1_ip> <master_2_ip>` command and it should do what is needed. This also re-add the node in the etcd cluster, as our cutom playbook will skip that step.

We'll run kubespray via docker in order to have a clean env. We however, need to mount our directories at the good place.

Firt copy the inventory folder into the inventory folder of your git repo using the name of the cluster. Once done run:
`docker run --rm -it --mount type=bind,source="$(pwd)"/inventory/<cluster_name>,dst=/inventory --mount type=bind,source="$(pwd)",dst=/kubespray_custom   --mount type=bind,source="${HOME}"/.ssh/id_recovery,dst=/root/.ssh/id_rsa   quay.io/kubespray/kubespray:v2.21.0 bash`

Then inside the container run: `pip3 install jmespath==0.9.5` and finally do a dummy connection do all server (to get their host key): `ssh root@<ip> exit`

> **INFO**: If you have dedicated control place (not control plane + worker at the same time), you will need to add the following at the end of the ansible-playbook command. Do check before that the error is related to having no worker before you proceed. `-e ignore_assert_errors=true`
Once done, we can run the initial playbook to rejoin, and go grab a coffee, this will take time.
```bash
cd /kubespray_custom/migrations_playbook/
ansible-playbook -i /inventory/hosts.yaml cluster.yml --skip-tags=multus
```

One the command finish, check that all is running properly and start proceeding with the second master.

### Removal of the 2nd node
Once all is ready and you are sure all is ready, we can remove the second node with the following process:
```bash
bash 1_delete_node.sh <node_name>
bash 2_fix_api_servers.sh <ip_remaining_2> <master_ip_1>
ssh <node_name>
# Teardown the node
docker rm -f $(docker ps -qa)
docker volume rm $(docker volume ls -q)
# I recomend to restart here before the next command, to ensure the command below doesn't traverse a mountpoint that would still be there, you can do the dist-upgrade here to gain some times
for mount in $(mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') /var/lib/kubelet /var/lib/rancher; do umount $mount; done
rm -rf /etc/cni \
       /etc/kubernetes \
       /opt/cni \
       /opt/rke \
       /run/secrets/kubernetes.io \
       /run/calico \
       /run/flannel \
       /var/lib/calico \
       /var/lib/etcd \
       /var/lib/cni \
       /var/lib/kubelet \
       /var/lib/rancher/rke/log \
       /var/log/containers \
       /var/log/kube-audit \
       /var/log/pods \
       /var/run/calico
```
You will also need to ssh on the master-1 and master-2 and edit the kube-apiserver manifest in `/etc/kubernetes/manifests` to remove the etcd from it's configuration. This will restart kubelet and the api-server after a few seconds
Then upgrade the node using the same process as for the 1st one.

### Add the 2nd node back via kubespray
First add the second node back to the etcd cluster same as for the 1st node, just different script! `bash 4_bootstrap_second_node.sh <master_2_ip> <master_3_ip>`

And finally just run in the docker of kubespray:
```bash
ansible-playbook -i /inventory/hosts.yaml 2_cluster.yml --skip-tags=multus
```
The playbook might hang during this step. If it hang during the join of the second master, go on the 3rd and run `docker restart kube-apiserver`. This for some reason fix the issue... Issue itself is that it can't update a configmap for the boostrap token and restarting the last RKE master fixes it...

### Removal of the 3rd node
Once all is ready and you are sure all is ready, we can remove the third node with the following process:
```bash
bash 1_delete_node.sh <node_name>
ssh <node_name>
# Teardown the node
docker rm -f $(docker ps -qa)
docker volume rm $(docker volume ls -q)
# I recomend to restart here before the next command, to ensure the command below doesn't traverse a mountpoint that would still be there, you can do the dist-upgrade here to gain some times
for mount in $(mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') /var/lib/kubelet /var/lib/rancher; do umount $mount; done
rm -rf /etc/cni \
       /etc/kubernetes \
       /opt/cni \
       /opt/rke \
       /run/secrets/kubernetes.io \
       /run/calico \
       /run/flannel \
       /var/lib/calico \
       /var/lib/etcd \
       /var/lib/cni \
       /var/lib/kubelet \
       /var/lib/rancher/rke/log \
       /var/log/containers \
       /var/log/kube-audit \
       /var/log/pods \
       /var/run/calico
```
You will also need to ssh on the master-1 and master-2 and edit the kube-apiserver manifest in `/etc/kubernetes/manifests` to remove the etcd from it's configuration. This will restart kubelet and the api-server after a few seconds
Then upgrade the node using the same process as for the 1st one.


### Add the 3rd node back via kubespray
For this one, we can finally use the real playbook, so move back to `/kubespray` folder and run

And finally just run in the docker of kubespray. **Make sure that NO WORKER NODE ARE IN THE INVENTORY**:
```bash
ansible-playbook -i /inventory/hosts.yaml cluster.yml --skip-tags=multus
```

## Step 5 - Control-plane upgrade to 1.24
> **WARNING**: Ensure that all is OK before continuing. This step only exist to avoid having to upgrade all the worker node to 1.24. As we'll remove them later, we'll just re-add them directly as 1.24 skipping a whole upgrade.

Once you are sure, just run `ansible-playbook -b -i /inventory/hosts.yaml upgrade-cluster.yml --skip-tags=multus -e kube_version=v1.24.10 -e upgrade_node_confirm=true` inside the container. this will do the job.

> **INFO**: It is possible to skip one upgrade fully of the worker node. If you want to use this faster process, do the upgrade of the master to v1.25.6 right after doing the 1.24.10 one. Your controlplane will have a 2 version skew, but this is supported by Kubernetes. In that case, in step 6 (if your control plane is running 1.25.6), change the kube_version in the name.

## Step 6 - Replacement of the workers
> **WARNING**: Ensure that all is OK before continuing. Adjust version if you did a double upgrade of the Control Plane

Go in `006_replace_worker` and just run `bash 1_delete_node.sh <name>`. Then teardown the node using the usual process, upgrade it, and enable it in kubepray inventory. 

Once ready just run
```bash
ansible-playbook -b -i /inventory/hosts.yaml facts.yml
ansible-playbook -b -i /inventory/hosts.yaml scale.yml --limit=<node> --skip-tags=multus -e kube_version=v1.24.10
```

## Step 7 - Upgrade to 1.25
> **INFO**: Not needed if you did the double upgrade of the Control plane.
Last step, easiest one in theory:

Upgrade the masters first
```bash
ansible-playbook -b -i /inventory/hosts.yaml facts.yml 
ansible-playbook -b -i /inventory/hosts.yaml upgrade-cluster.yml --skip-tags=multus -e kube_version=v1.25.6 --limit "kube_control_plane:etcd" -e upgrade_node_confirm=true
```

And then the workers:
```bash
ansible-playbook -b -i /inventory/hosts.yaml facts.yml 
ansible-playbook -b -i /inventory/hosts.yaml upgrade-cluster.yml --skip-tags=multus -e kube_version=v1.25.6 --limit "*worker*" -e upgrade_node_confirm=true
```