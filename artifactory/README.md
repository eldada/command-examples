# Artifactory
A collection of commands and scripts I use to automate some tasks with [JFrog Artifactory](https://jfrog.com/artifactory/)

## Scripts
* [artifactoryBenchmark.sh](artifactoryBenchmark.sh) - Run download, upload (or both) tests with a single file for a given size and iterations count. Results as CSV
* [artifactoryLoad.sh](artifactoryLoad.sh) - Run parallel processes of `artifactoryBenchmark.sh`. This is useful for generating load on Artifactory
* [artifactoryDownloadsLoop.sh](artifactoryDownloadsLoop.sh) - Create and upload a single generic binary generic file to Artifactory and download it in loops with set iterations and parallel threads

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

#### Default install
Install with Artifactory's default bundled database PostgreSQL
```shell
helm upgrade --install artifactory jfrog/artifactory 
```

#### With external PostgreSQL
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

#### With external MySQL (deprecated)
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

First, upload a test file you want to use to a repository. After that, you can run
```shell
# From official ab docs:
# -A username:password: Supply BASIC Authentication credentials to the server.
# -c <num>: Number of multiple requests to perform at a time. Default is one request at a time.
# -n <num>: Number of requests to perform for the benchmarking session. The default is to just perform a single request which usually leads to non-representative benchmarking results.

ab -A admin:password -c 10 -n 1000 http://localhost/artifactory/example-repo-local/example-file.bin
```

### Using Scripts
With the scripts [artifactoryBenchmark.sh](artifactoryBenchmark.sh) and [artifactoryLoad.sh](artifactoryLoad.sh) you can create load on Artifactory.

Each script has its own usage you can get with
```shell
./<script.sh> --help
```

### Benchmark from a Pod
You can run this from within a pod in Kubernetes
```shell
# Deploy a pod with the needed tools
kubectl apply -f https://github.com/eldada/kubernetes-scripts/raw/master/yaml/podWithTools.yaml

# Open a shell to the pod
kubectl exec -it pod-with-tools --bash

# Clone the repository with the scripts
cd /opt
git clone https://github.com/eldada/command-examples.git

cd command-examples/artifactory

# Run the script(s) you want
# NOTE - use the internal artifactory service rather than the external load balancer
./artifactoryBenchmark.sh --help

```
