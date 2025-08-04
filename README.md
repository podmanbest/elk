# elk-podman

elk with podman and podman-compose, for RHEL8 based images.

## Manual Deployment

Install podman, python and git.

```sh
sudo dnf install -y podman python3 git
```

Create a regular OS user to avoid bugs with podman userids, also assign wheel group privileges for sudo.

```sh
sudo groupadd podman
sudo useradd -m -d /home/elastic elastic && \
sudo usermod -a -G podman elastic && \
sudo su - elastic
```

Install podman-compose for regular user.

```sh
python3 -m pip install --user podman-compose
```

Clone the repo and CD into it.

```sh
git clone https://github.com/podmanbest/elk.git && cd elk
```

Create a Data directory for elastic and disable SELinux (yes... I know, but fuc\*\* it, this is a lab).

```sh
mkdir -p /tmp/elk/data
sudo setenforce 0
```

Export the desired ELK version and build the images.

```sh
export ELK_VERSION=7.9.2
podman-compose -f compose.yml build
```

Enable the followin ports for testing.

```sh
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --add-port=5601/tcp --permanent
sudo firewall-cmd --add-port=9200/tcp --permanent
sudo firewall-cmd --reload
```

Remember to enable the same ports in case you are testing in your cloud and not your local machine.

```sh
podman-compose -f compose.yml up
```

Export the PUBLIC IP (your external cloud IP, assigned to your VM), in case you are using your local machine use 'localhost'.

```sh
export PUBLICIP=X.X.X.X
```

Create 2 indices.

```sh
curl -XPOST -D- "http://$PUBLICIP:5601/api/saved_objects/index-pattern" \
    -H 'Content-Type: application/json' \
    -H 'kbn-version: 7.9.2' \
    -u elastic:changeme \
    -d '{"attributes":{"title":"http-groupa-*","timeFieldName":"@timestamp"}}'
```

```sh
curl -XPOST -D- "http://$PUBLICIP:5601/api/saved_objects/index-pattern" \
    -H 'Content-Type: application/json' \
    -H 'kbn-version: 7.9.2' \
    -u elastic:changeme \
    -d '{"attributes":{"title":"http-groupb-*","timeFieldName":"@timestamp"}}'
```

Test your indices

```sh
curl -XPOST -H 'Content-Type: application/json' \
"http://$PUBLICIP:8080" -d '{"message":"hello"}'
```

Log to Kibana and check index management and discover logs.

http://$PUBLICIP:5601
