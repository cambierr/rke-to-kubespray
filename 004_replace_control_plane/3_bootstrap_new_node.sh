if [ -z "$1" ]; 
then echo "Please specify the node IP as first parameter"; exit 1;
fi
if [ -z "$2" ]; 
then echo "Please specify the second node IP as second parameter"; exit 1;
fi
NODE_IP=$1
CERT_SRC_IP=$2

ssh root@${CERT_SRC_IP} docker exec etcd etcdctl member add etcd1 --peer-urls=https://${NODE_IP}:2380
scp root@${CERT_SRC_IP}:/etc/kubernetes/ssl/kube-ca.pem certs/ca.pem
scp root@${CERT_SRC_IP}:/etc/kubernetes/ssl/kube-ca-key.pem certs/ca-key.pem

mkdir -p certs
scp root@${CERT_SRC_IP}:/etc/kubernetes/ssl/kube-apiserver-requestheader-ca.pem certs/front-proxy-ca.crt
scp root@${CERT_SRC_IP}:/etc/kubernetes/ssl/kube-apiserver-requestheader-ca-key.pem certs/front-proxy-ca.key

scp root@${CERT_SRC_IP}:/etc/kubernetes/ssl/kube-service-account-token.pem certs/sa.pub
scp root@${CERT_SRC_IP}:/etc/kubernetes/ssl/kube-service-account-token-key.pem certs/sa.key

# Copy on new node
ssh root@${NODE_IP} mkdir -p /etc/ssl/etcd/ssl
scp certs/ca.pem root@${NODE_IP}:/etc/ssl/etcd/ssl/
scp certs/ca-key.pem root@${NODE_IP}:/etc/ssl/etcd/ssl/
ssh root@${NODE_IP} "chmod 700 /etc/ssl/etcd/ssl/*.pem"

ssh root@${NODE_IP} mkdir -p /etc/kubernetes/ssl
scp certs/ca.pem root@${NODE_IP}:/etc/kubernetes/ssl/ca.crt
scp certs/ca-key.pem root@${NODE_IP}:/etc/kubernetes/ssl/ca.key
scp certs/sa.pub root@${NODE_IP}:/etc/kubernetes/ssl/
scp certs/sa.key root@${NODE_IP}:/etc/kubernetes/ssl/

scp certs/front-proxy-ca.crt root@${NODE_IP}:/etc/kubernetes/ssl/
scp certs/front-proxy-ca.key root@${NODE_IP}:/etc/kubernetes/ssl/

ssh root@${NODE_IP} "chmod 600 /etc/kubernetes/ssl/ca.*"
ssh root@${NODE_IP} "chmod 600 /etc/kubernetes/ssl/sa.*"
ssh root@${NODE_IP} "chmod 600 /etc/kubernetes/ssl/front-proxy-ca.*"