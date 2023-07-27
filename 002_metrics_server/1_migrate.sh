echo "Clean old rke data"
kubectl get -n kube-system ConfigMap rke-metrics-addon -o json | jq -r '.data."rke-metrics-addon"' | kubectl delete -f -
echo "Manually clean - Checks"
kubectl delete -f auth-delegator.yaml
kubectl delete -f auth-reader.yaml
kubectl delete -f metrics-apiservice.yaml
kubectl delete -f metrics-server-deployment.yaml
kubectl delete -f metrics-server-sa.yaml
kubectl delete -f metrics-server-service.yaml
kubectl delete -f resource-reader-clusterrolebinding.yaml
kubectl delete -f resource-reader.yaml
#Rancher specifics
kubectl delete -n kube-system ConfigMap rke-metrics-addon
kubectl delete -n kube-system Job rke-metrics-addon-deploy-job

echo "Apply kubespray templates"
kubectl apply -f auth-delegator.yaml
kubectl apply -f auth-reader.yaml
kubectl apply -f metrics-apiservice.yaml
kubectl apply -f metrics-server-deployment.yaml
kubectl apply -f metrics-server-sa.yaml
kubectl apply -f metrics-server-service.yaml
kubectl apply -f resource-reader-clusterrolebinding.yaml
kubectl apply -f resource-reader.yaml