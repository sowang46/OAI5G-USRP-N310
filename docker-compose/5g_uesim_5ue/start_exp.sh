#!/bin/bash

# Create 5x2 pane grid
tmux new-session -d -s ue_iperf
tmux split-window -v -p 80 
tmux split-window -v -p 75
tmux split-window -v -p 66
tmux split-window -v -p 50
tmux select-pane -t 0
tmux split-window -h
tmux select-pane -t 2
tmux split-window -h
tmux select-pane -t 4
tmux split-window -h
tmux select-pane -t 6
tmux split-window -h
tmux select-pane -t 8
tmux split-window -h

# Iteratively start the iPerf servers/clients
for UE_ID in 1 2 3 4 5
do
    UE_IP=$(docker exec -it rfsim5g-oai-nr-ue$UE_ID ifconfig oaitun_ue1 | grep "inet" | awk -F'[: ]+' '{ print $3 }')
    tmux send-keys -t $(( 2*(UE_ID-1) )) "docker exec -it rfsim5g-oai-nr-ue$UE_ID iperf -s -u -i 1 -B $UE_IP" Enter
    tmux send-keys -t $(( 2*(UE_ID-1)+1 )) "docker exec -it oai-ext-dn iperf -u -t 86400 -i 1 -fk -B 192.168.70.135 -b 100M -c $UE_IP" Enter
done