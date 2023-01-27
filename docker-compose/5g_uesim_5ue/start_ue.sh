#!/bin/bash

docker-compose up -d oai-nr-ue1
sleep 5
docker-compose up -d oai-nr-ue2
sleep 5
docker-compose up -d oai-nr-ue3
sleep 5
docker-compose up -d oai-nr-ue4
sleep 5
docker-compose up -d oai-nr-ue5
sleep 5