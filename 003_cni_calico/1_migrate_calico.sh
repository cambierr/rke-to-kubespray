echo "COPY NEW FILE"
for ip in ip_node_1 ip_node_2 ip_node_n
do
   scp calico.conflist.template root@${ip}:/etc/cni/net.d/
   ssh root@${ip} docker pull quay.io/calico/cni:v3.24.5
   ssh root@${ip} docker pull quay.io/calico/node:v3.24.5
   ssh root@${ip} docker pull quay.io/calico/pod2daemon-flexvol:v3.24.5
done
echo "Clean old rke data"
kubectl delete -n kube-system ConfigMap canal-config
kubectl delete -n kube-system Daemonset canal
kubectl delete -n kube-system ServiceAccount canal
kubectl delete ClusterRoleBinding canal-calico
kubectl delete ClusterRoleBinding canal-flannel
kubectl delete ClusterRole calico
kubectl delete ClusterRole flannel

#Rancher specifics
kubectl delete -n kube-system ConfigMap rke-network-plugin
kubectl delete -n kube-system Job rke-network-plugin-deploy-job

echo "Fix the network in the pool"
####### FIX YOUR CIDR HERE IF DIFFERENT
kubectl patch ippool.crd.projectcalico.org default-ipv4-ippool --patch '{"spec": {"cidr": "10.42.0.0/16","vxlanMode":"Always"}}' --type=merge

echo "Apply kubespray templates"
kubectl apply -f kdd-crds.yml
kubectl apply -f calico-cr.yml
kubectl apply -f calico-crb.yml
kubectl apply -f calico-node-sa.yml
kubectl apply -f calico-config.yml
kubectl apply -f calico-ipamconfig.yml
kubectl apply -f calico-node.yml


