# Usage

Copy the proper directory to `openairinterface5g/ci-scripts/yaml_files`. For example: 

```
cp -r 5g_uesim_2ue ~/openairinterface5g/ci-scripts/yaml_files
```

Start the gNB on the host machine with rf simulator binded to localhost. Then move to `openairinterface5g/ci-scripts/yaml_files/5g_uesim_2ue` and start the UE containers:

```
cd ~/openairinterface5g/ci-scripts/yaml_files/5g_uesim_2ue
docker-compose up -d oai-nr-ue1 oai-nr-ue2
```

Note: You cannot start all UEs with `docker-compose up -d`

Check if the UE is successfully registered by checking the existance of `oaitun_ue1` interface inside the container:

```
docker exec -it rfsim5g-oai-nr-ue1 /bin/bash
# ifconfig | grep oaitun_ue1
```