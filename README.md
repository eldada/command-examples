# Commands examples
This is a repository with a collection of various useful commands and examples for easy copy -> paste

# Table of contents
* [Git](#git)
* [Linux](#linux)
  * [Screen](#screen)
* [Docker](#docker)
* [Kubernetes](#kubernetes)
  * [Kubectl](#kubectl)
  * [Helm](#helm)
* [Other](#other)
  * [Artifactory in Kubernetes](#artifactory-in-kubernetes)
* [Contribute](#contribute)

## Git
* Rebasing a branch on master
```bash
# Update local copy of master
git checkout master
git pull

# Rebase the branch on the updated master
git checkout my-branch
git rebase master

# If problems are found, follow on screen instructions to resolve and complete the rebase.
```

* Resetting a fork with upstream. **WARNING:** This will override **any** local changes in your fork!
```bash
git remote add upstream /url/to/original/repo
git fetch upstream
git checkout master
git reset --hard upstream/master  
git push origin master --force 
```

* Add `Signed-off-by` line by the committer at the end of the commit log message.
```bash
git commit -s -m "Your commit message"
```

## Linux
* Clear memory cache
```bash
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

* Create self signed SSL key and certificate
```bash
mkdir -p certs/my_com
openssl req -nodes -x509 -newkey rsa:4096 -keyout certs/my_com/my_com.key -out certs/my_com/my_com.crt -days 356 -subj "/C=US/ST=California/L=SantaClara/O=IT/CN=localhost"
```

* Create binary files with random content
```bash
# Just one file (1mb)
$ dd if=/dev/urandom of=file bs=1024 count=1000

# Create 10 files of size ~10MB
for a in {0..9}; do \
  echo ${a}; \
  dd if=/dev/urandom of=file.${a} bs=10240 count=1024; \
done
```

* Test connection to remote `host:port` (check port being opened without using netcat or other tools)
```bash
# Check if port 8086 is open on remote
bash -c "</dev/tcp/remote/8080" 2>/dev/null
[ $? -eq 0 ] && echo "Port 8080 on host 'remote' is open"
```

* Suppress `Terminated` message from the `kill` on a background process by waiting for it with `wait` and directing the stderr output to `/dev/null`. This is from in this [stackoverflow answer](https://stackoverflow.com/a/5722874/1300730).
```bash
# Call the kill command
kill ${PID}
wait $! 2>/dev/null
```

### Screen
* Full source in this [gist](https://gist.github.com/jctosta/af918e1618682638aa82)
* `screen` [MacOS man page](https://ss64.com/osx/screen.html) and [bash man page](https://ss64.com/bash/screen.html)
* The `screen` command quick reference
```bash
# Start a new session with session name
screen -S <session_name>

# List running screens
screen -ls

# Attach to a running session
screen -x

# Attach to a running session with name
screen -r <session_name>

# Detach a running session
screen -d <session_name>
```

* Screen commands are prefixed by an escape key, by default Ctrl-a (that's Control-a, sometimes written ^a). To send a literal Ctrl-a to the programs in screen, use Ctrl-a a. This is useful when when working with screen within screen. For example Ctrl-a a n will move screen to a new window on the screen within screen. 

| Description             | Command                                 |
|-------------------------|-----------------------------------------|
| Exit and close session  | `Ctrl-d` or `exit`                      |
| Detach current session  | `Ctrl-a d`                              |
| Detach and logout (quick exit) | `Ctrl-a D D`                     |
| Kill current window     | `Ctrl-a k`                              |
| Exit screen             | `Ctrl-a :` quit or exit all of the programs in screen|
| Force-exit screen       | `Ctrl-a C-\` (not recommended)          |

* Help

| Description | Command                       |
|-------------|-------------------------------|
| See help    | `Ctrl-a ?` (Lists keybindings)|

## Docker
* Allow a user to run docker commands without sudo
```bash
sudo usermod -aG docker user
# IMPORTANT: Log out and back in after this change!
```

* See what Docker is using
```bash
docker system df
```

* Prune Docker unused resources
```bash
# Prune system
docker system prune

# Remove all unused Docker images
docker system prune -a

# Prune only parts
docker image/container/volume/network prune
```

* Remove dangling volumes
```bash
docker volume rm $(docker volume ls -f dangling=true -q)
```

* Quit an interactive session without closing it:
```
# Ctrl + p + q (order is important)
```

* Attach back to it
```bash
docker attach <container-id>
```

* Save a Docker image to be loaded in another computer
```bash
# Save
docker save -o ~/the.img the-image:tag

# Load into another Docker engine
docker load -i ~/the.img
```

* Connect to Docker VM on Mac
```bash
screen ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty
# Ctrl +A +D to exit
```

* Remove `none` images (usually leftover failed docker builds)
```bash
docker images | grep none | awk '{print $3}' | xargs docker rmi
```

* Using [dive](https://github.com/wagoodman/dive) to analyse a Docker image
```bash
# Must pull the image before analysis
docker pull redis:latest

# Run using dive Docker image
docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive:latest redis:latest
```

* Adding health checks for containers that check tcp port being opened without using netcat or other tools in your image
```bash
# Check if port 8086 is open
bash -c "</dev/tcp/localhost/8081" 2>/dev/null
[ $? -eq 0 ] && echo "Port 8081 on localhost is open"
```

## Kubernetes

### Kubectl
* Get cluster events
```bash
# All cluster
kubectl get events

# Specific namespace events
kubectl get events --namespace=kube-system
```

* Get all cluster nodes IPs and names
```bash
# Single call to K8s API
kubectl get nodes -o json | grep -A 12 addresses

# A loop for more flexibility
for n in $(kubectl get nodes -o name); do \
  echo -e "\nNode ${n}"; \
  kubectl get ${n} -o json | grep -A 8 addresses; \
done
```

* See all cluster nodes CPU and Memory requests and limits
```bash
# Option 1
kubectl describe nodes | grep -A 2 -e "^\\s*CPU Requests"

# Option 2 (condensed)
kubectl describe nodes | grep -A 2 -e "^\\s*CPU Requests" | grep -e "%"
``` 

* See all custer nodes load (top)
```bash
kubectl top nodes
```

* Get all labels attached to all pods in a namespace
```bash
for a in $(kubectl get pods -n namespace1 -o name); do \
  echo -e "\nPod ${a}"; \
  kubectl -n namespace1 describe ${a} | awk '/Labels:/,/Annotations/' | sed '/Annotations/d'; \
done
```

* Forward local port to a pod or service
```bash
# Forward localhost port 8080 to a specific pod exposing port 8080
kubectl port-forward -n namespace1 web 8080:8080

# Forward localhost port 8080 to a specific web service exposing port 80
kubectl port-forward -n namespace1 svc/web 8080:80
```

* A great tool for port forwarding all services in a namespace + adding aliases to `/etc/hosts` is [kubefwd](https://github.com/txn2/kubefwd)
```bash
# Port forward all service in namespace1
kubefwd svc -n namespace1
```

* Extract secret value
```bash
# Get the value of the postgresql password
kubectl get secret -n namespace1 my-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode
```


### Helm
* Helm on an RBAC enabled cluster. This will give tiller `cluster-admin` role
```bash
kubectl -n kube-system create sa tiller && \
    kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller && \
    helm init --service-account tiller
```

* Debug a `helm install`. Useful for seeing the actual values resolved by helm before deploying
```bash
helm install --debug --dry-run <chart>
```


## Other

### Artifactory in Kubernetes
Examples of commands to install Artifactory in K8s with various databases.

**NOTE:** If using a [Kubernetes cluster with RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) disabled, 
must pass `--set rbac.create=false` to all Artifactory `helm install/upgrade` commands.

#### Setup Helm repository 
Add JFrog's helm repository
```bash
helm repo add jfrog https://charts.jfrog.io
```

#### Default install
Install with Artifactory's default included database PostgreSQL
```bash
helm upgrade --install artifactory jfrog/artifactory 
```

#### With embedded Derby
Install with Artifactory's embedded database Derby
```bash
helm upgrade --install artifactory \
    --set postgresql.enabled=false jfrog/artifactory 
```

#### With external PostgreSQL
Install Artifactory with external PostgreSQL database in K8s
```bash
# Install PostgreSQL
helm upgrade --install postgresql \
    --set postgresUser=artifactory \
    --set postgresPassword=password1 \
    --set postgresDatabase=artifactory \
    stable/postgresql
    
# Install Artifactory (PostgreSQL driver already included in Docker image)
helm upgrade --install artifactory \
    --set postgresql.enabled=false \
    --set database.type=postgresql \
    --set database.user=artifactory \
    --set database.password=password1 \
    --set database.host=postgresql \
    jfrog/artifactory

# Install Artifactory (Using DB_URL)
helm upgrade --install artifactory \
    --set postgresql.enabled=false \
    --set database.type=postgresql \
    --set database.user=artifactory \
    --set database.password=password1 \
    --set database.url='jdbc:postgresql://postgresql:5432/artifactory' \
    jfrog/artifactory

```

#### With external MySQL
Install Artifactory with external MySQL database in K8s
```bash
# Install MySQL
helm upgrade --install mysql \
    --set mysqlRootPassword=rootPassword1 \
    --set mysqlUser=artifactory \
    --set mysqlPassword=password1 \
    --set mysqlDatabase=artdb \
     stable/mysql

# Install Artifactory (download mysql driver before starting server)
helm upgrade --install artifactory \
    --set postgresql.enabled=false \
    --set database.type=mysql \
    --set database.user=artifactory \
    --set database.password=password1 \
    --set database.host=mysql \
    --set artifactory.preStartCommand='curl -L -o /opt/jfrog/artifactory/tomcat/lib/mysql-connector-java-5.1.41.jar https://jcenter.bintray.com/mysql/mysql-connector-java/5.1.41/mysql-connector-java-5.1.41.jar' \
    jfrog/artifactory

# Install Artifactory (Using DB_URL)
helm upgrade --install artifactory \
    --set postgresql.enabled=false \
    --set database.type=mysql \
    --set database.user=artifactory \
    --set database.password=password1 \
    --set artifactory.preStartCommand='curl -L -o /opt/jfrog/artifactory/tomcat/lib/mysql-connector-java-5.1.41.jar https://jcenter.bintray.com/mysql/mysql-connector-java/5.1.41/mysql-connector-java-5.1.41.jar' \
    --set database.url='url=jdbc:mysql://mysql:3306/artdb?characterEncoding=UTF-8&elideSetAutoCommits=true' \
    jfrog/artifactory

```

### Prometheus Operator
See [prometheus-operator](prometheus-operator/prometheus-operator.md)

## Contribute
Contributing is more than welcome with a pull request
