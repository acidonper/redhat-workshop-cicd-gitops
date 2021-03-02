##
# Script to prepare Openshift Laboratory
##

##
# Users 
##
USERS="pepito
pepita
manolito
manolita"

##
# Adding user to htpasswd
##
htpasswd -C users.htpasswd admin password
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
    name: my_htpasswd_provider
    type: HTPasswd
EOF

cat oauth.yaml | oc apply -f -


##
# Creating Role Binding for ArgoCD
##


for i in $USERS
do
  oc new-project $i-namespace
  oc adm policy add-role-to-user admin $i -n $i-namespace

cat <<EOF > argocd-rolebinding-$i.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-application-controller
  namespace: {{ $ns }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: ServiceAccount
  name: argocd-application-controller
  namespace: gitops-argocd
EOF
  
  cat argocd-rolebinding-$i.yaml | oc apply -f -

done

##
##
# Disable self namespaces provisioner 
##
# oc patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'
