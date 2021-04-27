#!/bin/bash
##
##------------------------------------------------------------------------------
## Usage: hand-taudem.sh
##
## Workflow that returns height-above-nearest-drainage (HAND) from source data  
## Author: Daniel Hardesty Lewis
## Copyright: Copyright 2020, Daniel Hardesty Lewis
## Credits: Daniel Hardesty Lewis
## License: GPLv3
## Version: 3.1.4
## Maintainer: Daniel Hardesty Lewis
## Email: dhl@tacc.utexas.edu
## Status: Production
##
## This Stampede-2 job script is designed to create a HAND-TauDEM session on 
## KNL long nodes through the SLURM batch system. Once the job
## is scheduled, check the output of your job (which by default is
## stored in your home directory in a file named hand-taudem.out)
##
## Aspects of this scripts were incorporated from `job.vnc`
##  located at /share/doc/slurm/job.vnc on stampede2.tacc.utexas.edu
##
## Note: you can fine tune the SLURM submission variables below as
## needed.  Typical items to change are the runtime limit, location of
## the job output, and the allocation project to submit against (it is
## commented out for now, but is required if you have multiple
## allocations).  
##
## To submit the job, issue: "sbatch hand-taudem.sbatch.sh" 
##
## For more information, please consult the User Guide at: 
##
## https://portal.tacc.utexas.edu/user-guides/stampede2
##-----------------------------------------------------------------------------
##
#SBATCH -J hand-taudem.j%j    # Job name
#SBATCH -o hand-taudem.o%j    # Name of stdout output file (%j expands to jobId)
#SBATCH -e hand-taudem.e%j    # Name of stderr error file (%j expands to jobId)
#SBATCH -p skx-normal         # Queue name
#SBATCH -N 1                  # Total number of nodes requested (48 cores/node)
#SBATCH -n 48                 # Total number of mpi tasks requested
#SBATCH -t 48:00:00          # Run time (hh:mm:ss) - 2 hours
#SBATCH -A PT2050-DataX

echo ${SLURM_JOB_ID}

##------------------------------------------------------------------------------
##------- You normally should not need to edit anything below this point -------
##------------------------------------------------------------------------------

#TEMP=$(getopt \
#    -o j: \
#    --long job:,\
#           path_hand_img:,\
#           path_hand_sh:,\
#           path_hand_py: \
#    -- "$@")
#
#if [ $? != 0 ]; then echo "Terminating..." >&2 ; exit 1 ; fi
#
#eval set -- "$TEMP"
#
#JOBS=1
#PATH_HAND_IMG=
#PATH_HAND_SH=
#PATH_HAND_PY=
#while true; do
#    case "$1" in
#        -- ) shift ; break ;;
#        -j | --job ) JOBS="$2"; shift ;;
#        --path_hand_img ) PATH_HAND_IMG="$2"; shift ;;
#        --path_hand_sh ) PATH_HAND_SH="$2"; shift ;;
#        --path_hand_py ) PATH_HAND_PY="$2"; shift ;;
#        * ) ARG="$@"; shift ; break ;;
#    esac
#    shift
#done

args=( )
for arg; do
    case "$arg" in
        --job )           args+=( -j ) ;;
        --path_hand_img ) args+=( -i ) ;;
        --path_hand_sh )  args+=( -s ) ;;
        --path_hand_py )  args+=( -p ) ;;
        --path_hand_log ) args+=( -l ) ;;
        --queue )         args+=( -q ) ;;
        --start_time )    args+=( -t ) ;;
        *)                args+=( "$arg" ) ;;
    esac
done

set -- "${args[@]}"

ARGS=""
while [ $# -gt 0 ]; do
    unset OPTIND
    unset OPTARG
    while getopts "j:i:s:p:l:q:t:" OPTION; do
        : "$OPTION" "$OPTARG"
        case $OPTION in
            j) JOBS="$OPTARG";;
            i) PATH_HAND_IMG="$OPTARG";;
            s) PATH_HAND_SH="$OPTARG";;
            p) PATH_HAND_PY="$OPTARG";;
            l) PATH_HAND_LOG="$OPTARG";;
            q) QUEUE="$OPTARG";;
            t) START_TIME="$OPTARG";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done


module load tacc-singularity

singularity exec ${PATH_HAND_IMG} \
            bash --noprofile \
                 --norc \
                 -c "${PATH_HAND_SH} -j $JOBS --path_hand_pys ${PATH_HAND_PY} --queue ${QUEUE} --start_time ${START_TIME} $ARGS"
#singularity exec --cleanenv ${PATH_HAND_IMG} bash --noprofile --norc


