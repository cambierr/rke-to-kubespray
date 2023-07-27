if [ -z "$1" ]; 
then echo "Please specify the node name as first parameter"; exit 1;
fi

NODE_NAME=$1

# TODO: Add Cordon. Uncomment line below if not doing the drain manually
# kubectl drain --force --ignore-daemonsets --grace-period 300 --timeout 360s --delete-emptydir-data ${NODE_NAME}
node_id=`ssh root@${NODE_NAME} docker exec etcd etcdctl member list  | grep ${NODE_NAME} | cut -d, -f1`
ssh root@${NODE_NAME} docker exec etcd etcdctl member remove $node_id
kubectl delete node ${NODE_NAME}
