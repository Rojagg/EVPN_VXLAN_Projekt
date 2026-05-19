#!/bin/bash

ip addr add 192.168.1.2/30 dev eth1
ip addr add 192.168.2.2/30 dev eth2

ip addr replace 10.0.1.1/32 dev lo
