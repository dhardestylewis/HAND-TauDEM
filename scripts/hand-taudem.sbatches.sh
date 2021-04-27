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


##------------------------------------------------------------------------------
##------- You normally should not need to edit anything below this point -------
##------------------------------------------------------------------------------

args=( )
for arg; do
    case "$arg" in
        --path_hand_taskproc ) args+=( -t ) ;;
        --job )                args+=( -j ) ;;
        --path_hand_sbatch )   args+=( -b ) ;;
        --path_hand_img )      args+=( -i ) ;;
        --path_hand_sh )       args+=( -s ) ;;
        --path_hand_py )       args+=( -p ) ;;
        --minutes )            args+=( -m ) ;;
        *)                     args+=( "$arg" ) ;;
    esac
done

set -- "${args[@]}"

ARGS=""
while [ $# -gt 0 ]; do
    unset OPTIND
    unset OPTARG
    while getopts "t:j:b:i:s:p:m:" OPTION; do
        : "$OPTION" "$OPTARG"
        case $OPTION in
            t) PATH_HAND_TASKPROC="$(readlink -f $OPTARG)";;
            j) JOBS="$OPTARG";;
            b) PATH_HAND_SBATCH="$(readlink -f $OPTARG)";;
            i) PATH_HAND_IMG="$(readlink -f $OPTARG)";;
            s) PATH_HAND_SH="$(readlink -f $OPTARG)";;
            p) PATH_HAND_PY="$(readlink -f $OPTARG)";;
            m) MINUTES="$OPTARG";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done


python3 ${PATH_HAND_TASKPROC} --path_hand_sbatch ${PATH_HAND_SBATCH} \
                              -j ${JOBS} \
                              --path_hand_img ${PATH_HAND_IMG} \
                              --path_hand_sh ${PATH_HAND_SH} \
                              --path_hand_py ${PATH_HAND_PY} \
                              --minutes ${MINUTES} \
                              $ARGS


