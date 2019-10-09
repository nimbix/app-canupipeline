#!/bin/bash
#
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

[ -z "$1" ] && echo "Canu version arg required!" && exit 1

CANU_VERSION=$1
# Oracle doesn't provide yum repos or sane URLs for downloading.
[ -n "$2" ] && JRE_URL=$2

yum install -y wget gnuplot #java-1.8.0-openjdk-headless.x86_64
wget -nv --header "Cookie: oraclelicense=accept-securebackup-cookie" ${JRE_URL}
yum install -y $(basename ${JRE_URL})
rm -f $(basename ${JRE_URL})

#wget "https://github.com/marbl/canu/releases/download/v${CANU_VERSION}/canu-${CANU_VERSION}.Linux-amd64.tar.xz" || \

wget -nv "https://github.com/marbl/canu/archive/v${CANU_VERSION}.tar.gz"

if [ -f "canu-${CANU_VERSION}.Linux-amd64.tar.xz" ]; then
    tar xvf canu-${CANU_VERSION}.Linux-amd64.tar.xz -C /usr/local
    rm -f canu-${CANU_VERSION}.Linux-amd64.tar.xz
elif [ -f "v${CANU_VERSION}.tar.gz" ]; then
    yum install -y make gcc-c++ patch
    tar xzf v${CANU_VERSION}.tar.gz
    cd canu-${CANU_VERSION}/src
    cat <<'EOF' | patch -p2
diff -Naur a/src/pipelines/canu/Execution.pm b/src/pipelines/canu/Execution.pm
--- a/src/pipelines/canu/Execution.pm	2018-07-02 18:21:01.924747943 +0000
+++ b/src/pipelines/canu/Execution.pm	2018-07-02 18:21:59.118710929 +0000
@@ -374,7 +374,7 @@
     $string .= "\n";
     $string .= "max=`ulimit -Hn`\n";
     $string .= "bef=`ulimit -Sn`\n";
-    $string .= "if [ \$bef -lt \$max ] ; then\n";
+    $string .= "if [ \"\$bef\" != \"unlimited\" ] && [ \$bef -lt \$max ] ; then\n";
     $string .= "  ulimit -Sn \$max\n";
     $string .= "  aft=`ulimit -Sn`\n";
     $string .= "  echo \"  Changed max open files from \$bef to \$aft (max \$max).\"\n";
EOF
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

