#!/bin/bash
#Set the IP address for the interface - more production-friendly - implicit /3
#idempotent - checking whether the interface is already configured
ip addr replace 100.64.0.1 dev lo


#Create the bridge named br0 that will be vlan aware - this allows us to distinguish the membership using vlan
# and disabling native vlan - so vlan 1 is no longer assigned by default
ip link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0


# the key setting for SVD configuration is "external" - so it sth similiar to nve in HUAWEI
# "vnifilter" isn't strictly necessary but is good practice, because then the VNI that is not used is received
# The message with this VNI will be directly discarded, otherwise we will accept and try process every VXLAN message
ip link add vxlan0 type vxlan dstport 4789 local 100.64.0.1 nolearning external vnifilter
ip link set br0 addrgenmode none
ip link set vxlan0 addrgenmode none master br0



#Mac address is consistent for both because bridge and vxlan interface represent a single VTEP 
#(br0 for internal switching fabric - facing internal clients)
#vxlan0 for external connection - facing external
ip link set br0 address 11:22:33:44:55:66
ip link set vxlan0 address 11:22:33:44:55:66
ip link set br0 up
ip link set vxlan0 up


#Creation of VRF
#############################
## ip-vrf vrf1 / l3vni 100 ##
#############################
ip link add vrf1 type vrf table 1100
ip link set vrf1 up

#############################
## ip-vrf vrf2 / l3vni 200 ##
#############################
ip link add vrf2 type vrf table 1200
ip link set vrf2 up

#############################
## ip-vrf vrf3 / no l3vni  ##
#############################
ip link add vrf3 type vrf table 1300
ip link set vrf3 up




############################
## ip-vrf vrf1 / l3vni 100 ##
#############################
# Choose any arbitrary VLAN for L3VNIs, since it never leaves the device
# as long as it doesn't collide with another VLAN. It's used solely to
# bind into a routing table (VRF)
#
# So basially we add the vlan id 1100 to pool of bridge br0 vlan (self)
# VID in L3 VNI has only local scope it means that it is used to identify elements that belong to that VNI,
# but not for the tagging purpose
bridge vlan add dev br0 vid 1100 self
bridge vlan add dev vxlan0 vid 1100
bridge vni add dev vxlan0 vni 100 # add vni if using vnifilter
bridge vlan add dev vxlan0 vid 1100 tunnel_info id 100 # map vlan to vni
ip link add vrf1br link br0 type vlan id 1100 # create vlan on top of bridge
ip link set vrf1br address 11:22:33:44:55:66 addrgenmode none # set L3VNI devices to routermac and no address
ip link set vrf1br master vrf1 # bind the device to the correct VRF, no address for L3VNI

#############################
## ip-vrf vrf2 / l3vni 200 ##
#############################
bridge vlan add dev br0 vid 1200 self
bridge vlan add dev vxlan0 vid 1200
bridge vni add dev vxlan0 vni 200
bridge vlan add dev vxlan0 vid 1200 tunnel_info id 200
ip link add vrf2br link br0 type vlan id 1200
ip link set vrf2br address 11:22:33:44:55:66 addrgenmode none
ip link set vrf2br master vrf2

###############################
## ip-vrf vrf3 / no l3vni    ##
###############################
# vrf3 has no L3VNI, so no bridge/vxlan configuration needed
# vrf3 is only used for intra bridge domain forwarding (l2 only)

ip link set vrf1br up
ip link set vrf2br up

###############
## l2vni 110 ## Configuration of L2 vni is similiar to L3 - but there VID is significant, because it is used
#also for the forwarding (vid in L2 frame)
#Difference is that the L2 VNI is additionaly assigned to L3VNI (vrf) and has configured IP address (VBDIF address)
###############
bridge vlan add dev br0 vid 10 self
bridge vlan add dev vxlan0 vid 10
bridge vni add dev vxlan0 vni 110
bridge vlan add dev vxlan0 vid 10 tunnel_info id 110
ip link add vlan10 link br0 type vlan id 10
ip link set vlan10 master vrf1 # bind L2VNI to L3VNI (vrf1)
ip link set vlan10 addr aa:bb:cc:00:00:6e # unique MAC per L2VNI+VTEP combo (or use anycast MAC, see below)
ip addr add 10.0.10.1/24 dev vlan10 # shared gateway IP per L2VNI, on all VTEPs
ip addr add 2001:db8:0:10::1/64 dev vlan10
ip link set vlan10 up

###############
## l2vni 220 ##
###############
bridge vlan add dev br0 vid 20 self
bridge vlan add dev vxlan0 vid 20
bridge vni add dev vxlan0 vni 220
bridge vlan add dev vxlan0 vid 20 tunnel_info id 220
ip link add vlan20 link br0 type vlan id 20
ip link set vlan20 master vrf2 # bind L2VNI to L3VNI (vrf2)
ip link set vlan20 addr aa:bb:cc:00:00:dc
ip addr add 10.0.20.1/24 dev vlan20
ip addr add 2001:db8:0:20::1/64 dev vlan20
ip link set vlan20 up

###############
## l2vni 330 ## Can access only other via L2VNI so the same bridge domain - because L3VNI is not establised so intra domain
#flow is not possible AND we can implement routes to other networks that are placed in this vni
###############
bridge vlan add dev br0 vid 30 self
bridge vlan add dev vxlan0 vid 30
bridge vni add dev vxlan0 vni 330
bridge vlan add dev vxlan0 vid 30 tunnel_info id 330
ip link add vlan30 link br0 type vlan id 30
ip link set vlan30 master vrf3 # bind L2VNI to vrf3 (no L3VNI)
ip link set vlan30 addr aa:bb:cc:00:01:4a
ip addr add 10.0.30.1/24 dev vlan30
ip addr add 2001:db8:0:30::1/64 dev vlan30
ip link set vlan30 up

###############
## l2vni 440 ## It is in public vrf - it can access the entire bridge domain and external connections
###############
bridge vlan add dev br0 vid 40 self
bridge vlan add dev vxlan0 vid 40
bridge vni add dev vxlan0 vni 440
bridge vlan add dev vxlan0 vid 40 tunnel_info id 440
ip link add vlan40 link br0 type vlan id 40
# vlan40 is not enslaved to any VRF, so it's in the default VRF
ip link set vlan40 addr aa:bb:cc:00:01:b8
ip addr add 10.0.40.1/24 dev vlan40
ip addr add 2001:db8:0:40::1/64 dev vlan40
ip link set vlan40 up

###############
## l2vni 550 ## It can access only the bridge domain (only L2 connectivity) - and anything else - becasue the routing is 
#disabled in kernel
###############
bridge vlan add dev br0 vid 50 self
bridge vlan add dev vxlan0 vid 50
bridge vni add dev vxlan0 vni 550
bridge vlan add dev vxlan0 vid 50 tunnel_info id 550
ip link add vlan50 link br0 type vlan id 50
# vlan50 is L2-only (no routing)
ip link set vlan50 addr aa:bb:cc:00:02:26
# no IP address for unrouted L2VNI
sysctl -w net.ipv4.conf.vlan50.forwarding=0
sysctl -w net.ipv6.conf.vlan50.forwarding=0
ip link set vlan50 up


###################################
## l2vni 110 / eth10 access port ##
###################################
#ip link set eth10 master br0
#bridge vlan add dev eth10 vid 10 pvid untagged

###################################
## l2vni 220 / eth20 access port ##
###################################
#ip link set eth20 master br0
#bridge vlan add dev eth20 vid 20 pvid untagged

###################################
## l2vni 330 / eth30 access port ##
###################################
#ip link set eth30 master br0
#bridge vlan add dev eth30 vid 30 pvid untagged

###################################
## l2vni 440 / eth40 access port ##
###################################
#ip link set eth40 master br0

#bridge vlan add dev eth40 vid 40 pvid untagged

###################################
## l2vni 550 / eth50 access port ##
###################################
#ip link set eth50 master br0
#bridge vlan add dev eth50 vid 50 pvid untagged


ip link set eth0 master br0
bridge vlan add dev eth0 vid 10
bridge vlan add dev eth0 vid 20
bridge vlan add dev eth0 vid 30
bridge vlan add dev eth0 vid 40
bridge vlan add dev eth0 vid 50
