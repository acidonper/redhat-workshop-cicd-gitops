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
for i in $USERS
do
  htpasswd -b users.htpasswd $i password
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
# Creating a custom role to manage Istio Objects
##
cat <<EOF > admin-mesh-custom-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admin-mesh
rules:
  - apiGroups:
    - ""
    resources:
    - secrets
    verbs:
    - create
    - get
    - list
    - watch
  - apiGroups:
    - ""
    - route.openshift.io
    resources:
    - routes
    verbs:
    - create
    - delete
    - deletecollection
    - get
    - list
    - patch
    - update
    - watch
  - apiGroups:
    - ""
    - route.openshift.io
    resources:
    - routes/custom-host
    verbs:
    - create
  - apiGroups:
    - ""
    - route.openshift.io
    resources:
    - routes/status
    verbs:
    - get
    - list
    - watch
  - apiGroups:
    - ""
    - route.openshift.io
    resources:
    - routes
    verbs:
    - get
    - list
    - watch
  - apiGroups:
    - maistra.io
    resources:
    - servicemeshmemberrolls
    verbs:
    - get
    - list
    - watch
EOF

cat admin-mesh-custom-role.yaml | oc apply -f -

##
# Disable self namespaces provisioner 
##
# oc patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'

##
# Adding required roles to users
##
for i in $USERS
do
  oc new-project $i-namespace
  oc adm policy add-role-to-user view $i -n istio-system
  oc adm policy add-role-to-user admin $i -n $i-namespace
  oc adm policy add-role-to-user admin-mesh $i -n istio-system
done

