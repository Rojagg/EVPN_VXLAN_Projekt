#!/bin/bash
ip addr replace 100.64.0.2 dev lo
ip addr add 192.168.2.1/30 dev eth1


ip link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0
ip link add vxlan0 type vxlan dstport 4789 local 100.64.0.2 nolearning external vnifilter



ip link set br0 addrgenmode none
ip link set vxlan0 addrgenmode none master br0


ip link set br0 address 22:33:44:55:66:77
ip link set vxlan0 address 22:33:44:55:66:77
ip link set br0 up
ip link set vxlan0 up

bridge link set dev vxlan0 vlan_tunnel on neigh_suppress on learning off

############################################
ip link add vrf1 type vrf table 1100
ip link set vrf1 up

ip link add vrf2 type vrf table 1200
ip link set vrf2 up

ip link add vrf3 type vrf table 1300
ip link set vrf3 up
############################################



###
#
#L3 VNI 100 configuration
#
##
bridge vlan add dev br0 vid 1100 self
bridge vlan add dev vxlan0 vid 1100
bridge vni add dev vxlan0 vni 100
bridge vlan add dev vxlan0 vid 1100 tunnel_info id 100

ip link add vrf1br link br0 type vlan id 1100
ip link set vrf1br address 22:33:44:55:66:77 addrgenmode none
ip link set vrf1br master vrf1


bridge vlan add dev bro0 vid 10 self
bridge vlan add dev vxlan0 vid 10
bridge vni add dev vxlan0 vni 110
bridge vni add dev vxlan0 vid 10 tunnel_info id 110
ip link add vlan10 link br0 type vlan id 10
ip link set vlan10 master vrf1
ip link set vlan10 addr 11:22:33:44:55:6e
ip addr add 10.0.10.1/24 dev vlan10
ip link set vlan10 up


##
#
#L3 VNI 200 configuration
#
##
bridge vlan add dev br0 vid 1200 self
bridge vlan add dev vxlan0 vid 1200
bridge vni add dev vxlan0 vni 200
bridge vni add dev vxlan0 vid 1200 tunnel_info id 200


ip link add vrf2br link br0 type vlan id 1200
ip link set vrf2br address 22:33:44:55:66:77
ip link set vrf2br master vrf2


bridge vlan add dev br0 vid 20 self
bridge vlan add dev vxlan0 vid 20
bridge vni add dev vxlan vni 220
bridge vlan add dev vxlan vid 20 tunnel_info id 220
ip link add vlan20 link br0 vlan id 20
ip link set vlan20 master vrf2
ip link set vlan20 addr 11:22:33:44:55:dc
ip addr add 10.0.20.1/24 dev vlan20
ip link set vlan20 up

##
#
#  VRF3 -
#
##
#
bridge vlan add dev br0 vid 30 self
bridge vlan add dev vxlan0 vid 30
bridge vni add dev vxlan0 vni 330
bridge vlan add dev vxlan0 vid 30 tunnel_info id 330
ip link add vlan30 link br0 vlan id 30
ip link set vlan30 master vrf2
ip link set vlan30 addr 11:22:33:44:51:4A
ip addr add 10.0.30.1/24 dev vlan30
ip link set vlan30 up

##
#
#
#
#
##
bridge vlan add dev br0 vid 40 self
bridge vlan add dev vxlan0 vid 40
bridge vni add dev vxlan0 vni 440
bridge vlan add dev vxlan0 vid 40 tunnel_info id 440
ip link add vlan40 link br0 vlan id 40
ip link set vlan40 addr 11:22:33:41:C8
ip add addr 10.0.40.1/24 dev vlan40
ip link set vlan40 up

##
bridge vlan add dev br0 vid 50 self
bridge vlan add dev vxlan0 vid 50
bridge vni add dev vxlan0 vni 550
bridge vlan add dev vxlan0 vid 50 tunnel_info id 550
ip link add vlan50 link br0 vlan id 50
ip link set vlan50 addr 11:22:33:42:26
sysctl -w net.ipv4.conf.vlan50.forwarding=0
sysctl -w net.ipv6.conf.vlan50.forwarding=0
ip link set vlan50 up

ip link set eth0 master br0
bridge vlan add dev eth0 vid 10
bridge vlan add dev eth0 vid 20
bridge vlan add dev eth0 vid 30
bridge vlan add dev eth0 vid 40
bridge vlan add dev eth0 vid 50






