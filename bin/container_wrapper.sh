#!/bin/bash

## Usage:
##  ibrun -np 67 singularity run ${SCRATCH}/hand_taudem_docker_tacc.sif ${PATH_TASK_PROC}/container_wrapper.sh --environment hand-libgdal --command "pitremove -z $argument -fel demfel.tif" &

## wrapper around commands to ensure they execute
##  in the proper conda environment
##  within a Singularity container 

## Author: Daniel Hardesty Lewis
## Copyright: Copyright 2021, Daniel Hardesty Lewis
## Credits: Daniel Hardesty Lewis
## License: GPLv3
## Version: 1.0.0
## Maintainer: Daniel Hardesty Lewis
## Email: dhl@tacc.utexas.edu
## Status: Production


args=( )
for arg; do
    case "$arg" in
        --job )              args+=( -j ) ;;
        --environment )      args+=( -e ) ;;
        --path_image )       args+=( -i ) ;;
        --command )          args+=( -c ) ;;
        *)                   args+=( "$arg" ) ;;
    esac
done

set -- "${args[@]}"

ARGS=""
while [ $# -gt 0 ]; do
    unset OPTIND
    unset OPTARG
    while getopts "j:e:i:c:" OPTION; do
        : "$OPTION" "$OPTARG"
        case $OPTION in
            j) JOBS="$OPTARG";;
            e) ENVIRONMENT="$OPTARG";;
            i) PATH_IMAGE="$(readlink -f $OPTARG)";;
            c) COMMAND="$OPTARG";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done


eval "$(conda shell.bash hook)"
conda activate "${ENVIRONMENT}"
eval "${COMMAND}"
conda deactivate


