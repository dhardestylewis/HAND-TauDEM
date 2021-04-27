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

##------------------------------------------------------------------------------
##------- You normally should not need to edit anything below this point -------
##------------------------------------------------------------------------------


args=( )
for arg; do
    case "$arg" in
        --job )                   args+=( -j ) ;;
        --path_hand_img )         args+=( -i ) ;;
        --path_hand_sh )          args+=( -s ) ;;
        --path_hand_log )         args+=( -l ) ;;
        --path_hand_cmds )        args+=( -c ) ;;
        --path_hand_cmd_outputs ) args+=( -o ) ;;
        --path_hand_rc )          args+=( -r ) ;;
        --queue )                 args+=( -q ) ;;
        --start_time )            args+=( -t ) ;;
        *)                        args+=( "$arg" ) ;;
    esac
done

set -- "${args[@]}"

ARGS=""
while [ $# -gt 0 ]; do
    unset OPTIND
    unset OPTARG
    while getopts "j:i:s:l:c:o:r:q:t:" OPTION; do
        : "$OPTION" "$OPTARG"
        case $OPTION in
            j) JOBS="$OPTARG";;
            i) PATH_HAND_IMG="$(readlink -f $OPTARG)";;
            s) PATH_HAND_SH="$(readlink -f $OPTARG)";;
            l) PATH_HAND_LOG="$OPTARG";;
            c) PATH_HAND_CMDS="$(readlink -f $OPTARG)";;
            o) PATH_HAND_CMD_OUTPUTS="$(readlink -f $OPTARG)";;
            r) PATH_HAND_RC="$(readlink -f $OPTARG)";;
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
                 -c "${PATH_HAND_SH} -j $JOBS --queue ${QUEUE} --start_time ${START_TIME} --path_hand_rc ${PATH_HAND_RC} --path_hand_cmds ${PATH_HAND_CMDS} --path_hand_cmd_outputs ${PATH_HAND_CMD_OUTPUTS} --path_hand_log ${PATH_HAND_LOG} $ARGS"


