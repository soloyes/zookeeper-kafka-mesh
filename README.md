* * * Features * * *
Used linux is Ubuntu 15.10.
Used bash for fast deploy.

Can skip follow steps and use attached ".vid" file. Import it to VirtualBox, and start the machine. Password is osboxes.org. 
Go to terminal, then cd infoBip. Use ./init.sh. Desc about init.sh is below steps to config Ubuntu.

* * * Steps to config Ubuntu 15.10 * * *
One possible way to test, is use VirtualBox with Ubuntu 15.10 image. 
	1) Install VirtualBox
	2) Use Ubuntu 15.10 image
	3) Install docker there (https://docs.docker.com/engine/installation/linux/ubuntulinux/)

In case of Ubuntu, we must manipulate with sudo rights. Here is one of possible way:
	1) sudo groupadd docker
	2) sudo usermod -aG docker $$yourUser$$
	3) restart your PC
Other case will have problems, coz script is not include any "sudo" insight.
Need to be sure docker command is not require "sudo".

Make exec all files:
	0) mkdir infoBip
	1) tar zxvf infoBip.tar.gz infoBip/
	2) chmod +x infoBip/*.sh

It operating with reconfigured images (improved by me): baseimage-zookeeper, baseimage-kafka. Both images has latest JRE+kafka/zookeeper software insight. Services are starting automatically when use init.sh.

To import containers we need to pull them into docker library.
	1) docker load < /infoBip/baseimage-zookeeper.tar
	2) docker load < /infoBip/baseimage-kafka.tar

* * * Steps to use init.sh * * *
Script init.sh checking docker process status. Start it if needed. May need the password to input for process start.
Script init.sh is create new network (if u already have others, it is OK, network name is any) from predefined ranges, just follow the instructions. Then it create new containers (if u already have others, it is OK) one-by-one belong to created network. Firstly we create zookeeper node, then we create kafka node. Script also can delete containers one-by-one, just follow the instructions. To delete and create we use init.sh.

Script assigns IP's automatically in sequence. Default GW is the first IP in the range (use by parent OS).

Every container starts ssh daemon itself. So, after ever container created, we can connect it. Just use ./SetPass.sh to set root password as "root" (will set password to every created container, not do on other containers). Then u can connect every server by ssh to check something (e.g cat /etc/hosts, grep log, ps -ef). For more comfortable we can use public-key, (add pub.id to docker image, then save image)

Now all systems are stable and every process working with each other. We can produce messages and consume it from any node we have.

Use Clear.sh to delete all configuration. It is fast way to have a test from begin.

* * * Limits and improvements * * *
Limit 1
Use bash - it is not very good solution for any production system, because we have limist to control container states, and so on (bash..BLA BLA). Better use java API directly.
Improvement 1:
Use Scala/Java/Pyton and so on.

Limit 2:
OS based
Improvement 2:
Possible to create different ways to operate with different OS's, but need exactly applicable task. So, Ubuntu is most popular OS.

Limit 3:
Add/delete procedures base only on restart process task (check log files, PID files then make some conclusion). It restart every process one-by-one, wait until it starts, then restart next one. It not care about load status, and it imposible to test when 1M messages come without test bed.
Improvement 3:
Use Scala/Java/Pyton and so on.
