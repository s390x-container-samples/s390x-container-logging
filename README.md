# ELK setup for Linux on IBM Z
This repo contains a working setup for the ELK stack for Linux on IBM Z. The container images for ELK are not publically available and they need to be built from source code. The components are:
   - [Elasticsearch](https://www.elastic.co/products/elasticsearch): distributed, RESTful search and analytics engine 
   - [Kibana](https://www.elastic.co/products/kibana): UI for elasticsearch
   - [Logstash](https://www.elastic.co/products/logstash): data processor
   - [Beats](https://www.elastic.co/products/beats): data shipper to elasticsearch or logstash
   
## Dockerfiles
- Dockerfiles source:

   - Elastisearch: https://github.com/linux-on-ibm-z/dockerfile-examples/blob/master/Elasticsearch/Dockerfile
   - Kibana: https://github.com/linux-on-ibm-z/dockerfile-examples/blob/master/Kibana/Dockerfile
   - Logstash: https://github.com/linux-on-ibm-z/dockerfile-examples/tree/master/Logstash/Dockerfile
   - Beats: https://raw.githubusercontent.com/linux-on-ibm-z/dockerfile-examples/master/Beats/Dockerfile

## Build the container images for ELK stack

Elastisearch:
The `dockerfiles/elasticsearch/Dockerfile-user` dockerfile fixes the permission denied problem for the dir data.
```sh
$ wget -O dockerfiles/elasticsearch/Dockerfile https://raw.githubusercontent.com/linux-on-ibm-z/dockerfile-examples/master/Elasticsearch/Dockerfile
$ docker build --no-cache -t elasticsearch:7.3.0 -f dockerfiles/elasticsearch/Dockerfile .
$ docker build -t elasticsearch-user:7.3.0 -f dockerfiles/elasticsearch/Dockerfile-user .
```

Logstash:
```sh
$ mkdir -p dockerfiles/logstash/
$ wget -O dockerfiles/logstash/Dockerfile https://raw.githubusercontent.com/linux-on-ibm-z/dockerfile-examples/master/Logstash/Dockerfile
$ wget -O dockerfiles/logstash/dockerfile_netty_tcnative https://raw.githubusercontent.com/linux-on-ibm-z/dockerfile-examples/master/Logstash/dockerfile_netty_tcnative
$ wget -O dockerfiles/logstash/dockerfile_openssl_dynamic https://raw.githubusercontent.com/linux-on-ibm-z/dockerfile-examples/master/Logstash/dockerfile_openssl_dynamic
$ docker build --no-cache -t logstash:7.3.0 -f dockerfiles/logstash/Dockerfile .
```

Kibana:
```sh
$ mkdir -p dockerfiles/kibana/
$ wget -O dockerfiles/kibana/Dockerfile https://raw.githubusercontent.com/linux-on-ibm-z/dockerfile-examples/master/Kibana/Dockerfile
$ docker build -t kibana:7.3.0 -f dockerfiles/kibana/Dockerfile .
```
Beats:
```sh
$ mkdir -p dockerfiles/beats/
$ wget -O dockerfiles/beats/Dockerfile https://raw.githubusercontent.com/linux-on-ibm-z/dockerfile-examples/master/Beats/Dockerfile
$ docker build --no-cache -t beats:7.3.0 -f dockerfiles/beats/Dockerfile .
```

Check images:
```sh
$ docker images
REPOSITORY                TAG                                        IMAGE ID            CREATED             SIZE
elasticsearch              7.3.0                                      8fa079cb4f10        41 minutes ago      1.02GB
logstash                  7.3.0                                      679cbd6747e1        4 hours ago         633MB
kibana                    7.3.0                                      171eb463de5c        8 hours ago         7.45GB
beats                     7.3.0                                      08d107976951        3 days ago          1.43GB
```

## Host configuration

### Elasticsearch
VM memory increase. See https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
```sh
sysctl -w vm.max_map_count=262144
```

## Docker-compose
Run the containers with `docker-compose`
```sh
$ docker-compose create
$ docker-compose start
Starting elasticsearch ... done
Starting logstash      ... done
Starting beats         ... done
Starting kibana        ... done
$ docker-compose ps   
         Name                       Command               State                            Ports                          
--------------------------------------------------------------------------------------------------------------------------
elkonz_beats_1           /bin/sh -c $BEATSNAME -e - ...   Up                                                              
elkonz_elasticsearch_1   elasticsearch                    Up      0.0.0.0:9200->9200/tcp, 0.0.0.0:9300->9300/tcp          
elkonz_kibana_1          kibana -H 0.0.0.0                Up      0.0.0.0:5601->5601/tcp                                  
elkonz_logstash_1        logstash                         Up      0.0.0.0:5000->5000/tcp, 5043/tcp,                       
                                                                  0.0.0.0:5044->5044/tcp, 514/tcp, 9292/tcp,              
                                                                  0.0.0.0:9600->9600/tcp
```
Verify elastisearch is correctly started:
```sh
curl -X GET http://localhost:9200/
{
  "name" : "elastisearch",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "w87vepkPTNqlAxrZIZA1NA",
  "version" : {
    "number" : "7.3.0-SNAPSHOT",
    "build_flavor" : "oss",
    "build_type" : "tar",
    "build_hash" : "de777fa",
    "build_date" : "2019-09-25T11:24:55.832607Z",
    "build_snapshot" : true,
    "lucene_version" : "8.1.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```
For Kibana dashboard, browse at http://IP:5601/app/kibana

## FileBeat
Beats is the tool that gathers data. Currently, the repo contains the configuration to collect syslog and container information. There are many more usecases. You can check what beat offers at https://www.elastic.co/products/beats.
### Syslog
The `syslog` module can be configured by adding to `filebeat.yaml`
```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
     - /var/log/*.log
```
and the beats container needs to be able to read the directory where the logs are stored. Hence, we need to pass this directory as volume. This is done by adding in the docker-compose.yaml these lines:
```yaml
      - type: bind
        source: /var/log/
        target: /var/log/
```
More advanced options at https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-input-syslog.html

For this example, you can use one of the scripts in `demo` to generate some logs. They will be visible in Kibana. 

### Docker

In order to collect docker metrics, you need to enable the `docker` module in beats. It is enough to add
these options to the `filebeat.yaml`
```yaml
filebeat.inputs:
  - type: docker
    enabled: true
    containers.ids: '*'
```
The beat conainer needs to be able to read the container logs. Therefore, the `/var/lib/docker/containers` needs to be passed as a volume. In the `docker-compose.yaml`, this is done by adding:
```sh
      - type: bind
        source: /var/lib/docker/containers
        target: /var/lib/docker/containers
```
More advanced options at https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-input-docker.html

You can generate some logs by running
```sh
$ docker run -ti alpine sh -c 'while [ true ]; do echo "Print something" && sleep 5 ; done'
Print something
Print something
Print something
^C
```
