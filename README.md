# Commands examples
This is a repository with a collection of various useful commands and examples I collected through times in various topics

# Table of contents
* [Linux](#linux)
* [Docker](#docker)
* [Kubernetes](#kubernetes)
  * [Kubectl](#kubectl)
  * [Helm](#helm)
* [Other](#other)
* [Contribute](#contribute)


## Linux
Clear memory cache
```bash
$ sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

Create self signed SSL key and certificate
```bash
$ mkdir -p certs/my_com
$ openssl req -nodes -x509 -newkey rsa:4096 -keyout certs/my_com/my_com.key -out certs/my_com/my_com.crt -days 356 -subj "/C=US/ST=California/L=SantaClara/O=IT/CN=localhost"
```

Create binary files with random content
```bash
# Just one file (1mb)
$ dd if=/dev/urandom of=file bs=1024 count=1000

# Create 10 files of size ~10MB
$ for a in {0..9}; do \
    echo ${a}; \
    dd if=/dev/urandom of=file.${a} bs=10240 count=1024; \
  done
```


## Docker
Allow a user to run docker commands without sudo
```bash
sudo usermod -aG docker user
# IMPORTANT: Log out and back in after this change!
```

See what Docker is using
```bash
$ docker system df
```

Prune Docker unused resources
```bash
# Prune system
$ docker system prune

# Remove all unused Docker images
$ docker system prune -a

# Prune only parts
$ docker image/container/volume/network prune
```

Remove dangling volumes
```bash
$ docker volume rm $(docker volume ls -f dangling=true -q)
```

Quit an interactive session without closing it:
```
# Ctrl + p + q (order is important)
```

Attach back to it
```bash
$ docker attach <container-id>
```

Save a Docker image to be loaded in another computer
```bash
# Save
$ docker save -o ~/the.img the-image:tag

# Load into another Docker engine
docker load -i ~/the.img
```

Connect to Docker VM on Mac
```bash
$ screen ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty
# Ctrl +A +D to exit
```

Remove `none` images (usually leftover failed docker builds)
```bash
$ docker images | grep none | awk '{print $3}' | xargs docker rmi
```

## Kubernetes

### Kubectl

Get cluster events
```bash
# All cluster
$ kubectl get events

# Specific namespace events
$ kubectl get events --namespace=kube-system
```

Get all cluster nodes IPs and names
```bash
# Single call to K8s API
$ kubectl get nodes -o json | grep -A 12 addresses

# A loop for more flexibility
$ for n in $(kubectl get nodes -o name); do \
    echo -e "\nNode ${n}"; \
    kubectl get ${n} -o json | grep -A 8 addresses; \
  done
```

See all cluster nodes CPU and Memory requests and limits
```bash
# Option 1
$ kubectl describe nodes | grep -A 2 -e "^\\s*CPU Requests"

# Option 2 (condensed)
$ kubectl describe nodes | grep -A 2 -e "^\\s*CPU Requests" | grep -e "%"
``` 

See all custer nodes load (top)
```bash
$ kubectl top nodes
```

Get all labels attached to all pods in a namespace
```bash
$ export NS=your-namespace
$ for a in $(kubectl get pods -n jfmctests -o name); do \
    echo -e "\nPod ${a}"; \
    kubectl -n jfmctests describe ${a} | awk '/Labels:/,/Annotations/' | sed '/Annotations/d'; \
  done
```

### Helm

Helm on an RBAC enabled cluster. This will give tiller `cluster-admin` role
```bash
$ kubectl -n kube-system create sa tiller && \
    kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller && \
    helm init --service-account tiller
```

Debug a `helm install`. Useful for seeing the actual values resolved by helm before deploying
```bash
$ helm install --debug --dry-run <chart>
```


## Other


## Contribute
Contributing is more than welcome with a pull request
