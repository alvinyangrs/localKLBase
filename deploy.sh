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
	iterations=30

	i=1
	while [ $i -le $iterations ]; do
    		pod_status=$(kubectl describe pod $podname | grep -A 20 "Containers:" | grep "State:")
    		if [[ $pod_status == *"Running"* ]]; then
        		echo "$podname start"
        		break
    		fi

		if [[ $pod_status == *"ContainerCreating"* ]]; then
                        sleep 20
			if [ i%10 -eq 0 ]; then
				echo "$podname still creating"
			fi
		else
			echo "$podname status $pod_status, check detail error status"
			break
                fi

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

#kubectl apply -f ubuntu-operation.yaml
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ubuntu-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ubuntu-demo
  template:
    metadata:
      name: ubuntu-pod
      labels:
        app: ubuntu-demo
    spec:
      containers:
      - name: ubuntu-container
        image: registry.cn-hangzhou.aliyuncs.com/ryang-test/ubuntu:24.04 #ubuntu:latest
        # command: ["sleep", "3600"]  # Sleep for 3600s
        # Get into the pod, replace with
        command: ["/bin/bash"]
        args: ["-c", "trap : TERM INT; sleep infinity & wait"]
        env:
        - name: ENV_VAR_NAME
          value: "value"
        ports:
        - containerPort: 80
        volumeMounts:
        - name: pvc1
          mountPath: "/mnt1"
        - name: pvc2
          mountPath: "/mnt2"
        - name: hostpath
          mountPath: "/mnt3"

      imagePullSecrets:
      - name: regcred
      volumes:
      - name: pvc1
        persistentVolumeClaim:
          claimName: elasticsearch-plugin
      - name: pvc2
        persistentVolumeClaim:
          claimName: qanything-resource
      - name: hostpath
        hostPath:
          path: /home/sysadmin/localKLBase/  # 替换为宿主机上的实际路径
          type: Directory
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                - controller-0

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  labels:
    io.kompose.service: elasticsearch-plugin
  name: elasticsearch-plugin
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
  storageClassName: cephfs

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  labels:
    io.kompose.service: qanything-resource
  name: qanything-resource
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: cephfs

EOF


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
	export HTTPS_PROXY=147.11.252.42:9090
	git config --global core.compression 0
	git config --global http.postBuffer 4524288000
	git config --global https.postBuffer 4524288000
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
if [[ $status -ne $okok ]]; then
        echo "pod etcd status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/minio-deployment-v1.yaml
check_pod_status "minio"
status=$?
if [[ $status -ne $okok ]]; then
        echo "pod minio status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/standalone-deployment-v1.yaml
check_pod_status "standalone"
status=$?
if [[ $status -ne $okok ]]; then
        echo "pod standalone status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/mysql-deployment-v1.yaml
check_pod_status "mysql"
status=$?
if [[ $status -ne $okok ]]; then
        echo "pod mysql status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/elasticsearch-pod-v1.yaml
check_pod_status "elasticsearch"
status=$?
if [[ $status -ne $okok ]]; then
        echo "pod elasticsearch status check fail, return $status"
        exit
fi

kubectl apply -f /home/sysadmin/localKLBase/localKLBase/k8syaml/qanything-local-deployment-v1.yaml
check_pod_status "qanything"
status=$?
if [[ $status -ne $okok ]]; then
        echo "pod qanyhing status check fail, return $status"
        exit
fi


