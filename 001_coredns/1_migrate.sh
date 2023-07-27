# If you want to prepull fill the node list there!
NODES=(ip_node_1 ip_node_2 ip_node_n)
for node in "${NODES[@]}"
do
   ssh root@${node} docker pull registry.k8s.io/coredns/coredns:v1.8.6
done

echo "Clean old rke data"
kubectl get -n kube-system ConfigMap rke-coredns-addon -o json | jq -r '.data."rke-coredns-addon"' | kubectl delete -f -
echo "Manually clean - Checks"
kubectl delete ClusterRoleBinding system:coredns-autoscaler
kubectl delete ClusterRole system:coredns-autoscaler
kubectl delete -n kube-system ConfigMap coredns-autoscaler
kubectl delete -n kube-system Deployment coredns-autoscaler
kubectl delete -n kube-system ServiceAccount coredns-autoscaler
kubectl delete -n kube-system Service kube-dns
kubectl delete -f coredns-clusterrolebinding.yml
kubectl delete -f coredns-clusterrole.yml
kubectl delete -f coredns-config.yml
kubectl delete -f coredns-deployment.yml
kubectl delete -f coredns-sa.yml
kubectl delete -f coredns-svc.yml
kubectl delete -f dns-autoscaler-clusterrolebinding.yml
kubectl delete -f dns-autoscaler-clusterrole.yml
kubectl delete -f dns-autoscaler-sa.yml
kubectl delete -f dns-autoscaler.yml
#Rancher specifics
kubectl delete -n kube-system ConfigMap rke-coredns-addon
kubectl delete -n kube-system Job rke-coredns-addon-deploy-job

echo "Apply kubespray templates"
kubectl apply -f coredns-clusterrolebinding.yml
kubectl apply -f coredns-clusterrole.yml
kubectl apply -f coredns-config.yml
kubectl apply -f coredns-deployment.yml
kubectl apply -f coredns-sa.yml
kubectl apply -f coredns-svc.yml
kubectl apply -f kube-dns-svc.yml
kubectl apply -f dns-autoscaler-clusterrolebinding.yml
kubectl apply -f dns-autoscaler-clusterrole.yml
kubectl apply -f dns-autoscaler-sa.yml
kubectl apply -f dns-autoscaler.yml