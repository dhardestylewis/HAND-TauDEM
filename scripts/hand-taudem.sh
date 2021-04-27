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
#echo "verbose=$verbose, output_file='$output_file', Leftovers: $@"

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
        *)                args+=( "$arg" ) ;;
    esac
done

printf 'args before update : '; printf '%q ' "$@"; echo
set -- "${args[@]}"
printf 'args before update : '; printf '%q ' "$@"; echo

ARGS=""
while [ $# -gt 0 ]; do
    unset OPTIND
    unset OPTARG
    while getopts "j:s:" OPTION; do
        : "$OPTION" "$OPTARG"
        echo "optarg : $OPTARG"
        case $OPTION in
            j) JOBS="$OPTARG";;
            s) PATH_HAND_PYS="$OPTARG";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done
echo ARGS=$ARGS

#while true; do
#    case "$1" in
#        -j | --job ) JOBS="$2"; shift ;;
#        --path_hand_py ) PATH_HAND_PYS="$2"; shift ;;
#        -- ) shift ; break ;;
#        * ) ARG="$@"; break ;; #shift ; break ;;
#    esac
#    shift
#done
echo JOBS="$JOBS"
echo PATH_HAND_PYS="$PATH_HAND_PYS"
echo args=$args
echo arg=$arg
echo at=$@

RUN_COMMANDS() {

    #echo "$1"
    
    echo arg1=$1
    argument="$(readlink -f $1)"
    cd $(dirname -- "$argument")

    ## Properly initialise non-interactive shell
    eval "$(conda shell.bash hook)"
    
    echo PATH_after_parallel=$PATH
    echo LD_LIBRARY_PATH_after_parallel=$LD_LIBRARY_PATH
    echo TEST_PATH_after_parallel=$TEST_PATH
    echo PATH_HAND_PYS_after_parallel=$PATH_HAND_PYS
    echo pwd=$(pwd)
    echo ls=$(ls)

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
    echo export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"

    echo $(pwd)
    echo $(basename -- "$argument")
    
    echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH
    pitremove -z $(basename -- "$argument") -fel demfel.tif
    dinfflowdir -fel demfel.tif -ang demang.tif -slp demslp.tif
    d8flowdir -fel demfel.tif -p demp.tif -sd8 demsd8.tif
    aread8 -p demp.tif -ad8 demad8.tif -nc
    areadinf -ang demang.tif -sca demsca.tif -nc
    
    ## Skeleton
    slopearea -slp demslp.tif -sca demsca.tif -sa demsa.tif
    d8flowpathextremeup -p demp.tif -sa demsa.tif -ssa demssa.tif -nc
    #python3 $PATH_HAND_PYS/hand-thresh.py --resolution demfel.tif --output demthresh.txt
    #threshold -ssa demssa.tif -src demsrc.tif -thresh $(cat demthresh.txt)
    threshold -ssa demssa.tif -src demsrc.tif -thresh 500.0
    
    streamnet -fel demfel.tif -p demp.tif -ad8 demad8.tif -src demsrc.tif -ord demord.tif -tree demtree.dat -coord demcoord.dat -net demnet.shp -w demw.tif -sw
    
    connectdown -p demp.tif -ad8 demad8.tif -w demw.tif -o outlets.shp -od movedoutlets.shp
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-rasterio
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    python3 $PATH_HAND_PYS/hand-heads.py --network demnet.shp --output dangles.shp
    python3 $PATH_HAND_PYS/hand-weights.py --shapefile dangles.shp --template demfel.tif --output demwg.tif
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-libgdal
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    aread8 -p demp.tif -ad8 demssa.tif -o outlets.shp -wg demwg.tif -nc
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-rasterio
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    python3 $PATH_HAND_PYS/hand-threshmin.py --resolution demfel.tif --output demthreshmin.txt
    python3 $PATH_HAND_PYS/hand-threshmax.py --accumulation demssa.tif --output demthreshmax.txt
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-libgdal
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    dropanalysis -ad8 demad8.tif -p demp.tif -fel demfel.tif -ssa demssa.tif -o outlets.shp -drp demdrp.txt -par $(cat demthreshmin.txt) $(cat demthreshmax.txt) 10 0
    threshold -ssa demssa.tif -src demsrc.tif -thresh $(tail -n 1 demdrp.txt | awk '{print $NF}')
    
    filename=$(basename -- "$argument")
    filename="${filename%.*}"

    dinfdistdown -ang demang.tif -fel demfel.tif -src demsrc.tif -wg demwg.tif -dd "${filename}dd.tif" -m ave v -nc
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate
    conda activate hand-rasterio
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"
    
    python3 $PATH_HAND_PYS/hand-vis.py --input "${filename}dd.tif" --binmethod 'lin' --raster "${filename}dd-vis.tif" --shapefile "${filename}dd-vis.shp" --geojson "${filename}dd-vis.json"
    
    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate

}

export -f RUN_COMMANDS

if [[ -z "${PATH_HAND_PYS}" ]]; then
    export PATH_HAND_PYS="$(pwd)"
fi
echo PATH_HAND_PYS_after_export=$PATH_HAND_PYS

NPROC=$(($(grep -c ^processor /proc/cpuinfo) - 1))
if [ $JOBS -gt $NPROC ]; then
    JOBS=$NPROC
fi
if [ $JOBS -eq 1 ]; then
    echo ARGS_before_nonparallel="$ARGS"
    for argument in $ARGS; do
         echo argument_nonparallel=$argument
#        shift
        RUN_COMMANDS "$(readlink -f $argument)"
    done
else
    echo hand_taudem.sh-parallel_at=$@
    echo hand_taudem.sh-parallel_arg=$arg
    echo PATH_before_parallel=$PATH
    echo LD_LIBRARY_PATH_before_parallel=$LD_LIBRARY_PATH
    export TEST_PATH='test'
    echo TEST_PATH_before_parallel=$TEST_PATH
    export PATH_HAND_PYS
    echo ARGS_before_parallel="$ARGS"
    parallel --will-cite -j $JOBS -k --ungroup RUN_COMMANDS ::: $ARGS
fi

