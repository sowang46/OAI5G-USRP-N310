This repo contains thorough tutorials for 
1. Deploying OAI5G RAN/Core stack on USRP N310 and a PC.
2. Deploying FlexRIC on OAI5G stack. 
3. Customizing OAI5G MAC scheduler.

# Deploying OAI5G stack
In this tutorial we describe how to deploy OAI5G stack on PC (CU/DU/Core), USRP N310 (RU/UE), and/or COTS UE.

## Testbed
This tutorial is verified on the following hardware:
 - PC for OAI CN5G and OAI gNB (on the same PC)
    - OS: Ubuntu 20.04.1
    - Kernel: 5.15.0-53-lowlatency
    - CPU: Intel(R) Core(TM) i9-9900K CPU @ 3.60GHz
    - RAM: 16GB
 - USRP N310
    - UHD version: 4.0.0.0-93-g3b9ced8f
 - Oneplus 10T

## Build

### OAI-CN
Install dependencies

```bash
sudo apt install -y git net-tools putty

sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs)  stable"
sudo apt update
sudo apt install -y docker docker-ce

# Add your username to the docker group, otherwise you will have to run in sudo mode.
sudo usermod -a -G docker $(whoami)
reboot

# https://docs.docker.com/compose/install/
sudo curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

Then clone OAI-CN repo and pull docker images of Core network functions.
For a simple deployment, we don't need to build the images.
Nevertheless, we need to clone the repo since it contains necessary scripts to start up the core network.


```bash
# Git oai-cn5g-fed repository
git clone https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed.git ~/oai-cn5g-fed

# Pull docker images
docker pull oaisoftwarealliance/oai-amf:develop
docker pull oaisoftwarealliance/oai-nrf:develop
docker pull oaisoftwarealliance/oai-smf:develop
docker pull oaisoftwarealliance/oai-udr:develop
docker pull oaisoftwarealliance/oai-udm:develop
docker pull oaisoftwarealliance/oai-ausf:develop
docker pull oaisoftwarealliance/oai-spgwu-tiny:develop
docker pull oaisoftwarealliance/trf-gen-cn5g:latest

# Tag docker images
docker image tag oaisoftwarealliance/oai-amf:develop oai-amf:develop
docker image tag oaisoftwarealliance/oai-nrf:develop oai-nrf:develop
docker image tag oaisoftwarealliance/oai-smf:develop oai-smf:develop
docker image tag oaisoftwarealliance/oai-udr:develop oai-udr:develop
docker image tag oaisoftwarealliance/oai-udm:develop oai-udm:develop
docker image tag oaisoftwarealliance/oai-ausf:develop oai-ausf:develop
docker image tag oaisoftwarealliance/oai-spgwu-tiny:develop oai-spgwu-tiny:develop
docker image tag oaisoftwarealliance/trf-gen-cn5g:latest trf-gen-cn5g:latest
```


### OAI5G RAN

Add the following lines to `/etc/default/grub`

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_pstate=disable"
GRUB_CMDLINE_LINUX_DEFAULT="quiet processor.max_cstate=1 intel_idle.ma
x_cstate=0 idle=poll"
```

Add the following line to `/etc/modprobe.d/blacklist.conf` and then reboot the PC.
```bash
blacklist intel_powerclamp
```

Install cpufrequtils and set CPU to performance mode.

```bash
sudo apt-get install cpufrequtils
sudo vim /etc/default/cpufrequtils
# Add this line to the end of the file
# GOVERNOR=“performance”
sudo systemctl disable ondemand.service
sudo /etc/init.d/cpufrequtils restart
```

If there is no `/etc/default/cpufrequtils`, run `sudo cpufreq-set -g performance` on every boot.

Export UHD_IMAGES_DIR. This needs to be done on every login. 

```bash
export UHD_IMAGES_DIR=/usr/share/uhd/images
```

Clone the OAI-RAN repo and build the soft-modem executables.
More details on building the executables can be found in [this tutorial](https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/develop/doc/BUILD.md).

```bash
git clone https://gitlab.eurecom.fr/oai/openairinterface5g.git
cd openairinterface5g
git checkout develop
source oaienv
cd cmake_targets
# The -I option is to install pre-requisites, you only need it the first time you build the softmodem or when some oai dependencies have changed.
./build_oai -I
# The -w option is to select the radio head support you want to include in your build. 
# The --nrUE option is to build the nr-uesoftmodem executable and all required shared libraries.
./build_oai -w USRP --gNB --nrUE 
```

After completing the build, the binaries are available in the `cmake_targets/ran_build/build` directory.
The executable for NR gNB is `nr-softmodem` while `nr-uesoftmodem` is for NR UE.

Note: After any regular build you can compile the rfsimulator from the build directory:

```bash
cd <path to oai sources>/openairinterface5g/cmake_targets/ran_build/build
make rfsimulator
```

This is equivalent to using `-w SIMU` when running the `build_oai` script.
The rfsimulator allows you to run gNB and UE without an USRP.
It is especially useful for debugging the deployment.

## Configuration

In order to connect UE, gNB, and CN, we need to properly configures each components so that:
1. The NFs' ip addresses in gNB config file match the CN deployment so that the gNB can communication with CN.
2. The PLMN in gNB config file is in the PLMN support list in AMF's config file so that gNB can be registered at AMF.
3. The UE's IMSI, TAC, KEY, and OPC is registered in CN's database.

### USRP N310

Use `uhd_usrp_probe` to make sure that the USRP's firmware version matches the UHD installation.
You can also find USRP's IP address using this command.

```bash
$ uhd_usrp_probe                       
[INFO] [UHD] linux; GNU C++ version 9.3.0; Boost_107100; UHD_4.0.0.0-93-g3b9ced8f                                   
[INFO] [MPMD] Initializing 1 device(s) in parallel with args: mgmt_addr=192.168.20.2,type=n3xx,product=n310,serial=3
177E5E,claimed=False,addr=192.168.20.2      # USRP's IP address
```

More [tutorials on setting up USRP](https://kb.ettus.com/USRP_N300/N310/N320/N321_Getting_Started_Guide).

### gNB
The gNB's config files for NR can be found at `openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF`.
In this tutorial, we use `gnb.band78.sa.fr1.162PRB.2x2.usrpn310.conf` as template.
The PLMN section (Line 15) has to be filled with the proper values that match the configuration of the AMF and the UE USIM.

```bash
    // Tracking area code, 0x0000 and 0xfffe are reserved values
    tracking_area_code  =  1;
    plmn_list = ({ mcc = 001; mnc = 01; mnc_length = 2; snssaiList = ({ sst = 1 }) });
```

The IP interfaces for the communication with the CN (Line 205) also need to be set to match the IP address of AMF and UPF.

```bash
    ////////// AMF parameters:
    amf_ip_address      = ( { ipv4       = "192.168.70.132";
                              ipv6       = "192:168:30::17";
                              active     = "yes";
                              preference = "ipv4";
                            }
                          );


    NETWORK_INTERFACES :
    {
        GNB_INTERFACE_NAME_FOR_NG_AMF            = "demo-oai";
        GNB_IPV4_ADDRESS_FOR_NG_AMF              = "192.168.70.129/24";
        GNB_INTERFACE_NAME_FOR_NGU               = "demo-oai";      # UPF
        GNB_IPV4_ADDRESS_FOR_NGU                 = "192.168.70.129/24";        # UPF
        GNB_PORT_FOR_S1U                         = 2152; # Spec 2152
    };
```

In the first part (`amf_ip_address`) we specify the IP of the AMF and in the second part (`NETWORK_INTERFACES`) we specify the gNB local interface with AMF (N2 interface) and the UPF (N3 interface).

Note: 192.168.70.132 is the OAI-CN5G AMF Container IP address. 
If you are running RAN and CN on two PCs, you certainly will need to do some networking manipulations for the gNB server to be able to see this AMF container.
See [the Sec.4.3 in this tutorial](https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed/-/blob/master/docs/DEPLOY_SA5G_BASIC_DEPLOYMENT.md) for more details.

If you would like to use USRP as RU (instead of the rfsimulator), you also need to match the RU address to USRP's IP address.

```bash
RUs = (
    {
       local_rf       = "yes"
         nb_tx          = 2
         nb_rx          = 2
         att_tx         = 0
         att_rx         = 0;
         bands          = [78];
         max_pdschReferenceSignalPower = -27;
         max_rxgain                    = 75;
         eNB_instances  = [0];
         bf_weights = [0x00007fff, 0x0000];
         sf_extension = 0
         sdr_addrs = "addr=192.168.20.2,clock_source=internal,time_source=internal"  # Match addr with USRP's address
    }
);
```

### AMF

The AMF's configuration file is located in `etc/amf.conf` inside the `oai-amf` container.
The values in this file is set by `oai-cn5g-fed/docker-compose/docker-compose-basic-nrf.yaml` (for the basic scenario) in the repo.

The PLMN section (Line 123) needs to align with gNB config.
Failing to do so may lead to NG setup failure when starting the gNB.

```bash
oai-amf:
        container_name: "oai-amf"
        image: oai-amf:develop
        environment:
            - TZ=Europe/paris
            - INSTANCE=0
            - PID_DIRECTORY=/var/run
            - MCC=208       # Match MCC in gNB config
            - MNC=99        # Match MNC in gNB config
            - REGION_ID=128
            - AMF_SET_ID=1
```

More details on CN configurations can be found in [this tutorial](https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed/-/blob/master/docs/CONFIGURE_CONTAINERS.md)

### SIM Card
Program SIM Card with [Open Cells Project](https://open-cells.com/) application [uicc-v2.6](https://open-cells.com/d5138782a8739209ec5760865b1e53b0/uicc-v2.6.tgz).

```bash
sudo ./program_uicc --adm 12345678 --imsi 001010000000001 --isdn 00000001 --acc 0001 --key fec86ba6eb707ed08905757b1bb44b8f --opc C42449363BBAD02B66D16BC975D77CC1 -spn "OpenAirInterface" --authenticate
```

## Run 

### Run CN
Start the CN by running this command.

```bash
python3 core-network.py --type start-basic --scenario 1
```

Once you see output like this, your CN is up and you are ready to start the RAN.

```bash
[2022-06-29 16:15:01,304] root:DEBUG:  OAI 5G Core network is configured and healthy....
```

To stop CN, run

```bash
python3 core-network.py --type stop-basic --scenario 1
```

More details on running CN can be found in [this tutorial](https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed/-/blob/master/docs/DEPLOY_SA5G_BASIC_DEPLOYMENT.md).

### Run gNB w/ USRP

Run the following commands to start gNB with USRP N310. Note: all software modem executables have to be run in `openairinterface5g/cmake_targets/ran_build/build` directory.

```bash
cd ~/openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-softmodem -O ../../../targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb.band78.sa.fr1.162PRB.2x2.usrpn310.conf --sa --usrp-tx-thread-config 1
```8


### Run gNB w/ rfsimulator

Run the following commands to start gNB with rfsimulator:
```bash
cd ~/openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-softmodem -O ../../../targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb.sa.band78.fr1.106PRB.usrpb210.conf --gNBs.[0].min_rxtxtime 6 --rfsim --sa
```

Then on the same PC, launch another terminal start UE with rfsimulator using this command:
```bash
cd ~/openairinterface5g/cmake_targets/ran_build/build
sudo RFSIMULATOR=127.0.0.1 ./nr-uesoftmodem -r 106 --numerology 1 --band 78 -C 3619200000 --nokrnmod --rfsim --sa --uicc0.imsi 001010000000001 --uicc0.nssai_sd 1
```
or
```
sudo RFSIMULATOR=127.0.0.1 ./nr-uesoftmodem -r 106 --numerology 1 --band 78 -C 3619200000 --nokrnmod --rfsim --sa -O nr-ue-sim.oai.conf
```

>NOTE: The first 5 digits of UE's IMSI should match the PLMN and UE's DNN should be present in SESSION_MANGMENT_SUBSCRIPTION_LIST in smf's configuration file

### Ping test
- UE host
```bash
ping 192.168.70.135 -t -S 12.1.1.2      # 12.1.1.2 is the IP address of oaitun_ue1
```
- CN5G host
```bash
docker exec -it oai-ext-dn ping 12.1.1.2
```

### Downlink iPerf test
- UE host
```bash
iperf -s -u -i 1 -B 12.1.1.2    # Somehow iperf3 doesn't work
```

- CN5G host
```bash
docker exec -it oai-ext-dn /bin/bash  
iperf -u -t 86400 -i 1 -fk -B 192.168.70.135 -b 100M -c 12.1.1.2 
```


### Debug
1. The control message in CN can be captured on `demo-oai` interface. These captures can be quite helpful since Wireshark can parse most of SBI messages.
2. You can also check CN NFs log using `docker logs`. For example, to check AMF's log, run:
```bash
sudo docker logs oai-amf
```
Or you can directly access a container's shell by running
```bash
sudo docker exec -it oai-amf /bin/bash
```


# Deploying FlexRIC
TBD

# Customizing MAC scheduler
Related tutorial: [SW_archi](https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/develop/doc/SW_archi.md)

The scheduler function is called by the chain: 

```bash
nr_ul_indication()->gNB_dlsch_ulsch_scheduler()->nr_schedule_ulsch()/nr_schedule_ue_spec()->nr_fr1_ulsch_preprocessor()->pf_ul()
```

> To signal which users have how many resources, the preprocessor populates the NR_sched_pusch_t (for values changing every TTI, e.g., frequency domain allocation) and NR_sched_pusch_save_t (for values changing less frequently, 
> at least in FR1 [to my understanding], e.g., DMRS fields when the time domain allocation stays between TTIs) structures. 

The actual scheduler implementation is in `pf_ul()`, which implements a basic PF scheduler. The code is as follows (Line 1529 in [gNB_scheduler_ulsch.c](https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/develop/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_ulsch.c))

A brief analysis of the code can be found [here](docs/scheduler_code.md).

# ToDo
1. Find a way to test UE attaching and throughput.
2. Test OAI UE with a new USRP N310.
3. Test UE attaching and throughput with Oneplus 10T.