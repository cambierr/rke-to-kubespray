NODE_NAME=$1
kubectl drain --force --ignore-daemonsets --grace-period 300 --timeout 360s --delete-emptydir-data ${NODE_NAME}
kubectl delete node ${NODE_NAME}