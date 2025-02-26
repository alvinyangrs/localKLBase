#!/bin/bash

# $1 is name string to be checked
check_pod_status() {
	#check ubuntu deployment stat until it's running
	podname=$(kubectl get pods | grep $1 | awk '{print $1}')

	if [ -z "$podname" ]; then
    		echo "No pod name begin with $1 found."
    		return 1
	fi

	deployname=$(kubectl get deployment | grep $1 | awk '{print $1}')
	iterations=10

	i=1
	while [ $i -le $iterations ]; do
    		pod_status=$(kubectl describe pod $podname | grep -A 20 "Containers:" | grep "State:")
    		if [[ $pod_status == *"Running"* ]]; then
        		echo "$podname start"
        		break
    		fi

    		sleep 10

    		i=$((i + 1))
	done

	if [ $i -gt $iterations ]; then
    		echo "ubuntu deployment did not start within the expected time."
    		return 1
	fi
	return 0
}



kubectl create secret docker-registry regcred \
    --docker-server=registry.cn-hangzhou.aliyuncs.com \
    --docker-username=confucian_tju@hotmail.com \
    --docker-password=Yrs@201202 \
    --docker-email=confucian_tju@hotmail.com

kubectl apply -f ubuntu-operation.yaml
echo 0
okok=0
check_pod_status "ubuntu"
status=$?
if [ $status -ne $okok ]; then
	echo "pod ubuntu status check fail, return $status"
	exit
fi
echo 1
podname=$(kubectl get pods | grep ubuntu | awk '{print $1}')
#go into ubuntu deployment with bash
#kubectl cp prepare_in_ubuntu.sh $podname:/root/prepare_in_ubuntu.sh 
kubectl exec  $podname -- bash -c "
	apt update
	apt install -y git
	cd /mnt3
	git config --global core.compression 0
	git clone --recurse-submodules https://github.com/alvinyangrs/localKLBase.git
	cp localKLBase/model_config.py localKLBase/QAnything/qanything_kernel/configs/model_config.py
	cp -rf localKLBase/QAnything/third_party/es/plugins/* /mnt1
	if [ -d /mnt1/lost_found ]; then 
		rm -rf /mnt1/lost+found
	fi
	cp -rf localKLBase/QAnything/* /mnt2
	"
#kubectl exec  $podname -- bash /prepare_in_ubuntu.sh
echo 2
if [ -z "/home/sysadmin/localKLBase/localKLBase" ]; then
    echo "Ubuntu prepare fail, no localKLBase repo."
    exit 1
fi

cd /home/sysadmin/localKLBase/localKLBase/QAnything
#cp ../model_config.py qanything_kernel/configs/model_config.py

#kubectl cp  third_party/es/plugins $podname:/mnt1
#kubectl exec $podname -- bash rm -rf /mnt1/lost*

#kubectl cp  * $podname:/mnt2
kubectl delete deployments.apps $deployname 


kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/etcd-deployment-v1.1.yaml
check_pod_status "etcd"
status=$?
if [[ $status -ne 0]]; then
        echo "pod etcd status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/minio-deployment-v1.yaml
check_pod_status "minio"
status=$?
if [[ $status -ne 0]]; then
        echo "pod minio status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/standalone-deployment-v1.yaml
check_pod_status "standalone"
status=$?
if [[ $status -ne 0]]; then
        echo "pod standalone status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/mysql-deployment-v1.yaml
check_pod_status "mysql"
status=$?
if [[ $status -ne 0]]; then
        echo "pod mysql status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/elasticsearch-pod-v1.yaml
check_pod_status "elasticsearch"
status=$?
if [[ $status -ne 0]]; then
        echo "pod elasticsearch status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/qanything-local-deployment-v1.yaml
check_pod_status "qanything"
status=$?
if [[ $status -ne 0]]; then
        echo "pod qanyhing status check fail, return $status"
        exit
fi


