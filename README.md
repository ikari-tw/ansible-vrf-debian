## ANSIBLE VRF-DEBIAN ROLE


#### 1. CONTEXTE

- deployer une VRF d'administration sur une vm debian vanilla
- objectifs : cloisonnement services d'administration génériques + sécurisation services production
- emploi d'iproute2 (pas de namespace, pas de systemd-networkd, pas de PBR)
- cloisonner sshd server + resolution dns dans la VRF "mgmt"


#### 2. REFERENCES

- https://stbuehler.de/blog/article/2020/02/29/using_vrf__virtual_routing_and_forwarding__on_linux.html
- https://interpip.es/linux/creating-a-vrf-and-running-services-inside-it-on-linux/
- https://people.kernel.org/dsahern/management-vrf-and-dns
- https://www.kernel.org/doc/html/latest/networking/vrf.html
- https://lists.debian.org/debian-user/2018/12/msg00772.html
- https://www.dasblinkenlichten.com/working-with-linux-vrfs/
- https://github.com/m4rcu5/ifupdown-vrf


#### 3. ENV

- environnement maitrisé : meme vm clonée
- 1 vm debian de test avec 2 interfaces réseaux minimum (pas de vlan ou bridge)
- os cible: debian 11 avec sshd (+cles deployees) et compte admin (+ sudo) ok


#### 4. STEP-BY-STEP MANUAL

###### 4.1 get info

- ssh check 					: done by ansible
- admin + sudo check 	: ssh keys already installed
- iproute2 check 			: by default in debian 11
- ansible adds 				: ansible-galaxy collection install community.general
- interfaces list 		: 

		~$ netstat -i 
		Kernel Interface table
		Iface      MTU    RX-OK RX-ERR RX-DRP RX-OVR    TX-OK TX-ERR TX-DRP TX-OVR Flg
		ens33     1500      581      0      0 0           352      0      0      0 BMRU
		ens35     1500        0      0      0 0            52      0      0      0 BMRU
		lo       65536        0      0      0 0             0      0      0      0 LRU
		mgmt     65575      534      0      0 0             0      0      0      0 OmRU


###### 4.2 push configs

- /etc/sysctl.d/99-vrf.conf

		net.ipv4.conf.all.log_martians = 1
		net.ipv4.ip_forward = 1
		net.ipv6.conf.all.disable_ipv6 = 1
		vm.overcommit_memory = 1

- /sbin/vrf.sh

		#!/bin/bash
		ip link add mgmt type vrf table 99
		ip link set dev mgmt up
		ip route add table 99 0.0.0.0/0 via $mgmt-gw-ip
		ip link set dev ens33 master mgmt
		ip addr add dev mgmt 127.0.0.1/8

- /etc/systemd/system/vrf.service

		[Unit]
		Description=MGMT VRF REBOOT PROOF
		Before=network-pre.target
		Wants=network-pre.target
		[Service]
		Type=oneshot
		ExecStart=/sbin/vrf.sh
		[Install]
		WantedBy=multi-user.target

- /lib/systemd/system/ssh.service > /etc/systemd/system/ssh.service.d/override.conf

		[Unit]
		After=vrf.target
		[Service]
		ExecStart=
		ExecStart=/bin/ip vrf exec mgmt /usr/sbin/sshd -D $SSHD_OPTS


###### 4.3 reboot & tests

- ssh check
- netinfo.sh

		#!/bin/bash
		$HOSTNAME
		ip -4 -o -br a
		ip r
		netstat -i | grep ^e | cut -d " " -f 1
		ip vrf show
		ip route show table 99
		ip vrf exec mgmt traceroute 8.8.8.8

- sudo ip vrf exec mgmt ping $ip
- ss -tau
- ps fauxwww | grep ssd > ip vrf identify $pid
- tests apt update (sudo ip vrf exec mgmt apt update)
- try ssh on both ip address of the host, only the one in mgmt vrf should answer


#### 5. TRANSPOSITION ANSIBLE

- role :

        roles/vrf-debian
        ├── defaults
        │    └── main.yml
        ├── files
        ├── handlers
        │    └── main.yml
        ├── meta
        │    └── main.yml
        ├── README.md
        ├── tasks
        │    └── main.yml
        ├── templates
        │    ├── netinfo.sh.j2
        │    ├── reset.sh
        │    ├── ssh.override.conf.j2
        │    ├── sysctl.conf
        │    ├── vrf.service.j2
        │    └── vrf.sh.j2
        ├── tests
        │    ├── inventory
        │    └── test.yml
        └── vars
            └── main.yml

- playbook :

        ---

        - name: MGMT VRF DEBIAN VANILLA
          gather_facts: yes
          hosts: "tp6cli"
          become: true

          tasks:

          - name: vrf role
            include_role:
              name: vrf-debian
            vars:
              vrf_name: mgmt
              vrf_table: 99
              vrf_gw: 192.168.0.254
              vrf_iface: ens33


#### 6. TESTS & CONCLUSION

        (ansible) /opt/ansible » ansible-playbook playbooks/vrf.yml -i inventory/hosts
        Executing playbook vrf.yml

        - TEST on hosts: tp6cli -
        Gathering Facts...
          tp6cli ok
        vrf role...
          tp6cli ok
        install iproute2...
          tp6cli ok
        tpl sysctl params...
          tp6cli done
        tpl vrf.service...
          tp6cli done
        tpl vrf.sh...
          tp6cli done
        enable vrf service systemd...
          tp6cli done
        systemd reload...
          tp6cli ok
        tpl netinfo.sh...
          tp6cli ok
        enforce ssh overriding dir...
          tp6cli done
        tpl ssh override...
          tp6cli done
        reboot_host (via handler)... 
          tp6cli done

        - Play recap -
          tp6cli                     : ok=13   changed=7    unreachable=0    failed=0    rescued=0    ignored=0   


Cheers.


