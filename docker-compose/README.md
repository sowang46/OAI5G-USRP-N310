# Usage

Copy the proper directory to `openairinterface5g/ci-scripts/yaml_files`. For example: 

```
cp -r 5g_uesim_2ue ~/openairinterface5g/ci-scripts/yaml_files
```

Start the gNB on the host machine with rf simulator binded to localhost. Then move to `openairinterface5g/ci-scripts/yaml_files/5g_uesim_2ue` and start the UE containers:

```
cd ~/openairinterface5g/ci-scripts/yaml_files/5g_uesim_2ue
docker-compose up -d
```

Note: In the case of 4 or more UEs, some UEs may not be able to register due to the limitation of AUSF. Use `start_ue.sh` script to start UEs in those cases.

Check if the UE is successfully registered by checking the existance of `oaitun_ue1` interface inside the container:

```
docker exec -it rfsim5g-oai-nr-ue1 /bin/bash
# ifconfig | grep oaitun_ue1
```

Run parallel iPerf tests in one tmux session with `start_exp.sh`. Make sure all UEs are registered before starting the experiment.