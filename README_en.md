# AirK8s Project

## I. Project (AirK8s) Statement

1. This project implements automated deployment of a specific version of a Kubernetes cluster in an offline environment.
2. Software Information: OS is openEuler-25.03, k8s version is v1.32.0, container runtime is containerd.
3. The script code (`k8s-auto-master.sh/k8s-auto-node01.sh/cgroups.sh/rename_all.sh`, etc., portions written by the author) is open-sourced under the "GPL v3" license.
4. Other materials involved in this project (third-party files, installation packages, operating systems, container images, etc.) are copyrighted by their respective owners and follow their respective open-source licenses.
5. Other materials involved in this project (third-party files, installation packages, operating systems, container images, etc.) are provided only for quick verification. The author makes no guarantees regarding their security, compliance, etc., and assumes no responsibility.
6. This project is intended for reference only during learning or testing. Users should conduct thorough testing and validation before use.
7. Contact the Author: aishu aishuc@126.com

## II. Usage Instructions

1. Download the AirK8s project.
2. Download the yum-server and docker-registry virtual machine images (VMware Workstation version 15.5 or higher). Link: https://pan.baidu.com/s/1qt9mEyJfPZeGVdLTWnQUgw?pwd=8891 Extraction code: 8891
3. Download the openEuler ISO image `openEuler-25.03-x86_64-dvd.iso`. Link: https://mirror.nyist.edu.cn/openeuler/openEuler-25.03/ISO/x86_64/openEuler-25.03-x86_64-dvd.iso

4. Set the network for the yum-server virtual machine to host-only.
5. Run yum-server. Password: root/root, user/user.
6. Set the IP for yum-server.
   ```
   #nmcli connection modify ens33 ipv4.method manual ipv4.address 192.168.229.132/24 ipv4.gateway 192.168.229.1 ipv4.dns 192.168.229.1
   #nmcli c up ens33
   ```
7. Mount the DVD.
   ```
   #mount /dev/sr0 /var/www/html/dvd
   ```
8. Run the docker-registry virtual machine. Password: root/root, user/user.
9. Set the IP for the docker-registry virtual machine.
10. Modify the docker-registry image name.
    ```
    [user@docker-registry ~]$ vi rename_all.sh
    ```
    Replace the value of `NEW_IP` with the actual IP.
    ```
    [user@docker-registry ~]$ ./rename_all.sh
    ```
11. Run the docker-registry container.
    ```
    [user@docker-registry ~]$ docker start $(docker ps -a -q)
    ```
12. Copy `openEuler-minimal` as the master virtual machine image. Set the virtual machine network to host-only.
13. Start the master node and set its IP.
14. Upload the scripts `cgroups.sh` and `k8s-auto-master.sh` to `/root`.
    ```
    [root@localhost ~]# chmod +x *.sh
    ```
15. Run the `cgroups.sh` script. The system will automatically restart.
16. Modify `k8s-auto-master.sh`.
    ```
    MASTER_NAME=master
    MASTER_IP=192.168.228.130
    MASTER_IP_MASK=24
    GATE_WAY=192.168.228.1
    DNS=192.168.228.1
    DOCKER_REGISTRY=192.168.228.128
    YUM_SERVER=192.168.228.129
    SOFT_SERVER=$YUM_SERVER
    NODE01_NAME=node01
    NODE01_IP=192.168.228.132
    ```
17. Run `k8s-auto-master.sh`.
    ```
    [root@master ~]# ./k8s-auto-master.sh
    User password: user
    For all [y/N]: Enter y
    ```
18. Verify.
    ```
    [root@localhost ~]# su - user
    [user@master ~]$ kubectl get pod -A
    ```
19. Copy `openEuler-minimal` as the node01 virtual machine image. Set the virtual machine network to host-only.
20. Start node01 and set its IP.
21. Upload the scripts `cgroups.sh` and `k8s-auto-node.sh` to `/root`.
    ```
    [root@localhost ~]# chmod +x *.sh
    ```
22. Run the `cgroups.sh` script. The system will automatically restart.
23. Modify `k8s-auto-node.sh`.
    ```
    NODE_NAME=node01
    NODE_IP=192.168.228.132
    NODE_IP_MASK=24
    GATE_WAY=192.168.228.1
    DNS=192.168.228.1
    DOCKER_REGISTRY=192.168.228.128
    YUM_SERVER=192.168.228.129
    SOFT_SERVER=$YUM_SERVER
    MASTER_IP=192.168.228.130
    ```
24. Run `k8s-auto-node.sh`.
    ```
    [root@localhost ~]# ./k8s-auto-node01.sh
    Password: The password for user 'user' is user, and for 'root' is root.
    For all [y/N]: Enter y
    ```
25. Verify.
    ```
    [root@localhost ~]# su - user
    [user@node01 ~]$ kubectl get pod -A
    [user@node01 ~]$ kubectl get node
    ```
