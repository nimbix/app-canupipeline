#!/bin/bash
#
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
#
# Author: Stephen Fox (stephen.fox@nimbix.net)

################################################################################
# canu-pipeline.sh
#
# Setup:
#  1. Install CANU from binary archives
#     (https://github.com/marbl/canu/releases, along with JAVA 1.8);
#     * https://github.com/marbl/canu/releases/download/v1.2/canu-1.2.Linux-amd64.tar.bz2
#     * http://download.oracle.com/otn-pub/java/jdk/8u91-b14/jre-8u91-linux-x64.rpm
#  2. Call /usr/local/scripts/torque/launch_all.sh to start the torque server
#     and clients
#
# This script should be called if you want to submit a job to torque via
# qsub or qrun in the current job environment.
################################################################################

sudo service sshd start 2>/dev/null
echo "$0 $@"

SPEC_FILE=
GENOME_MAGNITUDE=

while [ ! -z "$1" ]; do
    case "$1" in
        -ApplicationParams)
            shift
            PARAMS="$1"
            ;;
        -action)
            shift
            if [ "$1" != "all" ]; then
                ACTION="$1"
            else
                ACTION=
            fi
            ;;
        -genomeSize)
            shift
            GENOME_SIZE="$1"
            ;;
        -genomeMagnitude)
            shift
            if [ "$1" != "None" ]; then
                GENOME_MAGNITUDE="$1"
            else
                GENOME_MAGNITUDE=""
            fi
            ;;
        -rawErrorRate)
            shift
            RAW_ERROR_RATE="rawErrorRate=$1"
            ;;
        -correctedErrorRate)
            shift
            CORRECTED_ERROR_RATE="correctedErrorRate=$1"
            ;;
        -inputType)
            shift
            INPUT_TYPE="$1"
            ;;
        -inputFile)
            shift
            INPUT_FILE="$1"
            ;;
        -resumeFromJob)
            shift
            RESUME_FROM_JOB="$1"
            ;;
        -s)
            shift
            SPEC_FILE="-s $1"
            ;;
        *)
            ;;
    esac
    shift
done

sleep 5

echo "* Starting torque..."
#sudo /usr/local/scripts/torque/launch.sh
/usr/local/scripts/torque/launch_all.sh

sleep 15

TIMEOUT=100
ELAPSED=0

while [ 1 ]; do
    NODE_COUNT=$(qnodes -a |grep -i down | wc -l)
    if [ $NODE_COUNT -gt 0 ]; then
        sleep 10
        ELAPSED=$(($ELAPSED+10))
        if [ $ELAPSED -gt $TIMEOUT ]; then
            echo "* Failure to start torque!" 1>&2
            echo `qnodes -a` 1>&2
            exit 1
        fi
    else
        break
    fi
done

CANU_PATH=$(ls -d /usr/local/canu-*)/Linux-amd64/bin
export PATH=${PATH}:${CANU_PATH}

. /etc/JARVICE/jobinfo.sh

if [ ! -z $RESUME_FROM_JOB ] && [ ! -d /data/$RESUME_FROM_JOB ]; then
    echo "** FATAL: Cannot resume job: $RESUME_FROM_JOB. Try with a different job name, or leave this blank to start over." 1>&1
fi


OUTPUT_DIR=/data/${JOB_NAME}

# Create output directory
if [ ! -z $RESUME_FROM_JOB ]; then
    ln -s /data/$RESUME_FROM_JOB $OUTPUT_DIR
    # Get the job prefix, from the -p prefix part of canu.01.sh, since that's how the job run is uniquely identified
    JOB_PREFIX=$(tail -n1 /data/$RESUME_FROM_JOB/canu-scripts/canu.01.sh | awk 'BEGIN { FS="[ ]+" } { print $5 }' | awk 'BEGIN { FS="\"" } { print $2 }')
else
    JOB_PREFIX=$JOB_NAME
    mkdir -p $OUTPUT_DIR
fi
cd $OUTPUT_DIR

echo "** Output will be saved to /data/${JOB_NAME}"

# canu \
#     -d <working-directory> \
#     -p <file-prefix> \
#     [-s specifications] \
#     [-correct | -trim | -assemble] \
#     errorRate=<fraction-error> \
#     genomeSize=<genome-size>\
#     [parameters] \
#     [-pacbio-raw         <read-file>]
#     [-pacbio-corrected   <read-file>]
#     [-nanopore-raw       <read-file>]
#     [-nanopore-corrected <read-file>]
printf "%0.s#" {1..75}; echo
echo `qnodes -a`
printf "%0.s#" {1..75}; echo
echo `qstat -a`


set -e
# Canu is PBS aware and submits the job to PBS automagically using the name canu_${JOB_NAME}
CANU_CMD="canu -d ${OUTPUT_DIR} -p ${JOB_PREFIX} ${SPEC_FILE} ${ACTION} \
    ${RAW_ERROR_RATE} ${CORRECTED_ERROR_RATE} \
    genomeSize=${GENOME_SIZE}${GENOME_MAGNITUDE} \
    gridOptionsJobName=canu ${PARAMS}"
echo "** Resume canu job command: $CANU_CMD"
if [ ! -z $RESUME_FROM_JOB ]; then
    echo "** Resuming Canu job: $RESUME_FROM_JOB"
else
    CANU_CMD+=" ${INPUT_TYPE} ${INPUT_FILE}"
    echo "** New canu job command: $CANU_CMD"
    echo "** Starting new Canu job: $JOB_NAME"
fi
$CANU_CMD
set +e

# Query the Torque Job Id so we can schedule the system to shutdown once it ends
torque_job_id="$(qstat -f |grep "Job Id"| awk 'BEGIN { FS=": " } { print $2 }')"

QUEUE_LENGTH=1
SCRIPT_DIR=$OUTPUT_DIR/canu-scripts
LAST_LATEST_CANU=""
LATEST_CANU=""

if [ ! -z $torque_job_id ]; then
    while : ; do
        LATEST_SCRIPT=$(ls -1 $SCRIPT_DIR/canu.*.sh | sort | tail -n 1)
        LATEST_CANU=$(basename $LATEST_SCRIPT .sh)
        if [ "$LATEST_CANU" != "$LAST_LATEST_CANU" ]; then
            LATEST_OUTPUT=$SCRIPT_DIR/$LAST_LATEST_CANU.out
            if [ -f $LATEST_OUTPUT ]; then
                echo
                echo "*** Log file contents ($LATEST_OUTPUT):"
                cat $LATEST_OUTPUT
            fi
            echo
            echo "*** Current script is $LATEST_SCRIPT:"
            cat $LATEST_SCRIPT
            echo
            echo -n "*** Processing"
            LAST_LATEST_CANU=$LATEST_CANU
        fi
        sleep 10
        echo -n "."
        QUEUE_LENGTH=$(qstat -f | grep "job_state" | grep -v "job_state = C" | wc -l)
        LATEST_QUEUE=$SCRIPT_DIR/$LATEST_CANU.qstat
        echo "$(date): QUEUE_LENGTH=$QUEUE_LENGTH" >>$LATEST_QUEUE
        qstat -f >>$LATEST_QUEUE
        printf "%0.s*" {1..75} >>$LATEST_QUEUE
        echo >>$LATEST_QUEUE
        [ $QUEUE_LENGTH -eq 0 ] && echo && echo "** Queue is empty" && break
    done

    LATEST_OUTPUT=$SCRIPT_DIR/$LATEST_CANU.out
    echo
    echo "*** Last log file contents ($LATEST_OUTPUT):"
    cat $LATEST_OUTPUT

    echo; printf "%0.s*" {1..75}; echo

    FAILED=$(grep -i "canu failed" $LATEST_OUTPUT)
    if [ -n "$FAILED" ]; then
        echo "$FAILED" 1>&2
        echo "** FATAL: Error while running canu job!" 1>&2
        ERROR_CODE=1
        echo "** qnodes -a output:"
        qnodes -a
        echo "** qstat -f output:"
        qstat -f
    else
        echo "** SUCCESS: Canu job finished!" 1>&2
        ERROR_CODE=0
    fi
else
    echo "** FATAL: Error launching canu job!" 1>&2
    ERROR_CODE=1
fi

# Workaround for a bug with the block vaults
#NNODES=$(cat /etc/JARVICE/nodes | wc -l)
#let NSLAVES=$NNODES-1
#
#for i in `cat /etc/JARVICE/nodes |tail -n $NSLAVES`; do
#    echo "* Shutting down $i"
#    ssh $i sudo halt
#done

exit $ERROR_CODE
