[TOC]
### 一、架构描述与应用
#### 1. 应用场景
    大多数的互联网公司都会利用nginx的7层反向代理功能来实现后端web server的负载均衡和动静分离。这样做的好处是当单台后端server出现性能瓶颈时可以对其进行横向扩展从而提高整个系统的并发，同时也可以通过后端server提供的http或tcp监控接口对其进行健康检查实现自动Failover和Failback。
    在nginx给我们带来诸多好处的同时，自身却成为了整套系统的单点所在，试想一下nginx如果宕机了（虽然可能性不大），整个系统将会无法访问，由此可见对nginx server进行高可用的必要性。常见的高可用解决方案有heartbeat、keepalived等，其中以keepalived的实现最为轻量级、配置简单，所以在对nginx的高可用实现中更多会采用keepalived，下面主要也是以keepalived为例讲解。
#### 2. 架构说明


    上面的架构图中，nginx采用了主主模型，相对主备模型来说，能够更充分的利用服务器资源，原因是主备模式下，仅有一台nginx server可以对外提供服务，备用的nginx server仅会在主nginx server不可用时才会提升为主nginx server对外提供服务；主主模型还可以利用dns的解析一定程度上实现nginx本身的负载均衡，客户端访问网站的流程如下：
    1）client向dns server请求解析www.xxx.com的ip
    2）dns server根据其内部的轮询算法返回vip1或vip2，假设本次请求返回client的是vip2
    3）client与vip2建立tcp连接，然后完成后续的http请求
 
### 二、实验环境和配置功能介绍
#### 1. 服务器规划
系统使用CentOS7.2
服务角色	IP地址	软件版本
nginx lb1	192.168.124.71	1.10.1
nginx lb2
192.168.124.72
1.10.1
keepalived1	192.168.124.71
1.2.13
keepalived2
192.168.124.72
1.2.13
#### 2. 配置说明：
keepalived1:
```
### /etc/keepalived/keepalived.conf###
! Configuration File for keepalived

global_defs {               #全局配置段
    router_id host1        #物理路由id，一般指定为本机的hostname 
}

vrrp_script chkfile {         #服务状态检测脚本配置段
    script "[[ -f /etc/keepalived/down ]] && exit 1 || exit 0"         #通过周期性检测down文件是否存在来控制keepalived服务的主备切换
    interval 1     #指定检测间隔为1秒
    weight -2     #指定检测失败时，优先级减2；检测的成功或失败是由script后面指定的命令或脚本执行返回的状态码决定的，0表示成功，非0表示失败
}

vrrp_script chkngx {
    script "/etc/keepalived/chkngx.sh"        #指定用于检测nginx服务的执行脚本路径
    interval 1         #监测间隔
    weight -2        #失败时，优先级减2
    fall 3             # 指定nginx检测脚本连续执行失败次数为3，才进行Failover
    rise 3           # 指定nginx检测脚本连续执行成功次数为3，才进行Failback
}

vrrp_instance VI_1 {                #vrrp实例配置段
    state MASTER                      # 指定keepalived服务的其实状态
    interface eno16777736        # 指定keepalived的心跳口
    virtual_router_id 51               # 指定虚拟路由id（1~255），同一vrrp实例的主备keepalived必须配置为一样
    priority 100              #指定起始优先级，优先级高的会成为master
    advert_int 1             #vrrp通告的发送间隔
    authentication {                    #配置通过密码认证
        auth_type PASS
        auth_pass 8SSmX60hJr
    }
    track_interface {                         #配置检测的端口
        eno16777736 weight -2        #监控端口的up/down状态，来控制keepalived的主备切换
    }
    track_script {
        chkfile                   #通过指定上面定义监控脚本来监控服务状态，以完成主备切换
    }
    track_script {
        chkngx                 #通过指定上面定义监控脚本来监控服务状态，以完成主备切换
    }
    virtual_ipaddress {
        192.168.124.251/24 dev eno16777736 label vip1           #指定vip
    }
    notify_master "/etc/keepalived/notify.sh master"        #状态变为master时，触发的通知脚本
    notify_backup "/etc/keepalived/notify.sh backup"      #状态变为backup时，触发的通知脚本
    notify_fault "/etc/keepalived/notify.sh fault"                #状态变为fault时，触发的通知脚本
    notify "/etc/keepalived/notify.sh"    #当发生所有的状态改变时，会先触发对应的状态通知脚本后，再触发该脚本
}

vrrp_instance VI_2 {
    state BACKUP
    interface eno16777736
    virtual_router_id 52
    priority 99
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 9SSmX60hJr
    }
    track_interface {
        eno16777736 weight -2
    }
    track_script {
        chkfile        
    }
    track_script {
        chkngx        
    }
    virtual_ipaddress {
        192.168.124.252/24 dev eno16777736 label vip2
    }
    notify_master "/etc/keepalived/notify.sh master"
    notify_backup "/etc/keepalived/notify.sh backup"
    notify_fault "/etc/keepalived/notify.sh fault"
    notify "/etc/keepalived/notify.sh"
}
```
keepalived2:
```
### /etc/keepalived/keepalived.conf###
! Configuration File for keepalived

global_defs {
    router_id host2
}

vrrp_script chkfile {
    script "[[ -f /etc/keepalived/down ]] && exit 1 || exit 0"
    interval 1    
    weight -2
}

vrrp_script chkngx {
    script "/etc/keepalived/chkngx.sh"
    interval 1
    weight -2
    fall 3
    rise 3
}

vrrp_instance VI_1 {
    state BACKUP
    interface eno16777736
    virtual_router_id 51
    priority 99
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 8SSmX60hJr
    }
    track_interface {
        eno16777736 weight -2
    }
    track_script {
        chkfile
    }
    track_script {
        chkngx
    }
    virtual_ipaddress {
        192.168.124.251/24 dev eno16777736 label vip1
    }
    notify_master "/etc/keepalived/notify.sh master"
    notify_backup "/etc/keepalived/notify.sh backup"
    notify_fault "/etc/keepalived/notify.sh fault"
    notify "/etc/keepalived/notify.sh"
}

vrrp_instance VI_2 {
    state MASTER
    interface eno16777736
    virtual_router_id 52
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 9SSmX60hJr
    }
    track_interface {
        eno16777736 weight -2
    }
    track_script {
        chkfile
    }
    track_script {
        chkngx
    }
    virtual_ipaddress {
        192.168.124.252/24 dev eno16777736 label vip2
    }
    notify_master "/etc/keepalived/notify.sh master"
    notify_backup "/etc/keepalived/notify.sh backup"
    notify_fault "/etc/keepalived/notify.sh fault"
    notify "/etc/keepalived/notify.sh"
}
```
其他监控或通知脚本：
/etc/keepalived/notify.sh
```
###/etc/keepalived/notify.sh###
#!/bin/bash
#

declare -a vips=(192.168.124.251 192.168.124.252)
from=ops@xxx.com
to=admin@xxx.com
user=ops@xxx.com
pwd=mypassword

notify() {
    #$1: A string indicating whether it's a "GROUP" or an "INSTANCE"
    #$2: The name of said group or instance
    #$3: The state it's transitioning to ("MASTER", "BACKUP" or "FAULT")
    #$4: The priority value
    if [ "$2" = "VI_1" ]; then
        vip=${vips[0]}
    elif [ "$2" = "VI_2" ]; then
        vip=${vips[1]}
    fi
    msg="`date +%FT%H:%M:%S` $1 \"$2\" VIP \"${vip}\" have moved, HOST `hostname` turn to $3 state with the priority $4."
    #echo ${msg} | mailx -s "Keepalived state changed" -r $from -S smtp-auth-user=$user -S smtp-auth-password=$pwd $to
    echo ${msg} >> /tmp/keepalived.log
}

case $1 in
    master)
        exit 0
    ;;
    backup)
        exit 0
    ;;
    fault)
        exit 0
    ;;
    *)
        notify $1 $2 $3 $4
        exit 0
    ;;
esac
```
/etc/keepalived/convert_state.sh:
```
###/etc/keepalived/convert_state.sh###
#!/bin/bash
#

usage() {
    echo "./`basename $0` {master|backup}"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

if [[ "$1" = "master" ]]; then
    [ -f /etc/keepalived/down ] && rm -f /etc/keepalived/down
elif [[ "$1" = "backup" ]]; then
    [ ! -f /etc/keepalived/down ] && touch /etc/keepalived/down
else
    usage
fi
sleep 1
```
/etc/keepalived/chkngx.sh:
```
###/etc/keepalived/chkngx.sh###
#!/bin/bash
#

if pkill -0 nginx>/dev/null ; then
    [ `curl -sL -w %{http_code} http://localhost -o /dev/null` -eq 200 ] && exit 0
else
    service nginx start
fi
exit $?
```

### 三、使用ansible一键部署
####1. ansible角色目录结构：
```
keepalived_nginx/
├── ansible.cfg
├── deploy.yml
├── hosts
└── roles
    ├── keepalived
    │   ├── handlers
    │   │   └── main.yml
    │   ├── tasks
    │   │   └── main.yml
    │   ├── templates
    │   │   ├── chkngx.sh
    │   │   ├── convert_state.sh
    │   │   ├── keepalived.conf
    │   │   └── notify.sh
    │   └── vars
    │       └── main.yml
    └── nginx
        ├── handlers
        │   └── main.yml
        ├── tasks
        │   └── main.yml
        ├── templates
        │   └── nginx.systemd
        └── vars
            └── main.yml

11 directories, 14 files
```
####2.执行部署命令
```
cd keepalived_nginx/
[root@host1 keepalived_nginx]# ansible-playbook deploy.yml 

PLAY [nginx] *******************************************************************

TASK [setup] *******************************************************************
ok: [192.168.124.72]
ok: [192.168.124.71]

TASK [nginx : install denpendency package] *************************************
ok: [192.168.124.71] => (item=[u'pcre', u'openssl', u'pcre-devel', u'openssl-devel', u'zlib-devel', u'gd', u'gd-devel'])
ok: [192.168.124.72] => (item=[u'pcre', u'openssl', u'pcre-devel', u'openssl-devel', u'zlib-devel', u'gd', u'gd-devel'])

TASK [nginx : create nginx pid user] *******************************************
ok: [192.168.124.72]
ok: [192.168.124.71]

TASK [nginx : compile and install nginx] ***************************************
ok: [192.168.124.72]
ok: [192.168.124.71]

TASK [nginx : copy nginx systemd script] ***************************************
ok: [192.168.124.72]
ok: [192.168.124.71]

TASK [nginx : copy nginx init script] ******************************************
skipping: [192.168.124.71]
skipping: [192.168.124.72]

PLAY [keepalived] **************************************************************

TASK [setup] *******************************************************************
ok: [192.168.124.72]
ok: [192.168.124.71]

TASK [keepalived : install mailx] **********************************************
ok: [192.168.124.72]
ok: [192.168.124.71]

TASK [keepalived : install keepalived] *****************************************
ok: [192.168.124.71]
ok: [192.168.124.72]

TASK [keepalived : copy config file and chk_script to keepalived] **************
ok: [192.168.124.71] => (item=keepalived.conf)
changed: [192.168.124.72] => (item=keepalived.conf)
ok: [192.168.124.71] => (item=notify.sh)
ok: [192.168.124.72] => (item=notify.sh)
ok: [192.168.124.71] => (item=chkngx.sh)
ok: [192.168.124.72] => (item=chkngx.sh)

RUNNING HANDLER [keepalived : start keepalived service] ************************
changed: [192.168.124.72]

PLAY RECAP *********************************************************************
192.168.124.71             : ok=9    changed=0    unreachable=0    failed=0   
192.168.124.72             : ok=10   changed=2    unreachable=0    failed=0   
```
项目下载地址：https://github.com/gateray/keepalived_nginx
### 四、高可用测试
####1. vip1:192.168.124.251 on host1，vip2:192.168.124.252 on host2

 
####2. turn host2 to backup state
[root@host2 keepalived]# ./convert_state.sh backup



####3. restore host2 to vip2's master ,then force shutdown nginx
[root@host2 keepalived]# ./convert_state.sh master

[root@host2 keepalived]# systemctl stop nginx.service; mv /usr/local/nginx/sbin/nginx{,.tmp} 

 


#### 4.restore all
[root@host2 keepalived]# mv /usr/local/nginx/sbin/nginx{.tmp,}; systemctl start nginx.service

 

 

