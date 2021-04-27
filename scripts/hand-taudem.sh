#!/bin/bash

## Usage: hand-taudem.sh 

## Workflow that returns height-above-nearest-drainage (HAND) from source data

## Author: Daniel Hardesty Lewis
## Copyright: Copyright 2020, Daniel Hardesty Lewis
## Credits: Daniel Hardesty Lewis
## License: GPLv3
## Version: 3.1.2
## Maintainer: Daniel Hardesty Lewis
## Email: dhl@tacc.utexas.edu
## Status: Production

## TODO: DEFAULT TIFF visualization
## TODO: PREPEND the preprocessing script
## TODO: Memory tests with parallelization


### POSIX variable reset in case getopts was used previously in this same shell
#OPTIND=1
#
### Default behaviour
#output_file=""
#verbose=false
#jobno=1
#
### Support long options
#for arg in "$@"; do
#    shift
#    case "$arg" in
#        "--help")
#            set -- "$@" "-h"
#            ;;
#        "--verbose")
#            set -- "$@" "-v"
#            ;;
#        "--jobs")
#            set -- "$@" "-j"
#            ;;
#        "--output_file")
#            set -- "$@" "-f"
#            ;;
#        *)
#            set -- "$@" "$arg"
#            ;;
#    esac
#done
#
#while getopts "h?jvf:" opt; do
#    case "$opt" in
#        h|\?)
#            show_help
#            exit 0
#            ;;
#        v)  verbose=true
#            ;;
#        j)  jobno=$(($OPTARG))
#            ;;
#        f)  output_file=$OPTARG
#            ;;
#    esac
#done
#
#shift $((OPTIND-1))
#
#[ "${1:-}" = "--" ] && shift
#

## Option parsing from
##  https://stackoverflow.com/a/7948533
#TEMP=$(getopt \
#    -o j: \
#    --long job:,path_hand_py: \
#    -- "$@")
#
#if [ $? != 0 ]; then echo "Terminating..." >&2 ; exit 1 ; fi
#
#eval set -- "$TEMP"

args=( )
for arg; do
    case "$arg" in
        --job )           args+=( -j ) ;;
        --path_hand_pys ) args+=( -s ) ;;
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
    while getopts "j:s:q:t:" OPTION; do
        : "$OPTION" "$OPTARG"
        case $OPTION in
            j) JOBS="$OPTARG";;
            s) PATH_HAND_PYS="$OPTARG";;
            q) QUEUE="$OPTARG";;
            t) START_TIME="$OPTARG";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done

#while true; do
#    case "$1" in
#        -j | --job ) JOBS="$2"; shift ;;
#        --path_hand_py ) PATH_HAND_PYS="$2"; shift ;;
#        -- ) shift ; break ;;
#        * ) ARG="$@"; break ;; #shift ; break ;;
#    esac
#    shift
#done

RUN_COMMANDS() {

    
    argument="$(readlink -f $1)"
    cd $(dirname -- "$argument")

    ## Properly initialise non-interactive shell
    eval "$(conda shell.bash hook)"
    

    if (
        [[ "${CONDA_PREFIX}" ]] && \
        [[ "${CONDA_PREFIX}" == *'/envs/'* ]] && \
        [[ ":${LD_LIBRARY_PATH}:" != *":${CONDA_PREFIX}/lib:"* ]]
    ); then
        export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||; s|:'"${CONDA_PREFIX}"'/lib:|:|; s|:'"${CONDA_PREFIX}"'/lib$||; q')
    fi
    if [[ "${CONDA_DEFAULT_ENV}" != 'hand' ]]; then
        if [[ "${CONDA_DEFAULT_ENV}" == 'base' ]]; then
            conda activate hand-libgdal
        elif [[ "${CONDA_DEFAULT_ENV}" ]]; then
            conda deactivate
            conda activate hand-libgdal
        else
            conda activate
            conda activate hand-libgdal
        fi
    fi
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"

    
    if [ ! -f demfel.tif ]; then
        pitremove -z $(basename -- "$argument") \
                  -fel demfel.tif &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,pitremove" hand-taudem.log
        wait ${pid}
    fi
    if [ ! -f demang.tif ] || \
       [ ! -f demslp.tif ]; then
        dinfflowdir -fel demfel.tif \
                    -ang demang.tif \
                    -slp demslp.tif &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,dinfflowdir" hand-taudem.log
        wait ${pid}
    fi
    if [ ! -f demp.tif ] || \
       [ ! -f demsd8.tif ]; then
        d8flowdir -fel demfel.tif \
                  -p demp.tif \
                  -sd8 demsd8.tif &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,d8flowdir" hand-taudem.log
        wait ${pid}
    fi
    if [ ! -f demad8.tif ]; then
        aread8 -p demp.tif \
               -ad8 demad8.tif \
               -nc &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,aread8" hand-taudem.log
        wait ${pid}
    fi
    if [ ! -f demsca.tif ]; then
        areadinf -ang demang.tif \
                 -sca demsca.tif \
                 -nc &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,areadinf" hand-taudem.log
        wait ${pid}
    fi
    
    ## Skeleton
    if [ ! -f demsa.tif ]; then
        slopearea -slp demslp.tif \
                  -sca demsca.tif \
                  -sa demsa.tif &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,slopearea" hand-taudem.log
        wait ${pid}
    fi
    if [ ! -f demssa.tif ]; then
        d8flowpathextremeup -p demp.tif \
                            -sa demsa.tif \
                            -ssa demssa.tif \
                            -nc &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,d8flowpathextremeup" hand-taudem.log
        wait ${pid}
    fi
    #python3 $PATH_HAND_PYS/hand-thresh.py --resolution demfel.tif --output demthresh.txt
    #threshold -ssa demssa.tif -src demsrc.tif -thresh $(cat demthresh.txt)
    if [ ! -f demsrc.tif ]; then
        threshold -ssa demssa.tif \
                  -src demsrc.tif \
                  -thresh 500.0 &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,threshold" hand-taudem.log
        wait ${pid}
    fi
    
    if [ ! -f demord.tif ] || \
       [ ! -f demtree.dat ] || \
       [ ! -f demcoord.dat ] || \
       [ ! -f demnet.shp ] || \
       [ ! -f demw.tif ]; then
        streamnet -fel demfel.tif \
                  -p demp.tif \
                  -ad8 demad8.tif \
                  -src demsrc.tif \
                  -ord demord.tif \
                  -tree demtree.dat \
                  -coord demcoord.dat \
                  -net demnet.shp \
                  -w demw.tif \
                  -sw &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,streamnet" hand-taudem.log
        wait ${pid}
    fi
    
    if [ ! -f outlets.shp ] || \
       [ ! -f movedoutlets.shp ]; then
        connectdown -p demp.tif \
                    -ad8 demad8.tif \
                    -w demw.tif \
                    -o outlets.shp \
                    -od movedoutlets.shp &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,connectdown" hand-taudem.log
        wait ${pid}
    fi
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-rasterio
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    if [ ! -f dangles.shp ]; then
        python3 $PATH_HAND_PYS/hand-heads.py --network demnet.shp \
                                             --output dangles.shp &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,hand-heads" hand-taudem.log
        wait ${pid}
    fi
    if [ ! -f demwg.tif ]; then
        python3 $PATH_HAND_PYS/hand-weights.py --shapefile dangles.shp \
                                               --template demfel.tif \
                                               --output demwg.tif &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,hand-weights" hand-taudem.log
        wait ${pid}
    fi
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-libgdal
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    if [ ! -f demssa.tif ]; then
        aread8 -p demp.tif \
               -ad8 demssa.tif \
               -o outlets.shp \
               -wg demwg.tif \
               -nc &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,aread8" hand-taudem.log
        wait ${pid}
    fi
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-rasterio
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    if [ ! -f demthreshmin.txt ]; then
        python3 $PATH_HAND_PYS/hand-threshmin.py --resolution demfel.tif \
                                                 --output demthreshmin.txt &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,hand-threshmin" hand-taudem.log
        wait ${pid}
    fi
    if [ ! -f demthreshmax.txt ]; then
        python3 $PATH_HAND_PYS/hand-threshmax.py --accumulation demssa.tif \
                                                 --output demthreshmax.txt &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,hand-threshmax" hand-taudem.log
        wait ${pid}
    fi
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-libgdal
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    if [ ! -f demdrp.txt ]; then
        dropanalysis -ad8 demad8.tif \
                     -p demp.tif \
                     -fel demfel.tif \
                     -ssa demssa.tif \
                     -o outlets.shp \
                     -drp demdrp.txt \
                     -par $(cat demthreshmin.txt) $(cat demthreshmax.txt) 10 0 &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,dropanalysis" hand-taudem.log
        wait ${pid}
    fi
    if [ ! -f demsrc.tif ]; then
        threshold -ssa demssa.tif \
                  -src demsrc.tif \
                  -thresh $(tail -n 1 demdrp.txt | awk '{print $NF}') &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,threshold" hand-taudem.log
        wait ${pid}
    fi
    
    filename=$(basename -- "$argument")
    filename="${filename%.*}"

    if [ ! -f ${filename}dd.tif ]; then
        dinfdistdown -ang demang.tif \
                     -fel demfel.tif \
                     -src demsrc.tif \
                     -wg demwg.tif \
                     -dd "${filename}dd.tif" \
                     -m ave v \
                     -nc &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,dinfdistdown" hand-taudem.log
        wait ${pid}
    fi
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-rasterio
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    if [ ! -f ${filename}dd-vis.tif ] || \
       [ ! -f ${filename}dd-vis.shp ] || \
       [ ! -f ${filename}dd-vis.json ]; then
        python3 $PATH_HAND_PYS/hand-vis.py --input "${filename}dd.tif" \
                                           --binmethod 'lin' \
                                           --raster "${filename}dd-vis.tif" \
                                           --shapefile "${filename}dd-vis.shp" \
                                           --geojson "${filename}dd-vis.json" &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,hand-vis" hand-taudem.log
        wait ${pid}
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,True,hand-vis" hand-taudem.log
    fi
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate

}

export -f RUN_COMMANDS

if [[ -z "${PATH_HAND_PYS}" ]]; then
    export PATH_HAND_PYS="$(pwd)"
fi

NPROC=$(($(grep -c ^processor /proc/cpuinfo) - 1))
if [ $JOBS -gt $NPROC ]; then
    JOBS=$NPROC
fi
if [ $JOBS -eq 1 ]; then
    for argument in $ARGS; do
#        shift
        RUN_COMMANDS "$(readlink -f $argument)"
    done
else
    export PATH_HAND_PYS
    parallel --will-cite -j $JOBS -k --ungroup RUN_COMMANDS ::: $ARGS
fi

