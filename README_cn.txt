一、项目（AirK8s）声明
	1、本项目实现离线环境下特定版本的Kubernetes 集群的自动部署。
	2、项目特点：超轻量级、纯脚本，无预装和其它依赖，无系统污染、全程可控，支持高度定制
	3、软件信息：OS：openEuler-25.03、k8s版本：v1.32.0、容器运行时：containerd。
	4、脚本代码（`k8s-auto-master.sh/k8s-auto-node01.sh/cgroups.sh/create_server.sh` 等由作者编写的部分）采用 “GPL v3” 协议开源。
	5、本项目涉及的其它资料如有版权的话，其版权归各自所有者所有，遵循各自的开源许可证。
	6、本项目仅供学习用，用户使用前应自行进行充分评估、作者不作任何保证也不承担任何责任。
	7、联系作者：艾叔（aishuc@126.com）。

二、使用说明
	1、下载AirK8s项目
	2、下载openEuler ISO镜像openEuler-25.03-x86_64-dvd.iso，链接地址：https://mirror.nyist.edu.cn/openeuler/openEuler-25.03/ISO/x86_64/openEuler-25.03-x86_64-dvd.iso
	3、最小化安装openEuler，用于air-k8s-server，密码：root/root，user/user
	4、确保air-k8s-server：1、能够上网；2、已经关联ISO文件	
	5、在air-k8s-server上运行create_server.sh脚本
	[root@localhost ~]# ./create_server.sh	
	6、将air-k8s-server断开外网，连接到内网，确保不能够上网
	7、启动air-k8s-server的registry容器：$docker start $(docker ps -a -q)

	8、最小化安装openEuler，用于k8s的master，上传cgroups.sh k8s-auto-master.sh到master
	9、配置master的IP
	10、运行脚本cgroups.sh，系统将自动重启
	11、根据规划情况在master中修改k8s-auto-master.sh，示例如下
	MASTER_NAME=master
	MASTER_IP=192.168.228.130
	MASTER_IP_MASK=24
	GATE_WAY=192.168.228.1
	DNS=192.168.228.1
	AIR_K8S_SERVER=192.168.228.134
	NODE01_NAME=node01
	NODE01_IP=192.168.228.131
	
	12、master重启后，运行k8s-auto-master.sh
		[root@master ~]# ./k8s-auto-master.sh
		用户密码：user
		所有[y/N]：输入y
	13、验证
		[root@localhost ~]# su - user
		[user@master ~]$ kubectl get pod -A
	
	14、最小化安装openEuler，用于k8s的node01，上传cgroups.sh k8s-auto-node01.sh到node01
	15、配置node01的IP
	16、运行脚本cgroups.sh，系统将自动重启
	17、根据规划情况在node01中修改k8s-auto-node01.sh，示例如下
	MASTER_NAME=master
	MASTER_IP=192.168.228.130
	MASTER_IP_MASK=24
	GATE_WAY=192.168.228.1
	DNS=192.168.228.1
	AIR_K8S_SERVER=192.168.228.134
	NODE01_NAME=node01
	NODE01_IP=192.168.228.131
	
	18、node01重启后，运行k8s-auto-node01.sh
		[root@node01 ~]# ./k8s-auto-node01.sh
		user密码：user
		root密码：root
		所有[y/N]：输入y
	19、验证
		$ kubectl get pod -A
