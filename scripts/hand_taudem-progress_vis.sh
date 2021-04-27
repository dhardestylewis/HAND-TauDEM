#!/bin/bash


args=( )
for arg; do
    case "$arg" in
        --path_wd )          args+=( -w ) ;;
        --path_log )         args+=( -l ) ;;
        --prefix_watershed ) args+=( -p ) ;;
        --path_cp )          args+=( -c ) ;;
        * )                  args+=( "$arg" ) ;;
    esac
done

set -- "${args[@]}"

ARGS=""
while [ $# -gt 0 ]; do
    unset OPTIND
    unset OPTARG
    while getopts "w:l:p:c:" OPTION; do
        : "$OPTION" "$OPTARG"
        case $OPTION in
            w) PATH_WD="$(readlink -f $OPTARG)";;
            l) PATH_LOG="$OPTARG";;
            p) PREFIX_WATERSHED="$OPTARG";;
            c) PATH_CP="$(readlink -f $OPTARG)";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done


cd $PATH_WD

LOGS=$(find . | grep $PATH_LOG)

LOG_DIRECTORIES=$(for filename in $LOGS; do
    dirname $filename
done | uniq)
for directory in $LOG_DIRECTORIES; do
    mkdir -p $PATH_CP/$directory
done

for filename in $LOGS; do
    cp $filename $PATH_CP/$filename
done

WATERSHEDS=$(for filename in $LOGS; do
    ls $(dirname $filename)/$PREFIX_WATERSHED.*
done)
for catchment in $WATERSHEDS; do
    cp $catchment $PATH_CP/$catchment
done


#cd /scratch/projects/tnris/dhl-flood-modelling/
#for directory in $(for filename in $(find . | grep hand-taudem.log); do dirname $filename; done | uniq); do mkdir -p /scratch/04950/dhl/HAND-TauDEM/regions/Texas/TWDB-Basins/$directory; done
#for filename in $(find . | grep hand-taudem.log); do cp $filename /scratch/04950/dhl/HAND-TauDEM/regions/Texas/TWDB-Basins/$filename; done
#for catchment in $(for filename in $(find . | grep hand-taudem.log); do ls $(dirname $filename)/Catchments.*; done); do cp $catchment /scratch/04950/dhl/HAND-TauDEM/regions/Texas/TWDB-Basins/$catchment; done


