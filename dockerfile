#
# Author:      Erik Welander (erik.welander@hotmail.com)
# Modified:    2021-01-09
# 
# Generates a neat little torrent box that uses qbittorrent with a webUI and wireguard.
# All data and configurations will be stored outside the container.
# Upon startup, a random wireguard configuration will be picked from the configuration folder before qbittorrent starts.
# Some utils are provided so that the proper configuration is used internally, you can access the box with: docker exec -it <container> bash
#
# Instructions on how to use:
# The following arguments should be provided when running this container:
# #Permissions (Required by wireguard): 
# --cap-add net_admin --cap-add sys_module --privileged
# #Mount points:
# -v <hostpath>/:/mnt/configs -v <hostpath>/:/mnt/data
# #Ports:
# -p <hostport>:8088
# DNS:
# Docker uses it's own internal DNS by using a BIND mount, hence the vpn profile will not replace the actual DNS used.
# You will need to manualy specify what DNS to use when you create the container:
# --dns 8.8.8.8 --dns 8.8.4.4
# I strongly recommend using a reverse proxy with nginx and lets-encrypt if you intend to have the web-ui accessable from the internet.
# Example:
# docker build -t qbt --build-arg MIRROR=http://ftp.acc.umu.se/ubuntu/ .
# sudo docker run -d --name qbt --cap-add net_admin --cap-add sys_module --privileged --dns=1.1.1.1 --dns=1.0.0.1 -v /home/erik/docker/wireguard-qbittorrent/container_data/.config:/root/.config/ -v /home/erik/docker/wireguard-qbittorrent/container_data/.local:/root/.local/ -v /home/erik/docker/wireguard-qbittorrent/container_data/Wireguard:/root/Wireguard -v /mnt/local/:/root/Downloads -p 8088:8088 qbt
# (or just pass the hash to the ./run.sh script)
#
FROM ubuntu:20.04

VOLUME /mnt/data
VOLUME /root/.config

RUN usermod -u 99 nobody

ARG MIRROR
# Replace mirrors (Too lazy to write a SED :P)
RUN if [ ! "$MIRROR" = "\$MIRROR" ]; then \
    echo "deb $MIRROR focal main restricted" > /etc/apt/sources.list; \
    echo "deb $MIRROR focal universe" >> /etc/apt/sources.list; \
    echo "deb $MIRROR focal-updates universe" >> /etc/apt/sources.list; \
    echo "deb $MIRROR focal-updates main restricted" >> /etc/apt/sources.list; \
    echo "deb $MIRROR focal multiverse" >> /etc/apt/sources.list; \
    echo "deb $MIRROR focal-updates multiverse" >> /etc/apt/sources.list; \
    echo "deb $MIRROR focal-security main restricted" >> /etc/apt/sources.list; \
    echo "deb $MIRROR focal-security universe" >> /etc/apt/sources.list; \
    echo "deb $MIRROR focal-security multiverse" >> /etc/apt/sources.list; \
    echo "deb $MIRROR focal-backports main restricted universe multiverse" >> /etc/apt/sources.list; \
    echo "deb http://archive.canonical.com/ubuntu focal partner" >> /etc/apt/sources.list; \
    fi

RUN echo "========== Adding base utils and repositories =========="
RUN apt-get update \
    && apt-get install -y --no-install-recommends apt-utils debconf-utils dialog openssl \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:qbittorrent-team/qbittorrent-stable 

RUN echo "========== Installing packages =========="
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
htop \
iftop \
iputils-ping \
inetutils-traceroute \
vim \
sudo \
coreutils \
iproute2 \
net-tools \
resolvconf \
iptables \
wireguard \
qbittorrent-nox

COPY scripts /root/scripts
RUN chmod +x /root/scripts/*.sh
WORKDIR /root/scripts

ENTRYPOINT ./wg.sh && /usr/bin/qbittorrent-nox
