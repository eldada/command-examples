# Setting up prometheus-operator with helm
This guide is based on [official helm chart](https://hub.helm.sh/charts/stable/prometheus-operator).<br>
This will deploy the prometheus-operator on the selected Kubernetes cluster.

**NOTE:** This is a simple setup I use for my development clusters and should be treated as such!

## Required
- Kubernetes 1.10+ with Beta APIs
- Helm 2.10+

## Steps
### Helm
- Install [helm](https://helm.sh/)

- Helm on an RBAC enabled cluster. This will give tiller `cluster-admin` role
```bash
kubectl -n kube-system create sa tiller && \
    kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller && \
    helm init --service-account tiller
```

- No RBAC
```bash
helm init
```

### Deployment
- Create a dedicated namespace
```bash
kubectl create ns monitoring
```

- Use a custom `values.yaml` (with or without RBAC). See [values-rbac-on.yaml](values-rbac-on.yaml) and [values-rbac-off.yaml](values-rbac-off.yaml)

- Deploy prometheus-operator
```bash
# Get latest charts version
helm repo update

# Deploy (upgrade if already exists)
helm upgrade --install monitor --namespace monitoring -f ./values-rbac-(on|off).yaml stable/prometheus-operator
```

- Forward local port 3000 to Grafana service
```bash
kubectl port-forward -n monitoring svc/monitor-grafana 3000:80 &
```

- Browse to http://localhost:3000. Login with admin/password
