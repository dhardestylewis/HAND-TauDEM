#!/bin/bash


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


