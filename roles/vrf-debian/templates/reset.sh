#!/bin/sh
rm /etc/sysctl.d/99-vrf.conf 
rm /sbin/vrf.sh 
systemctl disable vrf.service 
rm /etc/systemd/system/vrf.service 
rm -rf /etc/systemd/system/ssh.service.d/
systemctl daemon-reload 
reboot
