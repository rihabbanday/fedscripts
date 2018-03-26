#!/bin/sh

#create PV to store etcd data; alternatively disable it by --etcd-persistent-storage=false
kubectl create -f pv_fed.yaml

CONFIG=/etc/kubernetes/admin.conf
# parse kube config file to get info
RAW_URL=""
LINE=""
N=0
NUM=$(sudo cat $CONFIG |wc -l)
getline() {  N=$(expr $N + 1); LINE=$(sudo sed -n ${N}p $CONFIG); }
while [ $N -le $NUM ]
do
        getline
        case $LINE in
        "- cluster:")
                getline; TMP_CA="$LINE"
                getline; TMP_SERVER="$LINE"
                getline; TMP_NAME="$LINE"
                NEED=$(echo $TMP_NAME |grep "kubernetes")
                if [ -n "$NEED" ]; then
                        RAW_URL="$TMP_SERVER"
                fi
                ;;
        *) ;;
        esac
done

API_SERVER_URL=$(echo $RAW_URL | awk '{split($0,a," ");print a[2]}')
API_SERVER_IP=$(echo $API_SERVER_URL | awk '{split($0,a,":");print a[2]}'| sed 's/\/\///g')

#API_SERVER_URL="https://<IP-Address>:6443"
#API_SERVER_IP="<IP-Address>"

PKI_DIR=/etc/kubernetes/pki

ROOT_CA=$PKI_DIR/ca.crt
CLIENT_CA=$PKI_DIR/apiserver-kubelet-client.crt
CLIENT_KEY=$PKI_DIR/apiserver-kubelet-client.key
#sudo chmod 644 $CLIENT_KEY

HOST_CLUSTER=central-cluster
HOST_USER=central-admin
HOST_CTX=central-context

# local context 
LOCAL_CTX=$HOST_CTX
CTL_CTX=federation

# create fed-context
kubectl config set-cluster $HOST_CLUSTER --server=$API_SERVER_URL --certificate-authority=$ROOT_CA
kubectl config set-credentials $HOST_USER --client-key=$CLIENT_KEY --client-certificate=$CLIENT_CA
kubectl config set-context $HOST_CTX --cluster=$HOST_CLUSTER --user=$HOST_USER

# create FCP and join itself
kubefed init $CTL_CTX --host-cluster-context=$HOST_CTX \
   --dns-provider="coredns"  \
   --dns-zone-name="comp.com." \
   --dns-provider-config="$HOME/coredns-provider.conf"\
   --api-server-service-type="NodePort"  \
   --api-server-advertise-address=${API_SERVER_IP} 

kubefed --context=$CTL_CTX join $HOST_CLUSTER --host-cluster-context=$HOST_CTX --cluster-context=$LOCAL_CTX
