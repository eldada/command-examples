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

# 10 concurrent downloads with a total of 1000 requests (basic auth)
ab -A admin:password -c 10 -n 1000 -k http://localhost/artifactory/example-repo-local/example-file.bin

# Using an access token instead of basic auth to download
ab -H "Authorization: Bearer ${TOKEN}" -c 10 -n 1000 -k http://localhost/artifactory/example-repo-local/example-file.bin
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
ab -A admin:password -u ./file.bin -c 1 -n 50 -k http://localhost/artifactory/example-repo-local/file.bin

# Use a token instead of basic auth to upload
ab -H "Authorization: Bearer ${TOKEN}" -u ./file.bin -c 1 -n 50 -k http://localhost/artifactory/example-repo-local/file.bin
```

#### Artifactory Load Helm Chart
You can use the [artifactory-load](helm/artifactory-load) helm chart to deploy one or more pods running `ab`, `wrk` or `hey` for a given time. You can run downloads, uploads, or both.

This chart support **up to**
1. 4 different downloads `ab`, `wrk` or `hey` scenarios at the same time (using multiple jobs). The default is a single job.
2. 2 different uploads (using `ab`) scenarios at the same time (using multiple jobs). The default is no upload job.

You can alter the chart and add support for more downloads or uploads scenarios if needed.

For downloads upload the files you want to use for the downloads testing. These should each be configured in its own jobX block. See example below that has 4 different scenarios with different sizes

For uploads, just enable and fill in the configuration block for the upload job(s) you want to run.

Create a `test-value.yaml` with the specific details of your run
```yaml
# Set the URL and credentials to access the Artifactory server to be tested
artifactory:
  url: http://artifactory-server
  auth: true
  user: admin
  password: password

## Multiple Jobs to run different download use cases at the same time
## Variables for each job:
#  tool:        The tool to use for the tests (ab, wrk or hey)
#  parallelism: How many pods to run in parallel per job
#  file:        File to download from Artifactory
#  timeSec:     How long to run the job in seconds
#  concurrency: How many threads to run in parallel per pod

# Run 2 pods with each pulling a 1KB file for 3 minutes (180 seconds)
job0:
  tool: "wrk"
  parallelism: 2
  file: example-repo-local/file1KB.bin
  timeSec: "180"
  concurrency: "2"

# Run 1 pod pulling a 10KB file for 5 minutes (300 seconds)
job1:
  tool: "wrk"
  parallelism: 1
  enabled: true
  file: example-repo-local/file10KB.bin
  timeSec: "300"
  concurrency: "2"

# Run 3 pods with each pulling a 100KB file for 10 minutes (600 seconds)
job2:
  tool: "wrk"
  parallelism: 3
  enabled: true
  file: example-repo-local/file100KB.bin
  timeSec: "600"
  concurrency: "3"

# Run 1 pod pulling a 10MB file for 10 minutes (600 seconds)
job3:
  tool: "wrk"
  parallelism: 1
  enabled: true
  file: example-repo-local/file10MB.bin
  timeSec: "600"
  concurrency: "1"

## Multiple Jobs to run different upload use cases at the same time
## Variables for each job:
#  parallelism: How many pods to run in parallel per job
#  repoPath:    Repository path to upload the file to (the file name will be unique per pod)
#  sizeKB:      Size of the file in KB
#  timeSec:     How long to run the job in seconds
#  concurrency: How many threads to run in parallel per pod

# Optional upload job 0
# Run 2 pods uploading a 10KB file for 10 minutes with 5 threads (users)
uploadJob0:
  enabled: true
  parallelism: 2
  repoPath: example-repo-local/uploads
  sizeKB: "10"
  timeSec: "600"
  concurrency: "5"

# Optional upload job 1
# Run 1 pod uploading a 1MB file for 10 minutes with 2 threads (users)
uploadJob1:
  enabled: true
  parallelism: 1
  repoPath: example-repo-local/uploads
  sizeKB: "1024"
  timeSec: "600"
  concurrency: "2"
```

Deploy the chart with the command
```shell
helm upgrade --install load . -f test-values.yaml
```

Uninstall the chart with the command
```shell
helm uninstall load
```

### Shell Scripts
* [artifactoryBenchmark.sh](artifactoryBenchmark.sh) - Run download, upload (or both) tests with a single file for a given size and iterations count. Results as CSV
* [artifactoryLoad.sh](artifactoryLoad.sh) - Run parallel processes of `artifactoryBenchmark.sh`. This is useful for generating load on Artifactory
* [artifactoryDownloadsLoop.sh](artifactoryDownloadsLoop.sh) - Create and upload a single generic binary generic file to Artifactory and download it in loops with set iterations and parallel threads

Each script has its own usage you can get with
```shell
./<script.sh> --help
```

### Benchmark From Within a Pod
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
