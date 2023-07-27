MASTER_IP=$1

if [ -z "$1" ]; 
then echo "Please specify the node IP as first parameter"; exit 1;
fi
if [ -z "$2" ]; 
then echo "Please specify the second node IP as second parameter"; exit 1;
fi

# ##Stop api server
echo "Connecting to node ${1} and fetching the docker info"
ssh root@${MASTER_IP} docker inspect kube-apiserver > /tmp/apiserver.json
echo "Parsing the docker inspect result and generating the command"
api_server_run=`python3 kube-apiserver.py $1 $2`
echo "Stoping the old kube-apiserver container"
ssh root@${MASTER_IP} docker stop kube-apiserver
echo "Waiting 1 second before removing the old container"
sleep 1
echo "Removing the old kube-apiserver container"
ssh root@${MASTER_IP} docker rm kube-apiserver
echo "Starting the new kube-apiserver container"
ssh root@${MASTER_IP} ${api_server_run}