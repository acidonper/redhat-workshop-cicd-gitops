##
# Script to prepare Openshift Laboratory
##

##
# Users 
##
USERS="user1
user2"

##
# Adding user to htpasswd
##
htpasswd -c -b users.htpasswd admin password
for i in $USERS
do
  htpasswd -b users.htpasswd $i $i
done

##
# Creating htpasswd file in Openshift
##
oc delete secret lab-users -n openshift-config
oc create secret generic lab-users --from-file=htpasswd=users.htpasswd -n openshift-config

##
# Configuring OAuth to authenticate users via htpasswd
##
cat <<EOF > oauth.yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - htpasswd:
      fileData:
        name: lab-users
    mappingMethod: claim
    name: lab-users
    type: HTPasswd
EOF

cat oauth.yaml | oc apply -f -


##
# Creating Role Binding for ArgoCD
##
oc adm policy add-cluster-role-to-user admin admin

for i in $USERS
do
  oc new-project $i-jump-app-dev
  oc label namespace $i-jump-app-dev argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-jump-app-dev
  
  oc new-project $i-jump-app-dev-k8s
  oc label namespace $i-jump-app-dev-k8s argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-jump-app-dev-k8s
  
  oc new-project $i-jump-app-dev-helm
  oc label namespace $i-jump-app-dev-helm argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-jump-app-dev-helm

  oc new-project $i-jump-app-pre
  oc label namespace $i-jump-app-pre argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-jump-app-pre

  oc new-project $i-jump-app-pro
  oc label namespace $i-jump-app-pro argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-jump-app-pro
  
  oc new-project $i-jump-app-cicd
  oc label namespace $i-jump-app-cicd argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-jump-app-cicd

  oc new-project $i-gitops-argocd
  oc label namespace $i-gitops-argocd argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-gitops-argocd

  # oc process -f ./scripts/files/argocd_operator.yaml -p USERNAME=$i | oc apply -f -
  oc apply -f ./scripts/files/redhat_gitops.yaml
  sleep 30
  oc process -f ./scripts/files/argocd_objs.yaml -p USERNAME=$i | oc apply -f -

done

##
##
# Disable self namespaces provisioner 
##
oc patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'
