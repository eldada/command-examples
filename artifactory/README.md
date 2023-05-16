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
Install with Artifactory's default included database PostgreSQL
```shell
helm upgrade --install artifactory jfrog/artifactory 
```

#### With embedded Derby
Install with Artifactory's embedded database Derby
```shell
helm upgrade --install artifactory jfrog/artifactory -f values-examples/values-derby.yaml 
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
