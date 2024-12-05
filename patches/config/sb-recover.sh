#!/bin/bash
echo "SB detect" >> /tmp/sb.txt
drbdadm status cluster >> /tmp/sb.txt
