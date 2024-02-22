# Artifactory
A collection of commands and scripts I use to automate some tasks with [JFrog Artifactory](https://jfrog.com/artifactory/)

## Run Artifactory
### Artifactory with local Docker
You can easily spin up a local Artifactory container with
```shell
# Run Artifactory with mounting a local artifactory directory to container's /var/opt/jfrog/artifactory
docker run -d --name rt -p 8082:8082 -v $(pwd)/artifactory:/var/opt/jfrog/artifactory releases-docker.jfrog.io/jfrog/artifactory-pro
```
Open a browser to http://localhost:8082

### Artifactory in Kubernetes
Examples of commands to install Artifactory in K8s with helm using various databases. See examples used here of custom values files in [values-examples](values-examples).

#### Setup Helm repository 
Add JFrog's [Helm charts](https://charts.jfrog.io) repository
```shell
helm repo add jfrog https://charts.jfrog.io
helm repo update
```

#### Default Install
Install with Artifactory's default bundled database PostgreSQL
```shell
helm upgrade --install artifactory jfrog/artifactory 
```

#### With an External PostgreSQL (recommended)
Install Artifactory with external PostgreSQL database in K8s
```shell
# Add Bitnami helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Install PostgreSQL
helm upgrade --install postgresql bitnami/postgresql -f values-examples/values-postgresql.yaml

# Install Artifactory (PostgreSQL driver already included in Docker image)
helm upgrade --install artifactory jfrog/artifactory -f values-examples/values-postgresql.yaml

# Open a shell to the postgresql pod and connect to the database
kubectl exec -it postgresql-0 -- bash

# Inside the container, connect to the database
psql --host postgresql -U artifactory

# You can open a client container to this database with
kubectl run pg-client --rm --tty -i --restart='Never' --image docker.io/bitnami/postgresql:15.1.0-debian-11-r13 \
    --env="PGPASSWORD=password1" --labels="postgresql-client=true" --command -- psql --host postgresql -U artifactory
```

#### With an External MySQL (deprecated)
Install Artifactory with external MySQL database in K8s (deprecated and will eventually not be supported)
```shell
# Add Bitnami helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Install MySQL
helm upgrade --install mysql bitnami/mysql -f values-examples/values-mysql.yaml

# Install Artifactory
helm upgrade --install artifactory jfrog/artifactory -f values-examples/values-mysql.yaml

# Open a shell to the mysql pod and connect to the database
kubectl exec -it mysql-0 -- bash

# Inside the container, connect to the database
mysql --host=localhost --user=artifactory --password=password1 artifactory
```

#### With a memory based emptyDir volume as cache-fs
Install with a [memory backed emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir) for [cache-fs](https://www.jfrog.com/confluence/display/JFROG/Cached+Filesystem+Binary+Provider)

**IMPORTANT: The memory used by the volume is counted against your container's memory limit!**</br>
**So you need to adjust the artifactory container's memory limit to <original limit> + <custom volume sizeLimit>**

```shell
helm upgrade --install artifactory jfrog/artifactory -f values-examples/values-memory-cache-fs.yaml 
```

## Benchmark Artifactory
Here are a couple of ways to benchmark Artifactory. This is very useful for comparing the impact of configuration changes on the performance of Artifactory

### Using Apache ab
Using [Apache ab](https://httpd.apache.org/docs/current/programs/ab.html) is useful for running multiple concurrent downloads of a single file.</br>
Multiple instances of `ab` can be run to add more load and to combine multiple files and technologies

#### Downloads
First, upload a test file you want to use to a repository. After that, you can run
```shell
# From official ab docs:
# -A username:password: Supply BASIC Authentication credentials to the server.
# -c <num>: Number of multiple requests to perform at a time. Default is one request at a time.
# -n <num>: Number of requests to perform for the benchmarking session. The default is to just perform a single request which usually leads to non-representative benchmarking results.

# 10 concurrent downloads with a total of 1000 requests
ab -A admin:password -c 10 -n 1000 http://localhost/artifactory/example-repo-local/example-file.bin

# Use a token instead of basic auth to download
ab -H "Authorization: Bearer ${TOKEN}" -c 10 -n 1000 http://localhost/artifactory/example-repo-local/example-file.bin
```

#### Uploads
**WARNING:** For upload tests, use a concurrent value of `1` to avoid errors!

First, create a local file to be uploaded
```shell
# From official ab docs:
# -A username:password: Supply BASIC Authentication credentials to the server.
# -c <num>: Number of multiple requests to perform at a time. Default is one request at a time.
# -n <num>: Number of requests to perform for the benchmarking session. The default is to just perform a single request which usually leads to non-representative benchmarking results.
# -u <file>: File containing data to PUT.

# 1 concurrent upload of a file 50 times
ab -A admin:password -u ./file.bin -c 1 -n 50 http://localhost/artifactory/example-repo-local/file.bin

# Use a token instead of basic auth to upload
ab -H "Authorization: Bearer ${TOKEN}" -u ./file.bin -c 1 -n 50 http://localhost/artifactory/example-repo-local/file.bin
```

#### Helm Chart
You can use the [artifactory-load](helm/artifactory-load) helm chart to deploy one or more pods running `ab` once or in an infinite loop.

This chart support **up to** 4 different `ab` scenarios at the same time (using multiple deployments). The default is a single deployment.

Upload the files you want to use for testing. These should each be configured in its own deploymentX block. See example below that has 4 different files of different sizes.

Create a `test-value.yaml` with the specific details of your run
```yaml
replicaCount: 2

artifactory:
  url: http://artifactory-server
  auth: true
  user: admin
  password: password

infinite: true

# 100 concurrent downloads of a 5 KB sized file
deployment0:
  replicaCount: 3
  file: generic-local/5kb.zip
  requests: 10000
  concurrency: 100

# 20 concurrent downloads of a 2 MB sized file
deployment1:
  replicaCount: 3
  enabled: true
  file: generic-local/2mb.zip
  requests: 10000
  concurrency: 20

# 10 concurrent downloads of a 100 MB sized file
deployment2:
  replicaCount: 3
  enabled: true
  file: generic-local/100mb.zip
  requests: 10000
  concurrency: 10

# 5 concurrent downloads of a 1 GB sized file
deployment3:
  replicaCount: 3
  enabled: true
  file: generic-local/1gb.zip
  requests: 10000
  concurrency: 5
```

Deploy the chart with the command
```shell
helm upgrade --install al . -f test-values.yaml
```

### Shell Scripts
* [artifactoryBenchmark.sh](artifactoryBenchmark.sh) - Run download, upload (or both) tests with a single file for a given size and iterations count. Results as CSV
* [artifactoryLoad.sh](artifactoryLoad.sh) - Run parallel processes of `artifactoryBenchmark.sh`. This is useful for generating load on Artifactory
* [artifactoryDownloadsLoop.sh](artifactoryDownloadsLoop.sh) - Create and upload a single generic binary generic file to Artifactory and download it in loops with set iterations and parallel threads

Each script has its own usage you can get with
```shell
./<script.sh> --help
```

### Benchmark from a Pod
You can run these tests from within a pod in Kubernetes
```shell
# Deploy a pod with the needed tools
kubectl apply -f https://github.com/eldada/kubernetes-scripts/raw/master/yaml/podWithTools.yaml

# Open a shell to the pod
kubectl exec -it pod-with-tools --bash

## You can use the load scripts from this repository, or directly the Apache ab utility, which is also installed in this pod

# To use the scripts, clone this repository
cd /opt
git clone https://github.com/eldada/command-examples.git

cd command-examples/artifactory

# Run the script(s) you want
# NOTE - use the internal artifactory service rather than the external load balancer
./artifactoryBenchmark.sh --help
```
