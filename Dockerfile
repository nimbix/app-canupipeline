# Copyright (c) 2017, Nimbix, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are
# those of the authors and should not be interpreted as representing official
# policies, either expressed or implied, of Nimbix, Inc.

FROM jarvice/base-centos-torque:latest
MAINTAINER Nimbix, Inc.

ARG CANU_VERSION
ENV CANU_VERSION ${CANU_VERSION:-1.4}

# Install Nimbix desktop so we can use GUI mode
ADD https://github.com/nimbix/image-common/archive/master.zip /tmp/nimbix.zip
WORKDIR /tmp

# Nimbix desktop (does a yum clean all)
RUN unzip nimbix.zip && rm -f nimbix.zip && mkdir -p /usr/local/lib/nimbix_desktop && for i in help-real.html help-tiger.html install-centos-real.sh install-centos-tiger.sh nimbix_desktop postinstall-tiger.sh url.txt xfce4-session-logout share skel.config; do cp -a /tmp/image-common-master/nimbix_desktop/$i /usr/local/lib/nimbix_desktop; done && rm -rf /tmp/image-common-master
RUN /usr/local/lib/nimbix_desktop/install-centos-tiger.sh && yum clean all && ln -s /usr/local/lib/nimbix_desktop /usr/lib/JARVICE/tools/nimbix_desktop

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
    rm -f canu-${CANU_VERSION}.Linux-amd64.tar.xz && \
    echo "export PATH=\$PATH:/usr/local/canu-${CANU_VERSION}/Linux-amd64/bin" >>/etc/profile.d/canu.sh

ADD ./scripts/canu-pipeline.sh /usr/local/scripts/canu/canu-pipeline.sh
ADD ./scripts/canu-desktop.sh /usr/local/scripts/canu/canu-desktop.sh
ADD ./NAE/AppDef.json /etc/NAE/AppDef.json
ADD ./NAE/AppDef.png /etc/NAE/AppDef.png
ADD ./NAE/help.html /etc/NAE/help.html
COPY ./NAE/screenshot.png /etc/NAE/screenshot.png

