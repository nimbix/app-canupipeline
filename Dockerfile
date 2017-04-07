FROM jarvice/base-centos-torque:latest
MAINTAINER Nimbix, Inc.

VOLUME /tmp
WORKDIR /tmp

ARG CANU_VERSION
ENV CANU_VERSION ${CANU_VERSION:-1.4}

RUN yum install -y wget java-1.8.0-openjdk-headless.x86_64 && \
    yum clean all && \
    wget "https://github.com/marbl/canu/releases/download/v${CANU_VERSION}/canu-${CANU_VERSION}.Linux-amd64.tar.xz" && \
    tar xvf canu-${CANU_VERSION}.Linux-amd64.tar.xz && \
    mv /tmp/canu-${CANU_VERSION} /usr/local/canu-${CANU_VERSION}

ADD ./scripts/canu-pipeline.sh /usr/local/scripts/canu/canu-pipeline.sh
ADD ./NAE/AppDef.json /etc/NAE/AppDef.json
ADD ./NAE/AppDef.png /etc/NAE/AppDef.png
ADD ./NAE/help.html /etc/NAE/help.html
COPY ./NAE/screenshot.png /etc/NAE/screenshot.png

CMD ["/usr/local/scripts/canu/canu-pipeline.sh"]
