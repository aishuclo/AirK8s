# AirK8s Project

## I. Project (AirK8s) Declaration

1. This project implements automated deployment of a specific version of Kubernetes cluster in an offline environment.
2. Features: ultra-lightweight, pure scripts, no pre-installation or other dependencies, no system pollution, fully controllable, highly customizable.
3. Software info: OS: openEuler-25.03, k8s version: v1.32.0, container runtime: containerd.
4. The script code (`k8s-auto-master.sh` / `k8s-auto-node01.sh` / `cgroups.sh` / `create_server.sh`, etc., parts written by the author) is open-sourced under the **GPL v3** license.
5. Any other materials involved in this project, if copyrighted, belong to their respective owners and follow their own open-source licenses.
6. This project is for learning purposes only. Users should fully evaluate it before use. The author provides no warranty and assumes no liability.
7. Contact the author: Uncle Ai (aishuc@126.com).

## II. Usage Instructions

1. Download the AirK8s project.
2. Download the openEuler ISO image `openEuler-25.03-x86_64-dvd.iso` from:  
   https://mirror.nyist.edu.cn/openeuler/openEuler-25.03/ISO/x86_64/openEuler-25.03-x86_64-dvd.iso
3. Perform a minimal installation of openEuler for `air-k8s-server`. Password: root/root, user/user.
4. Ensure `air-k8s-server`: ① has internet access; ② has the ISO file attached/mounted.
5. Run the `create_server.sh` script on `air-k8s-server`:  
   `[root@localhost ~]# ./create_server.sh`
6. Disconnect `air-k8s-server` from the external network and connect it to the internal network (ensure no internet access).
7. Start the registry container on `air-k8s-server`.
8. Perform a minimal installation of openEuler for the k8s master. Upload `cgroups.sh` and `k8s-auto-master.sh` to the master.
9. Configure the master's IP address.
10. Run the `cgroups.sh` script; the system will automatically reboot.
11. Modify `k8s-auto-master.sh` on the master according to your plan. Example:  
    ```
    MASTER_NAME=master
    MASTER_IP=192.168.228.130
    MASTER_IP_MASK=24
    GATE_WAY=192.168.228.1
    DNS=192.168.228.1
    AIR_K8S_SERVER=192.168.228.134
    NODE01_NAME=node01
    NODE01_IP=192.168.228.131
    ```
12. After the master reboots, run `k8s-auto-master.sh`:  
    `[root@master ~]# ./k8s-auto-master.sh`  
    User password: user  
    All [y/N]: enter y
13. Verification:  
    `[root@localhost ~]# su - user`  
    `[user@master ~]$ kubectl get pod -A`
14. Perform a minimal installation of openEuler for k8s node01. Upload `cgroups.sh` and `k8s-auto-node01.sh` to node01.
15. Configure node01's IP address.
16. Run `cgroups.sh`; the system will automatically reboot.
17. Modify `k8s-auto-node01.sh` on the master according to your plan. Example:  
    ```
    MASTER_NAME=master
    MASTER_IP=192.168.228.130
    MASTER_IP_MASK=24
    GATE_WAY=192.168.228.1
    DNS=192.168.228.1
    AIR_K8S_SERVER=192.168.228.134
    NODE01_NAME=node01
    NODE01_IP=192.168.228.131
    ```
18. After the master reboots, run `k8s-auto-node01.sh`:  
    `[root@master ~]# ./k8s-auto-node01.sh`  
    user password: user  
    root password: root  
    All [y/N]: enter y
19. Verification:  
    `$ kubectl get pod -A`
