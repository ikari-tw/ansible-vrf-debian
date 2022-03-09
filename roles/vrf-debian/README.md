## TP6 ANSIBLE + GITHUB


#### 1. CONTEXTE

- deployer une tache repetetive avec ansible
- partager le code sur github
- demontrer le fonctionnement


#### 2. PROJET

- deployer une VRF d'administration sur une vm debian vanilla
- raisons : cloisonnement services d'administration génériques + sécurisation services production
- emploi d'iproute2 (pas de namespace, pas de systemd-networkd, pas de PBR)
- mettre en ecoute sshd server + ntpsec + resolution dns dans la VRF "mgmt"
- verifier iproute2 apt, ntp, sshd, kernel, syslog


#### 3. REFERENCES

- https://stbuehler.de/blog/article/2020/02/29/using_vrf__virtual_routing_and_forwarding__on_linux.html
- https://interpip.es/linux/creating-a-vrf-and-running-services-inside-it-on-linux/
- https://people.kernel.org/dsahern/management-vrf-and-dns
- https://www.kernel.org/doc/html/latest/networking/vrf.html
- https://lists.debian.org/debian-user/2018/12/msg00772.html
- https://www.dasblinkenlichten.com/working-with-linux-vrfs/
- https://github.com/m4rcu5/ifupdown-vrf


#### 4. ENV

- environnement maitrisé : meme OS, meme vm clonée
- 1 vm debian de test avec 2 interfaces réseaux minimum (pas de vlan ou bridge)
- 1 env virtuel python3 avec ansible
- os cible: debian 11 avec sshd (+cles deployees) et compte admin (+ sudo) ok


#### 5. STEP-BY-STEP MANUAL

###### 5.1 get info

- ssh check 					: done by ansible
- admin + sudo check 	: ssh keys already installed
- iproute2 check 			: by default in debian 11
- ansible adds 				: ansible-galaxy collection install community.general
- interfaces list 		: ansible_facts {{ ansible_interfaces }}

		~$ netstat -i 
		Kernel Interface table
		Iface      MTU    RX-OK RX-ERR RX-DRP RX-OVR    TX-OK TX-ERR TX-DRP TX-OVR Flg
		ens33     1500      581      0      0 0           352      0      0      0 BMRU
		ens35     1500        0      0      0 0            52      0      0      0 BMRU
		lo       65536        0      0      0 0             0      0      0      0 LRU
		mgmt     65575      534      0      0 0             0      0      0      0 OmRU

- /etc/network/interfaces

		auto lo
		iface lo inet loopback
		allow-hotplug ens33
		iface ens33 inet static
			address 192.168.0.211/24
			#gateway 192.168.0.254
			#dns-nameservers 9.9.9.9
		allow-hotplug ens35
		iface ens35 inet static
			address 10.0.0.211/24
			#gateway 10.0.0.1
			#dns-nameservers 9.9.9.9


###### 5.2 push configs

- /etc/sysctl.conf or /etc/sysctl.d/99-sysctl.conf

		kernel.domainname = tp6.ocr
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

- /lib/systemd/system/ntpsec.service > /etc/systemd/system/ntpsec.service.d/override.conf

		[Unit]
		After=vrf.target
		[Service]
		ExecStart=
		ExecStart=/bin/ip vrf exec mgmt /usr/libexec/ntpsec/ntp-systemd-wrapper

###### 5.3 reboot & tests

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

review "for i in netstat ..."

- sudo ip vrf exec mgmt ping $ip
- ps fauxwww > ip vrf identify $pid
- tests apt update (sudo ip vrf exec MGMT-VRF apt update)



#### 6. TRANSPOSITION ANSIBLE



#### 7. TESTS & CONCLUSION



