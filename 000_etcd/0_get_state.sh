ETCD_1=<ip_master_1>
ETCD_2=<ip_master_2>
ETCD_3=<ip_master_3>

ssh root@${ETCD_3} docker exec -e ETCDCTL_ENDPOINTS=https://${ETCD_1}:2379,https://${ETCD_2}:2379,https://${ETCD_3}:2379 etcd etcdctl endpoint status --write-out table
ssh root@${ETCD_3} docker exec etcd etcdctl member list --write-out table