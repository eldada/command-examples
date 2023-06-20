# Commands example

This is a repository with a collection of useful commands, scripts and examples for easy copy -> paste

# Table of contents

* [Linux](#linux)
  * [Examples](#examples)
  * [The proc directory](#the-proc-directory)
  * [Screen](#screen)
  * [Sysbench](#sysbench)
  * [Apache Bench](#apache-bench)
  * [Load generator](#load-generator)
* [Git](#git)
* [Java](#java)
* [Docker](#docker)
  * [Tools](#tools)
  * [My Dockerfiles](#my-dockerfiles)
* [Artifactory](#artifactory)
* [Contribute](#contribute)

## Linux

### Examples

* Clear memory cache
```shell script
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

* Create a self-signed SSL key and certificate
```shell script
mkdir -p certs/my_com
openssl req -nodes -x509 -newkey rsa:4096 -keyout certs/my_com/my_com.key -out certs/my_com/my_com.crt -days 356 -subj "/C=US/ST=California/L=SantaClara/O=IT/CN=localhost"
```

* Create binary files with random content
```shell script
# Just one file (1mb)
dd if=/dev/urandom of=file bs=1024 count=1000

# Create 10 files of size ~10MB
for a in {0..9}; do \
  echo ${a}; \
  dd if=/dev/urandom of=file.${a} bs=10240 count=1024; \
done
```

* Test connection to remote `host:port` (check port being opened without using `netcat` or other tools)
```shell script
# Check if port 8080 is open on remote
bash -c "</dev/tcp/remote/8080" 2>/dev/null
[ $? -eq 0 ] && echo "Port 8080 on host 'remote' is open"
```

* Suppress `Terminated` message from the `kill` on a background process by waiting for it with `wait` and directing the stderr output to `/dev/null`. This is from in this [stackoverflow answer](https://stackoverflow.com/a/5722874/1300730).
```shell script
# Call the kill command
kill ${PID}
wait $! 2>/dev/null
```

* **curl** variables<br>
The `curl` command has the ability to provide a lot of information about the transfer. See [curl man page](https://curl.haxx.se/docs/manpage.html).<br>
Search for `--write-out`.<br>
See all supported variables in [curl.format.txt](files/curl.format.txt)
```shell script
# Example for getting http response code (variable http_code)
curl -o /dev/null -s --write-out '%{http_code}' https://curl.haxx.se

# Example for one-liner printout of several connection time parameters
curl -w "\ndnslookup: %{time_namelookup} \nconnect: %{time_connect} \nappconnect: %{time_appconnect} \npretransfer: %{time_pretransfer} \nredirect: %{time_redirect} \nstarttransfer: %{time_starttransfer} \n---------\ntotal: %{time_total} \nsize: %{size_download}\n" \
        -so /dev/null https://curl.haxx.se
        
# Example for printing all variables and their values by using an external file with the format
curl -o /dev/null -s --write-out '@files/curl.format.txt' https://curl.haxx.se
```

* Single binary `curl`
```shell script
# Get the archive, extract (notice the xjf parameter to tar) and copy.
wget -O curl.tar.bz2 http://www.magicermine.com/demos/curl/curl/curl-7.30.0.ermine.tar.bz2 && \
    tar xjf curl.tar.bz2 && \
    cp curl-7.30.0.ermine/curl.ermine curl && \
    ./curl --help
```

* Single static binaries
Taken from this cool [static-binaries](https://github.com/yunchih/static-binaries/) repository
```shell script
# tcpdump
curl -O https://raw.githubusercontent.com/yunchih/static-binaries/master/tcpdump
```
* Single static binary `vi`
```shell script
# vi (vim)
curl -OL https://eldada.jfrog.io/artifactory/tools/x86_64/vi.tar.gz
```

* Single static binary `jq` (Linux). Look in https://stedolan.github.io/jq/download/ for additional flavors
```shell script
# jq
curl -OL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
```

* Get **http code** using **wget** (without **curl**)<br>
In cases where **curl** is not available, use **wget** to get the http code returned from an HTTP endpoint
```shell script
wget --spider -S -T 2 www.jfrog.org 2>&1 | grep "^  HTTP/" | awk '{print $2}' | tail -1
```

* Poor man's `top` shell scripts (in Linux only!). Good for when `top` is not installed<br>
Get CPU and memory usage by processes on the current host. Also useful in Linux based Docker containers<br>
  * Using data from `/proc` [top.sh script](scripts/top.sh)<br> 
  * Using data from `ps -eo` [top-ps.sh script](scripts/top-ps.sh)

* Process info (in Linux only!)<br>
To get process info using its PID or search string: Command line, environment variables. Use [procInfo.sh](scripts/procInfo.sh).

* Add file to WAR file [addFileToWar.sh](scripts/addFileToWar.sh)

### The proc directory

The `/proc` file system has all the information about the running processes. See full description in the [proc man page](https://man7.org/linux/man-pages/man5/proc.5.html).

* Get a process command line (see usage in [procInfo.sh](scripts/procInfo.sh))
```shell script
# Assume PID is the process ID you are looking at
cat /proc/${PID}/cmdline | tr '\0' ' '
```

* Get a process environment variables (see usage in [procInfo.sh](scripts/procInfo.sh))
```shell script
# Assume PID is the process ID you are looking at
cat /proc/${PID}/environ | tr '\0' '\n'
```

* Get load average from disk instead of command
```shell script
cat /proc/loadavg | awk '{print $1 ", " $2 ", " $3}'
```

* Get top 10 processes IDs and names sorted with highest time waiting for disk IO (Aggregated block I/O delays, measured in clock ticks)
```shell script
cut -d" " -f 1,2,42 /proc/[0-9]*/stat | sort -n -k 3 | tail -10
```

### Screen

* Full source in this [gist](https://gist.github.com/jctosta/af918e1618682638aa82)
* `screen` [MacOS man page](https://ss64.com/osx/screen.html) and [bash man page](https://ss64.com/bash/screen.html)
* The `screen` command quick reference
```shell script
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

### Sysbench

**Sysbench** is a mutli-purpose benchmark that features tests for CPU, memory, I/O, and even database performance testing.<br>
See full content for this section in [linuxconfig.org's how to benchmark your linux system](https://linuxconfig.org/how-to-benchmark-your-linux-system#h7-sysbench).

* Installation (Debian/Ubuntu)
```shell script
sudo apt install sysbench
```
* CPU benchmark
```shell script
sysbench --test=cpu run
```
* Memory benchmark
```shell script
sysbench --test=memory run
```
* I/O benchmark
```shell script
sysbench --test=fileio --file-test-mode=seqwr run
```

### Apache Bench

From the [Apache HTTP server benchmarking tool](http://httpd.apache.org/docs/2.4/programs/ab.html) page: "`ab` is a tool for benchmarking your Apache Hypertext Transfer Protocol (HTTP) server."

```shell script
# A simple benchmarking of a web server. Running 100 requests with up to 10 concurrent requests
ab -n 100 -c 10 http://www.jfrog.com/
```

### Load generator

A simple [createLoad.sh](scripts/createLoad.sh) script to create disk IO and CPU load in the current environment. This script just creates and deletes files in a temp directory which strains the CPU and disk IO.<br>
**WARNING:** Running this script with many threads can bring a system to a halt or even crash it. USE WITH CARE!
```shell script
./createLoad.sh --threads 10
```

## Git

* Rebasing a branch on master
```shell script
# Update local copy of master
git checkout master
git pull

# Rebase the branch on the updated master
git checkout my-branch
git rebase master

# Rebase and squash
git rebase master -i

# If problems are found, follow on screen instructions to resolve and complete the rebase.
```

* Resetting a fork with upstream. **WARNING:** This will override **any** local changes in your fork!
```shell script
git remote add upstream /url/to/original/repo
git fetch upstream
git checkout master
git reset --hard upstream/master  
git push origin master --force 
```

* Add `Signed-off-by` line by the committer at the end of the commit log message.
```shell script
git commit -s -m "Your commit message"
```

## Java

Some useful commands for debugging a `java` process
```shell script
# Go to the java/bin directory
cd ${JAVA_HOME}/bin

# Get your java process id
PID=$(ps -ef | grep java | grep -v grep | awk '{print $2}')

# Get JVM native memory usage
# For this, you need your java process to run with the the -XX:NativeMemoryTracking=summary parameter
./jcmd ${PID} VM.native_memory summary

# Get all JVM info
./jinfo ${PID}

# Get JVM flags for a java process
./jinfo -flags ${PID}

# Get JVM heap info 
./jcmd ${PID} GC.heap_info

# Get JVM Metaspace info
./jcmd ${PID} VM.metaspace

# Trigger a full GC
./jcmd ${PID} GC.run

# Java heap memory histogram
./jmap -histo ${PID}
 
```

## Docker

* Allow a user to run docker commands without sudo
```shell script
sudo usermod -aG docker user
# IMPORTANT: Log out and back in after this change!
```

* See what Docker is using
```shell script
docker system df
```

* Prune Docker unused resources
```shell script
# Prune system
docker system prune

# Remove all unused Docker images
docker system prune -a

# Prune only parts
docker image/container/volume/network prune
```

* Remove dangling volumes
```shell script
docker volume rm $(docker volume ls -f dangling=true -q)
```

* Quit an interactive session without closing it:
```
# Ctrl + p + q (order is important)
```

* Attach back to it
```shell script
docker attach <container-id>
```

* Save a Docker image to be loaded in another computer
```shell script
# Save
docker save -o ~/the.img the-image:tag

# Load into another Docker engine
docker load -i ~/the.img
```

* Connect to Docker VM on Mac
```shell script
screen ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty
# Ctrl +A +D to exit
```

* Remove `none` images (usually leftover failed docker builds)
```shell script
docker images | grep none | awk '{print $3}' | xargs docker rmi
```

* Using [dive](https://github.com/wagoodman/dive) to analyse a Docker image
```shell script
# Must pull the image before analysis
docker pull redis:latest

# Run using dive Docker image
docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive:latest redis:latest
```

* Adding health checks for containers that check tcp port being opened without using netcat or other tools in your image
```shell script
# Check if port 8081 is open
bash -c "</dev/tcp/localhost/8081" 2>/dev/null
[ $? -eq 0 ] && echo "Port 8081 on localhost is open"
```

### Tools

A collection of useful Docker tools
* A simple terminal UI for Docker and docker-compose: [lazydocker](https://github.com/jesseduffield/lazydocker)
* A web based UI for local and remote Docker: [Portainer](https://www.portainer.io/)
* Analyse a Docker image with [dive](https://github.com/wagoodman/dive)

### My Dockerfiles

A few `Dockerfile`s I use in my work
* An Ubuntu with added tools and no root: [Dockerfile-ubuntu-with-tools](Dockerfiles/Dockerfile-ubuntu-with-tools)
```shell
# For a local build
docker build -f Dockerfile-ubuntu-with-tools -t eldada.jfrog.io/docker/ubuntu-with-tools:22.10 .

# Multi arch build and push
docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile-ubuntu-with-tools -t eldada.jfrog.io/docker/ubuntu-with-tools:22.10 --push

```

## Artifactory

See Artifactory related scripts and examples in [artifactory](artifactory)

## Contribute

Contributing is more than welcome with a pull request
