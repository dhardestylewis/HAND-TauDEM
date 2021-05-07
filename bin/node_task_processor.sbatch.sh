#!/bin/bash
##
##------------------------------------------------------------------------------
## Usage: sbatch node_task_processor.sbatch.sh --job 1 --path_img hand_taudem_singularity_image.sif --path_sh bin/node_task_processor.sh --path_log hand_taudem.log --path_cmds bin/workflow_commands-hand_taudem.sh --path_cmd_outputs bin/workflow_outputs-hand_taudem.txt --path_rc bin/workflow_configuration-hand_taudem.sh --queue development --start_time $(date -u +%s) HUC1 HUC2 HUC3
##
## 
##
## Author: Daniel Hardesty Lewis
## Copyright: Copyright 2021, Daniel Hardesty Lewis
## Credits: Daniel Hardesty Lewis
## License: GPLv3
## Version: 1.0.0
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
#SBATCH -t 48:00:00           # Run time (hh:mm:ss) - 2 hours
#SBATCH -A PT2050-DataX
#SBATCH --reservation PT2050

##------------------------------------------------------------------------------
##------- You normally should not need to edit anything below this point -------
##------------------------------------------------------------------------------


args=( )
for arg; do
    case "$arg" in
        --job )                   args+=( -j ) ;;
        --path_img )         args+=( -i ) ;;
        --path_sh )          args+=( -s ) ;;
        --path_log )         args+=( -l ) ;;
        --path_cmds )        args+=( -c ) ;;
        --path_cmd_outputs ) args+=( -o ) ;;
        --path_rc )          args+=( -r ) ;;
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
            i) PATH_IMG="$(readlink -f $OPTARG)";;
            s) PATH_SH="$(readlink -f $OPTARG)";;
            l) PATH_LOG="$OPTARG";;
            c) PATH_CMDS="$(readlink -f $OPTARG)";;
            o) PATH_CMD_OUTPUTS="$(readlink -f $OPTARG)";;
            r) PATH_RC="$(readlink -f $OPTARG)";;
            q) QUEUE="$OPTARG";;
            t) START_TIME="$OPTARG";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done


module load tacc-singularity

#singularity exec ${PATH_IMG} \
bash --noprofile \
     --norc \
     -c "${PATH_SH} -j $JOBS --queue ${QUEUE} --start_time ${START_TIME} --path_rc ${PATH_RC} --path_cmds ${PATH_CMDS} --path_cmd_outputs ${PATH_CMD_OUTPUTS} --path_log ${PATH_LOG} $ARGS"


