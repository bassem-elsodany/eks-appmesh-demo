#### [1] execute to prepare the env

> export CLUSTER_NAME=eks-appmesh-demo \
  export AWS_ACCOUNT_ID=xxxxxxx \
  export AWS_DEFAULT_REGION=eu-west-2 \
  export AWS_DEFAULT_PROFILE=development \
  export APP_MESH_NS=appmesh-system \
  export APP_MESH_CONTROLLER_NAME=appmesh-controller \
  export APP_MESH_ROLE_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:role/appmesh-controller \
  export KONG_NS=kong \
  export DEMO_APP_NAME=echoserver \
  export DEMO_APP_MESH_NAME=echoserver-mesh-app \
  export DEMO_APP_SVC_1=echoserver-uk \
  export DEMO_APP_SVC_2=echoserver-canada \

  > rm ~/.kube/config

---------------------------------------------------------------------------------------------------------
#### [2] execute to create the cluster

> terraform init \
  terraform plan \
  TF_VAR_profile=$AWS_DEFAULT_PROFILE TF_VAR_cluster_name=$CLUSTER_NAME terraform apply -auto-approve

##### [to generate cluster config]
> aws eks update-kubeconfig --name $CLUSTER_NAME

------------------------------------------------------------------------
#### [3] install fluentd log forwarder
> envsubst < raw-manifests/logs/fluentd.yml | kubectl apply -f -


##### AWS ES
> aws es create-elasticsearch-domain \
  --domain-name rtf-eks-demo-logs \
  --elasticsearch-version 7.4 \
  --elasticsearch-cluster-config \
  InstanceType=t2.small.elasticsearch,InstanceCount=1 \
  --ebs-options EBSEnabled=true,VolumeType=standard,VolumeSize=10 \
  --access-policies '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["es:*"],"Resource":"*"}]}'

------------------------------------------------------------------------
#### [4] install & configure app mesh controller

> envsubst < raw-manifests/appmesh/sa-appmesh-controller.yml | kubectl apply -f -

##### SDS disabled app mesh
> helm upgrade -i $APP_MESH_CONTROLLER_NAME  eks/appmesh-controller \
    --namespace $APP_MESH_NS \
    --set region=$AWS_DEFAULT_REGION \
    --set serviceAccount.create=false \
    --set serviceAccount.name=$APP_MESH_CONTROLLER_NAME \
    --set tracing.enabled=true \
    --set tracing.provider=x-ray \
    --set sds.enabled=false
------------------------------------------------------------------------
#### [5] install app V1

##### [5.1] No MTLS
> envsubst < raw-manifests/app/base-v1.yml | kubectl apply -f -

##### set default ns
> kubectl config set-context --current --namespace=$AWS_DEFAULT_PROFILE

> export ECHO_POD_NAME=$(kubectl get pods -n $AWS_DEFAULT_PROFILE -l app=$DEMO_APP_NAME -o jsonpath='{.items[].metadata.name}') \
  kubectl exec -n $AWS_DEFAULT_PROFILE  -it ${ECHO_POD_NAME} -c $DEMO_APP_NAME bash

> curl -s echoserver-uk-v1:9080/ping \
  curl -s echoserver-canada-v1:9080/ping \
  curl -s echoserver:9080/servers/echoserver-uk-v1 \
  curl -s echoserver:9080/servers/echoserver-canada-v1

##### [5.2] MTLS File Based
> export DEMO_APP_CA_CERT=ca_1_cert.pem \
  export DEMO_APP_K8S_SECRET=echoserver-ca1-tls

> chmod u+x raw-manifests/app/mtls/filebased/certs.sh \
  sudo ./raw-manifests/app/mtls/filebased/certs.sh

###### verify that the echoserver-uk app certificate was signed by CA 1
> openssl verify -verbose -CAfile raw-manifests/app/mtls/filebased/ca_1_cert.pem  raw-manifests/app/mtls/filebased/echoserver-uk_cert.pem

###### mount certificates as Kubernetes Secrets
> chmod u+x raw-manifests/app/mtls/filebased/deploy.sh \
  ./raw-manifests/app/mtls/filebased/deploy.sh

###### List Kubernetes Secrets
> kubectl get secrets -n $AWS_DEFAULT_PROFILE

###### deploy app
> envsubst < raw-manifests/app/mtls/filebased/base-v1.yml | kubectl apply -f -
------------------------------------------------------------------------
#### [6] configure meshed app v1

##### [6.1] No MTLS APP
> envsubst < raw-manifests/app/base-v1-mesh.yml | kubectl apply -f -

###### list appmesh components
> kubectl get virtualservices \
  kubectl get virtualrouters \
  kubectl get virtualnodes

###### Reload deployment
> kubectl -n development rollout restart deployment ${DEMO_APP_SVC_2}-v1 $DEMO_APP_NAME ${DEMO_APP_SVC_1}-v1

> export ECHO_POD_NAME=$(kubectl get pods -n $AWS_DEFAULT_PROFILE -l app=$DEMO_APP_NAME -o jsonpath='{.items[].metadata.name}') \
  kubectl exec -n $AWS_DEFAULT_PROFILE  -it ${ECHO_POD_NAME} -c $DEMO_APP_NAME bash

> curl -s echoserver-uk.development.svc.cluster.local:9080/ping \
  curl -s echoserver-canada.development.svc.cluster.local:9080/ping

##### [6.2] File based MTLS

###### Deploy APP
> envsubst < raw-manifests/app/mtls/filebased/base-v1-mesh-mtls-file-based.yml | kubectl apply -f -

###### Reload deployment
> kubectl -n development rollout restart deployment $DEMO_APP_SVC_2-v1 $DEMO_APP_NAME $DEMO_APP_SVC_1-v1

###### Set Vars
> ECHO_POD=$(kubectl get pod -l "app=echoserver" -n $AWS_DEFAULT_PROFILE --output=jsonpath={.items..metadata.name}) \
  UK_POD=$(kubectl get pod -l "version=v1,app=uk" -n $AWS_DEFAULT_PROFILE  --output=jsonpath={.items..metadata.name}) \
  CANADA_POD=$(kubectl get pod -l "version=v1,app=canada" -n $AWS_DEFAULT_PROFILE  --output=jsonpath={.items..metadata.name})

###### List mounted certs under each app
> kubectl exec -it $CANADA_POD -n $AWS_DEFAULT_PROFILE -c envoy -- ls /certs/ \
  kubectl exec -it $ECHO_POD -n $AWS_DEFAULT_PROFILE -c envoy -- ls /certs/ \
  kubectl exec -it $UK_POD -n $AWS_DEFAULT_PROFILE -c envoy -- ls /certs/

###### Check Health
> kubectl exec -it $ECHO_POD -n  $AWS_DEFAULT_PROFILE -c envoy -- curl http://localhost:9901/clusters | grep -E '((uk|canada).*health)'


##### [6.3] SDS MTLS

###### Install SPIRE
> export TRUSTED_DOMAIN=development.aws \
  envsubst < raw-manifests/spire/spire.yml | kubectl apply -f -

###### register enteries
> chmod u+x /raw-manifests/spire/register_server_entries.sh  \
  ./raw-manifests/spire/register_server_entries.sh register $TRUSTED_DOMAIN $AWS_DEFAULT_PROFILE


###### check registered enteries
> kubectl exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry show \
  export SVID_CA_TRUST_DOMAIN=spiffe://development.aws \
  export ECHO_SERVER_APP_SVID=spiffe://development.aws/echo-server \
  export ECHO_SERVER_SVC_1_SVID=spiffe://development.aws/uk \
  export ECHO_SERVER_SVC_2_SVID=spiffe://development.aws/canada \

envsubst < raw-manifests/app/mtls/sds/base-v1-mesh-mtls-sds.yml | kubectl apply -f -

------------------------------------------------------------------------
#### [7] install app V2

> envsubst < raw-manifests/app/base-v2.yml | kubectl apply -f -

> kubectl get virtualservices
  kubectl get virtualrouters
  kubectl get virtualnodes

> export ECHO_POD_NAME=$(kubectl get pods -n $AWS_DEFAULT_PROFILE -l app=$DEMO_APP_NAME -o jsonpath='{.items[].metadata.name}') \
  kubectl exec -n $AWS_DEFAULT_PROFILE  -it ${ECHO_POD_NAME} -c $DEMO_APP_NAME bash

> curl -s echoserver-uk.development.svc.cluster.local:9080/ping \
  curl -s echoserver-canada.development.svc.cluster.local:9080/ping

##### routing weight
> while true; do
    curl echoserver-uk.development.svc.cluster.local:9080/ping
    echo 
    sleep .5
  done


##### connection pools and circuit breaking, retry-policy

> KONG_POD=$(kubectl get pod -l "app.kubernetes.io/name=kong" -n $KONG_NS --output=jsonpath={.items..metadata.name}) \
  kubectl exec -it $KONG_POD -n $KONG_NS -c envoy -- curl localhost:9901/stats | grep -E '(http.ingress.downstream_cx_active|upstream_cx_active|cx_open|upstream_cx_http1_total)'

> kubectl exec -it $KONG_POD -n $KONG_NS -c envoy -- curl localhost:9901/stats| grep -E '(uk-v1_development_http_9080.upstream_rq_)' \
  kubectl exec -it $KONG_POD -n $KONG_NS -c envoy -- curl localhost:9901/stats| grep -E '(cx_open)'

------------------------------------------------------------------------
#### [8] install & configure Kong Ingress controller

##### create kong namespace, create new virtual node with two backends
> envsubst < raw-manifests/kong/virtualnode.yml | kubectl apply -f -

> helm repo add kong https://charts.konghq.com \
  helm repo update

##### Install ingress controller
> helm install -n $KONG_NS $KONG_NS kong/kong --set ingressController.installCRDs=false

##### bypass egress filtering for containers running under security context with (by default) UID 1337
> kubectl patch deploy -n $KONG_NS $KONG_NS-$KONG_NS -p '{"spec":{"template":{"spec":{"containers":[{"name":"ingress-controller","securityContext":{"runAsUser": 1337}}]}}}}'

> kubectl get service -n $KONG_NS

------------------------------------------------------------------------
#### [9] Configure Ingress
Define Ingress to expose and protect the service mesh

> envsubst < raw-manifests/kong/ingress-resource.yml | kubectl apply -f -

> kubectl get ing -oyaml
------------------------------------------------------------------------
#### [9] Play with Kong resources

##### Rate limit
>  envsubst < raw-manifests/kong/ratelimiting.yml | kubectl apply -f - \
  kubectl patch ingress $DEMO_APP_NAME-ingress -n $AWS_DEFAULT_PROFILE -p '{"metadata":{"annotations":{"konghq.com/plugins":"rl-by-minute"}}}'

> curl -i http://{id}}eu-west-2.elb.amazonaws.com/echo/echoserver-uk

##### Rate limit & API Key
> envsubst < raw-manifests/kong/apikey.yml | kubectl apply -f - \
  kubectl patch ingress $DEMO_APP_NAME-ingress  -n $AWS_DEFAULT_PROFILE -p '{"metadata":{"annotations":{"konghq.com/plugins":"apikey, rl-by-minute"}}}'

###### Provision a key and associate it to a consumer
> kubectl create secret generic consumerapikey -n $AWS_DEFAULT_PROFILE --from-literal=kongCredType=key-auth --from-literal=key=secret \
  envsubst < raw-manifests/kong/consumers.yml | kubectl apply -f - \
  curl -i http://{id}}eu-west-2.elb.amazonaws.com/echo/echoserver-uk -H 'apikey:secret'
------------------------------------------------------------------------

#### [10] Destroy the env

##### Delete app mesh virtual services
>  aws appmesh list-virtual-services --mesh-name $DEMO_APP_MESH_NAME | \
jq -r ' .virtualServices[] | [.virtualServiceName] | @tsv ' | \
  while IFS=$'\t' read -r virtualServiceName; do 
    aws appmesh delete-virtual-service --mesh-name $DEMO_APP_MESH_NAME --virtual-service-name $virtualServiceName 
  done


##### Delete app mesh virtual routers
>  aws appmesh list-virtual-routers --mesh-name $DEMO_APP_MESH_NAME | \
jq -r ' .virtualRouters[] | [.virtualRouterName] | @tsv ' | \
  while IFS=$'\t' read -r virtualRouterName; do 
    aws appmesh list-routes --mesh-name $DEMO_APP_MESH_NAME --virtual-router-name $virtualRouterName | \
    jq -r ' .routes[] | [ .routeName] | @tsv ' | \
      while IFS=$'\t' read -r routeName; do 
        aws appmesh delete-route --mesh $DEMO_APP_MESH_NAME --virtual-router-name $virtualRouterName --route-name $routeName
      done
    aws appmesh delete-virtual-router --mesh-name $DEMO_APP_MESH_NAME --virtual-router-name $virtualRouterName 
  done

##### Delete app mesh virtual nodes
>  aws appmesh list-virtual-nodes --mesh-name $DEMO_APP_MESH_NAME | \
jq -r ' .virtualNodes[] | [.virtualNodeName] | @tsv ' | \
  while IFS=$'\t' read -r virtualNodeName; do 
    aws appmesh delete-virtual-node --mesh-name $DEMO_APP_MESH_NAME --virtual-node-name $virtualNodeName 
  done

##### Delete app mesh mesh
>  aws appmesh delete-mesh --mesh-name $DEMO_APP_MESH_NAME

##### Delete Kong Controller
>  kubectl delete namespace $KONG_NS

##### Delete appmesh-system controller
>  kubectl delete namespace $APP_MESH_NS

##### Delete EKS Cluster
> TF_VAR_profile=$AWS_DEFAULT_PROFILE TF_VAR_cluster_name=$CLUSTER_NAME terraform destroy -auto-approve
