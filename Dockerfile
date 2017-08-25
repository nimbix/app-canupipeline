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

FROM jarvice/base-centos-torque:6.0.4
MAINTAINER Nimbix, Inc.

ARG CANU_VERSION
ENV CANU_VERSION ${CANU_VERSION:-1.6}
ARG JRE_URL
ENV JRE_URL ${JRE_URL:-http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jre-8u131-linux-x64.rpm}

# Install Nimbix desktop so we can use GUI mode
ADD https://github.com/nimbix/image-common/archive/master.zip /tmp/nimbix.zip
WORKDIR /tmp

# Nimbix desktop (does a yum clean all)
RUN unzip nimbix.zip && rm -f /tmp/nimbix.zip && mkdir -p /usr/local/lib/nimbix_desktop && for i in help-real.html help-tiger.html install-centos-real.sh install-centos-tiger.sh nimbix_desktop postinstall-tiger.sh url.txt xfce4-session-logout share skel.config; do cp -a /tmp/image-common-master/nimbix_desktop/$i /usr/local/lib/nimbix_desktop; done && rm -rf /tmp/image-common-master
RUN /usr/local/lib/nimbix_desktop/install-centos-tiger.sh && yum clean all && ln -s /usr/local/lib/nimbix_desktop /usr/lib/JARVICE/tools/nimbix_desktop

# recreate nimbix user home to get the right skeleton files
RUN /bin/rm -rf /home/nimbix && /sbin/mkhomedir_helper nimbix

# for standalone use
EXPOSE 5901
EXPOSE 443

# Add scripts and whatnot
ADD ./scripts/canu-desktop.sh /usr/local/scripts/canu/canu-desktop.sh
ADD ./scripts/canu-install.sh /usr/local/scripts/canu/canu-install.sh
ADD ./scripts/canu-pipeline.sh /usr/local/scripts/canu/canu-pipeline.sh
COPY ./NAE/screenshot.png /etc/NAE/screenshot.png
ADD ./NAE/AppDef.png /etc/NAE/AppDef.png
ADD ./NAE/help.html /etc/NAE/help.html
ADD ./NAE/AppDef.json /etc/NAE/AppDef.json
RUN sed -i -e "s/%CANU_VERSION%/${CANU_VERSION}/" /etc/NAE/AppDef.json

# Do Canu install
WORKDIR /tmp
RUN /usr/local/scripts/canu/canu-install.sh ${CANU_VERSION} ${JRE_URL} && \
    echo "export PATH=\$PATH:/usr/local/canu-${CANU_VERSION}/Linux-amd64/bin" >>/etc/profile.d/canu.sh

