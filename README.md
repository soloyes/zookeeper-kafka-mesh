#### Using Docker create any number of zookeeper and kafka containers without service interruption. Bash user-friendly control menu. 

Righit now it is tested only on Ubuntu.
In case of **Ubuntu**, we must manipulate with sudo rights for docker. Here is one of possible way:

	1. sudo groupadd docker
	2. sudo usermod -aG docker $$yourUser$$
	3. restart your PC

Other case will have problems, coz script is not apply to "sudo".
Need to be sure docker is not required for "sudo".

Make exec all files:

	1. chmod +x *.sh

It operating with images based on Dockerfile: baseimage-zookeeper, baseimage-kafka.
Both images will install JRE+kafka/zookeeper/wget software insight.

Before the start, build images manually:

docker build -t baseimage-zookeeper -f DockerfileZ .

docker build -t baseimage-kafka -f DockerfileK . 

**Steps to use init.sh**

Script ./init.sh is checking docker process status. Start it if needed. May need the password for process start.
Script ./init.sh is creating new network (if u already have others, it is OK, network name may be any: numbers, letters, symbols) from predefined IP ranges, just follow the instructions. Then it create new containers (no problem if already have others belong to other network) one-by-one belong to created network. Firstly it create zookeeper node, then we optionally create kafka/zookeeper node. Script also can delete containers one-by-one, just follow the instructions. To delete and create use ./init.sh also.

Script assigns IP's automatically in sequence. Default GW is the first IP in the range (use by parent OS).

Every container starts ssh daemon itself. So, after ever container created, we can connect it.
Just use ./SetPass.sh to set root user password as "root" (will set password for every created container belongs to created network, not implement on other containers). Then u can connect any server by ssh ***root@IP*** to check something (e.g cat /etc/hosts, grep log, ps -ef). For more comfortable way we can use public-key (add pub.id to docker image, then save image).

Use ./Clear.sh to delete all created configuration (containers, relate files). It is fast way to have a test from very begin.

**Limits and improvements**

Limit 1:
Add/delete procedures base only on restart process insight the container (parse log files, PID files then make some conclusion). It restart every process one-by-one, wait until it starts, then restart next one. When any container restart failed, procedure will rollback to previous state.
