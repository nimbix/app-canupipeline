#!/usr/bin/env bash
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
#

################################################################################
# canu-pipeline.sh
#
# Setup:
#  1. Install CANU from binary archives
#     (https://github.com/marbl/canu/releases, along with JAVA 1.8);
#     * https://github.com/marbl/canu/releases/download/v1.2/canu-1.2.Linux-amd64.tar.bz2
#
#  2. Call /usr/local/scripts/cluster-start.sh to start the Slurm server
#     and clients
#
#   Canu command line format:
#   canu \
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
#
# This script should be called if you want to submit a job to Slurm via
# sbatch in the current job environment
################################################################################

#set -x

TOOLSDIR="/usr/local/JARVICE/tools/bin"

# start SSHd
echo "INFO: starting SSHd..."
${TOOLSDIR}/sshd_start

# Wait for slaves...max of 60 seconds
SLAVE_CHECK_TIMEOUT=60
${TOOLSDIR}/python_ssh_test ${SLAVE_CHECK_TIMEOUT}
ERR=$?
if [[ ${ERR} -gt 0 ]]; then
  echo "ERROR: One or more slaves failed to start" 1>&2
  exit ${ERR}
fi

echo "INFO: Canu pipeline setup: $0 $*"
echo

SPEC_FILE=
GENOME_MAGNITUDE=

while [ -n "$1" ]; do
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
  -memory)
    shift
    MEM="$1"
    ;;
  *) ;;

  esac
  shift
done

# start the Slurm cluster, feed the node memory size and turn off the desktop
echo "INFO:  Starting Slurm cluster..."
/usr/local/scripts/cluster-start.sh memory "$MEM"
echo

CANU_PATH=$(ls -d /usr/local/canu-*)/Linux-amd64/bin
export PATH=${PATH}:${CANU_PATH}

. /etc/JARVICE/jobinfo.sh

DATADIR=/data
[ -f $DATADIR/please_place_all_files_in_data_directory.txt ] &&
  DATADIR=/data/data

if [ -n "$RESUME_FROM_JOB" ] && [ ! -d $DATADIR/$RESUME_FROM_JOB ]; then
  echo "FATAL: Cannot resume job: $RESUME_FROM_JOB. Try with a different job name, or leave this blank to start over" 1>&1
fi

OUTPUT_DIR=$DATADIR/${JOB_NAME}

# Create output directory
if [ -n "$RESUME_FROM_JOB" ]; then
  ln -s $DATADIR/$RESUME_FROM_JOB $OUTPUT_DIR
  # Get the job prefix, from the -p prefix part of canu.01.sh, since that's how the job run is uniquely identified
  JOB_PREFIX=$(tail -n1 $DATADIR/$RESUME_FROM_JOB/canu-scripts/canu.01.sh | sed -e "s/.*\-p '\([^']*\)'.*/\1/")
else
  JOB_PREFIX=$JOB_NAME
  mkdir -p $OUTPUT_DIR
fi

cd $OUTPUT_DIR

echo "INFO:  Output will be saved to $OUTPUT_DIR"
echo

printf "%0.s#" {1..75}
echo
echo "INFO:  Slurm node info:"
scontrol show nodes
printf "%0.s#" {1..75}
echo
echo "INFO:  Slurm queue info:"
squeue
printf "%0.s#" {1..75}
echo

set -e
# Canu is Slurm aware and submits the job to Slurm automagically using the name canu_${JOB_NAME}
CANU_CMD="canu -d ${OUTPUT_DIR} -p ${JOB_PREFIX} ${SPEC_FILE} ${ACTION}
    ${RAW_ERROR_RATE} ${CORRECTED_ERROR_RATE}
    genomeSize=${GENOME_SIZE}${GENOME_MAGNITUDE}
    gridOptionsJobName=canu ${PARAMS}"

if [ -n "$RESUME_FROM_JOB" ]; then
  echo "INFO:  Resume Canu job command: $CANU_CMD"
  echo "INFO:  Resuming Canu job: $RESUME_FROM_JOB"
else
  CANU_CMD+=" ${INPUT_TYPE} ${INPUT_FILE}"
  echo "INFO:  New Canu job command: $CANU_CMD"
  echo "INFO:  Starting new Canu job: $JOB_NAME"
fi

# Launch the Canu command line job
$CANU_CMD
set +e

QUEUE_LENGTH=1
SCRIPT_DIR=$OUTPUT_DIR/canu-scripts
LAST_LATEST_CANU=""
LATEST_CANU=""
ERROR_CODE=0

# Slurm has multiple Job IDs during a Canu run, not a single one so monitor the
#  scripts that Canu generates for job portions
sleep 5
while true; do
  LATEST_SCRIPT=$(ls -1 $SCRIPT_DIR/canu.*.sh | sort | tail -n 1)
  LATEST_CANU=$(basename $LATEST_SCRIPT .sh)

  if [ "$LATEST_CANU" != "$LAST_LATEST_CANU" ]; then
    LATEST_OUTPUT=$SCRIPT_DIR/$LAST_LATEST_CANU.out
    if [ -f $LATEST_OUTPUT ]; then
      echo
      echo "INFO:  Latest log file contents ($LATEST_OUTPUT):"
      cat $LATEST_OUTPUT
    fi
    echo
    echo "INFO:  Current script is $LATEST_SCRIPT:"
    cat $LATEST_SCRIPT
    echo
    echo -n "INFO:  Processing"
    LAST_LATEST_CANU=$LATEST_CANU
  fi

  sleep 10

  echo -n "."

  QUEUE_LENGTH=$(qstat -f | grep "job_state" | grep -v "job_state = C" | wc -l)
  LATEST_QUEUE=$SCRIPT_DIR/$LATEST_CANU.qstat
  echo "$(date): QUEUE_LENGTH=$QUEUE_LENGTH" >>$LATEST_QUEUE
  scontrol show partition

  #    qstat -f >>$LATEST_QUEUE
  squeue >>$LATEST_QUEUE

  printf "%0.s*" {1..75} >>$LATEST_QUEUE
  echo >>$LATEST_QUEUE
  [ $QUEUE_LENGTH -eq 0 ] && echo && echo "INFO:  Queue is empty" && break
done

echo
printf "%0.s*" {1..75}
echo

LATEST_OUTPUT=$SCRIPT_DIR/$LATEST_CANU.out
echo
echo "INFO:  Last log file contents ($LATEST_OUTPUT):"
cat $LATEST_OUTPUT

echo
printf "%0.s*" {1..75}
echo

FAILED=$(grep -i "canu failed" $LATEST_OUTPUT)
if [ -n "$FAILED" ]; then
  echo "$FAILED" 1>&2
  echo "FATAL:  Error while running Canu job!" 1>&2
  ERROR_CODE=1

  echo "INFO:  scontrol show nodes output:"
  scontrol show nodes

  echo "INFO:  squeue output:"
  squeue
else
  echo "SUCCESS: Canu job finished!" 1>&2
  ERROR_CODE=0
fi

exit $ERROR_CODE
