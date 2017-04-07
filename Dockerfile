FROM jarvice/base-centos-torque:latest
MAINTAINER Nimbix, Inc.

ARG CANU_VERSION
ENV CANU_VERSION ${CANU_VERSION:-1.4}

# Install Nimbix desktop so we can use GUI mode
ADD https://github.com/nimbix/image-common/archive/master.zip /tmp/nimbix.zip
WORKDIR /tmp

# Nimbix desktop (does a yum clean all)
RUN unzip nimbix.zip && rm -f nimbix.zip && mkdir -p /usr/local/lib/nimbix_desktop && for i in help-real.html help-tiger.html install-centos-real.sh install-centos-tiger.sh nimbix_desktop postinstall-tiger.sh url.txt xfce4-session-logout share skel.config; do cp -a /tmp/image-common-master/nimbix_desktop/$i /usr/local/lib/nimbix_desktop; done && rm -rf /tmp/image-common-master
RUN /usr/local/lib/nimbix_desktop/install-centos-tiger.sh && yum clean all && ln -s /usr/local/lib/nimbix_desktop /usr/lib/JARVICE/tools/nimbix_desktop && echo "/usr/local/bin/nimbix_desktop" >>/etc/rc.local

# recreate nimbix user home to get the right skeleton files
RUN /bin/rm -rf /home/nimbix && /sbin/mkhomedir_helper nimbix

# for standalone use
EXPOSE 5901
EXPOSE 443

# Do Canu install
WORKDIR /tmp
RUN yum install -y wget gnuplot java-1.8.0-openjdk-headless.x86_64 && \
    yum clean all && \
    wget "https://github.com/marbl/canu/releases/download/v${CANU_VERSION}/canu-${CANU_VERSION}.Linux-amd64.tar.xz" && \
    tar xvf canu-${CANU_VERSION}.Linux-amd64.tar.xz -C /usr/local && \
    rm -f canu-${CANU_VERSION}.Linux-amd64.tar.xz

ADD ./scripts/canu-pipeline.sh /usr/local/scripts/canu/canu-pipeline.sh
ADD ./NAE/AppDef.json /etc/NAE/AppDef.json
ADD ./NAE/AppDef.png /etc/NAE/AppDef.png
ADD ./NAE/help.html /etc/NAE/help.html
COPY ./NAE/screenshot.png /etc/NAE/screenshot.png

