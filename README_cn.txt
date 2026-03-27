一、项目（AirK8s）声明
	1、本项目实现离线环境下特定版本的Kubernetes 集群的自动部署
	2、软件信息：OS为openEuler-25.03、k8s版本为v1.32.0、容器运行时为containerd。
	3、脚本代码（`k8s-auto-master.sh/k8s-auto-node01.sh/cgroups.sh/rename_all.sh` 等由作者编写的部分）采用 “GPL v3” 协议开源。
	4、本项目涉及的其它资料等（第三方文件、安装包、操作系统、容器镜像等），其版权归各自所有者所有，遵循各自的开源许可证。
	5、本项目涉及的其它资料等（第三方文件、安装包、操作系统、容器镜像等）仅用于快速验证，作者不对它们的安全性、合规性等作任何保证，也不承担任何责任。
	6、本项目仅供学习或测试时参考用。用户使用前应自行进行充分测试和验证。
	7、联系作者：艾叔（aishuc@126.com）

二、使用说明
	1、下载AirK8s项目
	2、下载yum-server和docker-registry虚拟机镜像（vmware workstation 15.5版本以上），链接地址：https://pan.baidu.com/s/1qt9mEyJfPZeGVdLTWnQUgw?pwd=8891 提取码: 8891 
	3、下载openEuler ISO镜像openEuler-25.03-x86_64-dvd.iso，链接地址：https://mirror.nyist.edu.cn/openeuler/openEuler-25.03/ISO/x86_64/openEuler-25.03-x86_64-dvd.iso
	
	4、设置yum-server虚拟机网络为host-only
	5、运行yum-server，密码：root/root，user/user
	6、设置yum-server的IP
		#nmcli connection modify ens33 ipv4.method manual ipv4.address 192.168.229.132/24  ipv4.gateway 192.168.229.1 ipv4.dns 192.168.229.1
nmcli c up ens33
	7、挂载dvd
		#mount /dev/sr0 /var/www/html/dvd

	8、运行docker-registry虚拟机，密码：root/root，user/user
	9、设置docker-registry虚拟机IP
	10、修改docker-registry镜像名称
		[user@docker-registry ~]$vi rename_all.sh
		将NEW_IP的值替换为真实IP的值
		[user@docker-registry ~]$./rename_all.sh
	11、运行docker-registry容器
		[user@docker-registry ~]$ docker start $(docker ps -a -q)

	12、复制openEuler-minimal为master虚拟机镜像，设置虚拟机网络为host-only
	13、启动master，设置IP
	14、上传脚本cgroups.sh/k8s-auto-master.sh到/root
		[root@localhost ~]# chmod +x *.sh
	15、运行脚本cgroups.sh，系统将自动重启
	16、修改k8s-auto-master.sh
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
	17、运行k8s-auto-master.sh
		[root@master ~]# ./k8s-auto-master.sh
		用户密码：user
		所有[y/N]：输入y
	18、验证
		[root@localhost ~]# su - user
		[user@master ~]$ kubectl get pod -A

	19、复制openEuler-minimal为node01虚拟机镜像，设置虚拟机网络为host-only
	20、启动node01，设置IP
	21、上传脚本cgroups.sh/k8s-auto-node.sh到/root
		[root@localhost ~]# chmod +x *.sh
	22、运行脚本cgroups.sh，系统将自动重启
	23、修改k8s-auto-node.sh
		NODE_NAME=node01
		NODE_IP=192.168.228.132
		NODE_IP_MASK=24
		GATE_WAY=192.168.228.1
		DNS=192.168.228.1
		DOCKER_REGISTRY=192.168.228.128
		YUM_SERVER=192.168.228.129
		SOFT_SERVER=$YUM_SERVER
		MASTER_IP=192.168.228.130
	24、运行k8s-auto-node.sh
		[root@localhost ~]# ./k8s-auto-node01.sh
		密码：user用户的密码为user，root用户的密码为root
		所有[y/N]：输入y	
	25、验证
		[root@localhost ~]# su - user
		[user@node01 ~]$ kubectl get pod -A
		[user@node01 ~]$ kubectl get node