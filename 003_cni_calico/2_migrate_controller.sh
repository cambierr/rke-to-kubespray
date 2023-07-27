echo "Once first part is fully done"
kubectl delete ClusterRole calico-kube-controllers
kubectl delete ClusterRoleBinding calico-kube-controllers
kubectl delete -n kube-system Deployment calico-kube-controllers
kubectl delete -n kube-system ServiceAccount calico-kube-controllers
kubectl delete -n kube-system PodDisruptionBudget calico-kube-controllers
kubectl apply -f calico-kube-cr.yml
kubectl apply -f calico-kube-crb.yml
kubectl apply -f calico-kube-sa.yml
kubectl apply -f calico-kube-controllers.yml


