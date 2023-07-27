if [ -z "$1" ]; 
then echo "Please specify the node IP as first parameter"; exit 1;
fi

echo "Connecting to node ${1} and fetching the docker info"
#Comment the line below if the process crashed with a "container unknown" error and rerun
ssh root@$1 docker inspect etcd > /tmp/etcd.json
echo "Parsing the docker inspect result and generating the command"
etcd_cmd=`python3 etcd.py`
echo "Prepulling the new image"
ssh root@$1 docker pull rancher/mirrored-coreos-etcd:v3.5.6
echo "Stoping the old etcd container"
ssh root@$1 docker stop etcd
echo "Waiting 1 second before removing the old container"
sleep 1
echo "Removing the old etcd container"
ssh root@$1 docker rm etcd
echo "Starting the new etcd container"
ssh root@$1 $etcd_cmd