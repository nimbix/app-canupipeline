# Copyright (c) 2019, Nimbix, Inc.
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

#FROM jarvice/base-centos-torque:6.1.2-stripped
FROM jarvice/app-hpctest:18.08.8
LABEL maintainer="Nimbix, Inc."

# Update SERIAL_NUMBER to force rebuild of all layers (don't use cached layers)
ARG SERIAL_NUMBER
ENV SERIAL_NUMBER ${SERIAL_NUMBER:-20191023.1000}

ARG CANU_VERSION
ENV CANU_VERSION ${CANU_VERSION:-1.8}
ARG JRE_URL
ENV JRE_URL ${JRE_URL:-http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jre-8u131-linux-x64.rpm}

#RUN curl -H 'Cache-Control: no-cache' \
#        https://raw.githubusercontent.com/nimbix/image-common/master/install-nimbix.sh \
#        | bash -s -- --setup-nimbix-desktop

# for standalone use
EXPOSE 5901
EXPOSE 443

# Add scripts
COPY scripts/canu-desktop.sh /usr/local/scripts/canu/canu-desktop.sh
COPY scripts/canu-install.sh /usr/local/scripts/canu/canu-install.sh
COPY scripts/canu-pipeline.sh /usr/local/scripts/canu/canu-pipeline.sh

COPY NAE/screenshot.png /etc/NAE/screenshot.png
COPY NAE/AppDef.png /etc/NAE/AppDef.png
COPY NAE/help.html /etc/NAE/help.html
COPY NAE/AppDef.json /etc/NAE/AppDef.json
RUN curl --fail -X POST -d @/etc/NAE/AppDef.json https://api.jarvice.com/jarvice/validate

RUN sed -i -e "s/%CANU_VERSION%/${CANU_VERSION}/" /etc/NAE/AppDef.json

# Do Canu install
WORKDIR /tmp
RUN /usr/local/scripts/canu/canu-install.sh ${CANU_VERSION} ${JRE_URL} && \
    echo "export PATH=\$PATH:/usr/local/canu-${CANU_VERSION}/Linux-amd64/bin" >>/etc/profile.d/canu.sh
