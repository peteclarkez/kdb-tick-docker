#!/bin/bash 
cd /opt/kx/kdb-tick
touch /opt/kx/kdb-tick/tick.log
#Tick
nohup q tick.q sym  .  -p 5010	< /dev/null > /opt/kx/kdb-tick/tick.log 2>&1 &  
#RDB
nohup q tick/r.q :5010 -p 5011	< /dev/null > /opt/kx/kdb-tick/rdb.log 2>&1 &
#HDB
#nohup q sym            -p 5012	< /dev/null > /opt/kx/kdb-tick/hdb.log 2>&1 &
#Feedhanler
nohup q tick/feed.q  < /dev/null > /opt/kx/kdb-tick/feed.log 2>&1 &

tail -f /opt/kx/kdb-tick/tick.log