#!/bin/bash

[ -z "$1" ] && echo "Canu version arg required!" && exit 1

CANU_VERSION=$1

yum install -y wget gnuplot java-1.8.0-openjdk-headless.x86_64
wget "https://github.com/marbl/canu/releases/download/v${CANU_VERSION}/canu-${CANU_VERSION}.Linux-amd64.tar.xz" || \
    wget "https://github.com/marbl/canu/archive/v${CANU_VERSION}.tar.gz"

if [ -f "canu-${CANU_VERSION}.Linux-amd64.tar.xz" ]; then
    tar xvf canu-${CANU_VERSION}.Linux-amd64.tar.xz -C /usr/local
    rm -f canu-${CANU_VERSION}.Linux-amd64.tar.xz
elif [ -f "v${CANU_VERSION}.tar.gz" ]; then
    yum install -y make gcc-c++
    tar xzf v${CANU_VERSION}.tar.gz
    cd canu-${CANU_VERSION}/src
    BUILDSTACKTRACE=0 CC=gcc make -j 12
    cd ..
    mkdir -p /usr/local/canu-${CANU_VERSION}
    mv Linux-amd64 /usr/local/canu-${CANU_VERSION}/Linux-amd64
    cd ..
    rm -rf canu-${CANU_VERSION} v${CANU_VERSION}.tar.gz
else
    echo "Canu version (${CANU_VERSION}) not found!"
    exit 1
fi

yum clean all

