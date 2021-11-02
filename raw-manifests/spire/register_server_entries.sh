#!/usr/bin/env bash

set -e
TRUSTED_DOMAIN=$2
AWS_DEFAULT_PROFILE=$3


register_server_entries() {
    kubectl exec -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry create $@
}


if [ "$1" == "register" ]; then
  echo "Registering an entry for spire agent..."
  echo "TRUSTED_DOMAIN is" $TRUSTED_DOMAIN
  register_server_entries \
    -spiffeID spiffe://$TRUSTED_DOMAIN/ns/spire/sa/spire-agent \
    -selector k8s_sat:cluster:$CLUSTER_NAME \
    -selector k8s_sat:agent_ns:spire \
    -selector k8s_sat:agent_sa:spire-agent \
    -node

  echo "Registering an entry for the kong name..."
  register_server_entries \
    -parentID spiffe://$TRUSTED_DOMAIN/ns/spire/sa/spire-agent \
    -spiffeID spiffe://$TRUSTED_DOMAIN/kong \
    -selector k8s:ns:kong \
    -selector k8s:sa:kong-kong \
    -selector k8s:pod-label:app.kubernetes.io/name:kong \
    -selector k8s:container-name:envoy

  echo "Registering an entry for the echo server"
  register_server_entries \
    -parentID spiffe://$TRUSTED_DOMAIN/ns/spire/sa/spire-agent \
    -spiffeID spiffe://$TRUSTED_DOMAIN/echo-server \
    -selector k8s:ns:$AWS_DEFAULT_PROFILE \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:echo-server \
    -selector k8s:pod-label:version:v1 \
    -selector k8s:container-name:envoy

  echo "Registering an entry for the uk app - version:v1..."
  register_server_entries \
    -parentID spiffe://$TRUSTED_DOMAIN/ns/spire/sa/spire-agent \
    -spiffeID spiffe://$TRUSTED_DOMAIN/uk \
    -selector k8s:ns:$AWS_DEFAULT_PROFILE \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:uk \
    -selector k8s:pod-label:version:v1 \
    -selector k8s:container-name:envoy

  echo "Registering an entry for the canada app - version:v1..."
  register_server_entries \
    -parentID spiffe://$TRUSTED_DOMAIN/ns/spire/sa/spire-agent \
    -spiffeID spiffe://$TRUSTED_DOMAIN/canada \
    -selector k8s:ns:$AWS_DEFAULT_PROFILE \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:canada \
    -selector k8s:pod-label:version:v1 \
    -selector k8s:container-name:envoy
fi