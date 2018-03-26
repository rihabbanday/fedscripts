#!/bin/sh

kubectl --context=federation delete cluster central-cluster

kubectl delete ns/federation-system
sleep 5

CRB=$(kubectl get ClusterRoleBinding|grep federation |awk '{split($0,a," ");print a[1]}')
CR=$(kubectl get ClusterRoles|grep federation |awk '{split($0,a," ");print a[1]}')

kubectl delete ClusterRoleBinding $CRB
kubectl delete ClusterRoles $CR

kubectl delete -f pv_fed.yaml

kubectl config delete-context federation

