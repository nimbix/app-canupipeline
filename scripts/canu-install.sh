#!/bin/bash

[ -z "$1" ] && echo "Canu version arg required!" && exit 1

CANU_VERSION=$1
# Oracle doesn't provide yum repos or sane URLs for downloading.
#JRE_URL=http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jre-8u131-linux-x64.rpm
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
#    cat <<'EOF' | patch -p2
#diff --git a/src/pipelines/canu/Execution.pm b/src/pipelines/canu/Execution.pm
#index be1fe77..840ac4f 100644
#--- a/src/pipelines/canu/Execution.pm
#+++ b/src/pipelines/canu/Execution.pm
#@@ -354,7 +354,7 @@ sub getLimitShellCode ($) {
#         $string .= "\n";
#         $string .= "max=`ulimit -Hu`\n";
#         $string .= "bef=`ulimit -Su`\n";
#-        $string .= "if [ \$bef -lt \$max ] ; then\n";
#+        $string .= "if [ \"\$bef\" != \"unlimited\" ] && [ \$bef -lt \$max ] ; then\n";
#         $string .= "  ulimit -Su \$max\n";
#         $string .= "  aft=`ulimit -Su`\n";
#         $string .= "  echo \"Changed max processes per user from \$bef to \$aft (max \$max).\"\n";
#EOF
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

