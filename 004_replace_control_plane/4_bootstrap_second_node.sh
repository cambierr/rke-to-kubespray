if [ -z "$1" ]; 
then echo "Please specify the node IP as first parameter"; exit 1;
fi
if [ -z "$2" ]; 
then echo "Please specify the third node IP as second parameter"; exit 1;
fi
NODE_IP=$1
CERT_SRC_IP=$2

ssh root@${CERT_SRC_IP} docker exec etcd etcdctl member add etcd2 --peer-urls=https://${NODE_IP}:2380