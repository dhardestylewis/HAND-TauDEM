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
## Version: 3.1.2
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
#SBATCH -p long               # Queue name
#SBATCH -N 1                  # Total number of nodes requested (48 cores/node)
#SBATCH -n 68                 # Total number of mpi tasks requested
#SBATCH -t 120:00:00           # Run time (hh:mm:ss) - 2 hours
#SBATCH -A PT2050-DataX

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
#    echo "$TEMP"
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
        *)                args+=( "$arg" ) ;;
    esac
done

printf 'args before update : '; printf '%q ' "$@"; echo
set -- "${args[@]}"
printf 'args after update : '; printf '%q ' "$@"; echo

ARGS=""
while [ $# -gt 0 ]; do
    unset OPTIND
    unset OPTARG
    while getopts "j:i:s:p:" OPTION; do
        : "$OPTION" "$OPTARG"
        echo "optarg : $OPTARG"
        case $OPTION in
            j) JOBS="$OPTARG";;
            i) PATH_HAND_IMG="$(readlink -f $OPTARG)";;
            s) PATH_HAND_SH="$(readlink -f $OPTARG)";;
            p) PATH_HAND_PY="$(readlink -f $OPTARG)";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done
echo ARGS=$ARGS

echo jobs=$JOBS
echo path_hand_img=$PATH_HAND_IMG
echo path_hand_sh=$PATH_HAND_SH
echo path_hand_py=$PATH_HAND_PY
echo args=$args
echo arg=$arg
echo at=$@

module load tacc-singularity

echo singularity exec ${PATH_HAND_IMG} "${PATH_HAND_SH} -j $JOBS --path_hand_py ${PATH_HAND_PY} $ARGS"
singularity exec ${PATH_HAND_IMG} bash --noprofile --norc -c "${PATH_HAND_SH} -j $JOBS --path_hand_pys ${PATH_HAND_PY} $ARGS"
echo singularity exec ${PATH_HAND_IMG} bash
#singularity exec --cleanenv ${PATH_HAND_IMG} bash --noprofile --norc
