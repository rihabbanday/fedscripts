#!/bin/sh
#tar vxf join_fed.tar

CONFIG=$HOME/.kube/config
FED_CTL_CLUSTER=federation
FED_HOST_CLUSTER=central-cluster
PKI_DIR=/etc/kubernetes/pki
TO_DIR=./join_k8s_fed

FED_HOST_SERVER=""
FED_CTL_SERVER=""
FED_CTL_CA=""
FED_CTL_CLIENT_CA=""
FED_CTL_CLIENT_KEY=""

# parse kube config file to get info
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
                NEED=$(echo $TMP_NAME |grep "$FED_CTL_CLUSTER")
                if [ -n "$NEED" ]; then
                        FED_CTL_SERVER="$TMP_SERVER"
                        FED_CTL_CA="$TMP_CA"
                fi
                NEED=$(echo $TMP_NAME |grep "$FED_HOST_CLUSTER")
                if [ -n "$NEED" ]; then
                        FED_HOST_SERVER="$TMP_SERVER"
                fi
                ;;
        "- name: $FED_CTL_CLUSTER"*)
                getline #skip line user:
                getline #skip line as-user-extra:
                getline; FED_CTL_CLIENT_CA="$LINE"
                getline; FED_CTL_CLIENT_KEY="$LINE"
                ;;
        *) ;;
        esac
done

# output result to TO_DIR

if [ ! -d "$TO_DIR" ]; then
        mkdir -p $TO_DIR
fi

echo $FED_CTL_CA | sudo awk '{split($0,a," ");print a[2]}' |base64 -d > $TO_DIR/fed.ca
echo $FED_CTL_CLIENT_CA | sudo awk '{split($0,a," ");print a[2]}' |base64 -d > $TO_DIR/fed.crt
echo $FED_CTL_CLIENT_KEY | sudo awk '{split($0,a," ");print a[2]}' |base64 -d > $TO_DIR/fed.key

CTL_SERVER=$(echo $FED_CTL_SERVER | sudo awk '{split($0,a," ");print a[2]}')
HOST_SERVER=$(echo $FED_HOST_SERVER | sudo awk '{split($0,a," ");print a[2]}')


cp $PKI_DIR/ca.crt $TO_DIR/
cp $PKI_DIR/apiserver-kubelet-client.crt $TO_DIR/
cp $PKI_DIR/apiserver-kubelet-client.key $TO_DIR/

echo "#!/bin/sh" >$TO_DIR/join_fed.sh
echo "" >>$TO_DIR/join_fed.sh
echo "CTL_URL=$CTL_SERVER" >>$TO_DIR/join_fed.sh
echo "HOST_URL=$HOST_SERVER" >>$TO_DIR/join_fed.sh
cat ./join_fed.template >>$TO_DIR/join_fed.sh
chmod 744 $TO_DIR/join_fed.sh

tar vcf join_fed.tar $TO_DIR
rm -rf $TO_DIR

echo "=====join_fed.tar generated===="
echo "please copy it to your master node and tar vxf join_fed.tar, then execute join_fed.sh as root user"
