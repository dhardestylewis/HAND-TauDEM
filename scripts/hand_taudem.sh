#!/bin/bash

## Usage: hand-taudem.sh 

## Workflow that returns height-above-nearest-drainage (HAND) from source data

## Author: Daniel Hardesty Lewis
## Copyright: Copyright 2020, Daniel Hardesty Lewis
## Credits: Daniel Hardesty Lewis
## License: GPLv3
## Version: 3.2.0
## Maintainer: Daniel Hardesty Lewis
## Email: dhl@tacc.utexas.edu
## Status: Production

## TODO: DEFAULT TIFF visualization
## TODO: PREPEND the preprocessing script
## TODO: Memory tests with parallelization


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


RUN_COMMAND() {

    outputs=$1
    output_exists=false
    for output in "${outputs[@]}"; do
        echo output
        echo $output
        if [ ! -f $output ]; then
            output_exists=false
            break
        fi
        echo output_exists
        echo $output_exists
    done

    if ! $output_exists; then
        RUN_CMD &
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,$cmd_run" hand-taudem.log
        wait ${pid}
    fi

}


CONDA_ACTIVATE() {

    export LD_LIBRARY_PATH=$(
        echo "${LD_LIBRARY_PATH}" |
        sed -E 's|^'"${CONDA_PREFIX}"'/lib:||'
    )
    conda deactivate
    conda activate $1
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"

}


RUN_COMMANDS() {


    echo 1
    echo $1
    argument="$(readlink -f $1)"
    cd $(dirname -- "$argument")
    echo pwd
    echo $(pwd)

    ## Properly initialise non-interactive shell
    eval "$(conda shell.bash hook)"


    if (
        [[ "${CONDA_PREFIX}" ]] && \
        [[ "${CONDA_PREFIX}" == *'/envs/'* ]] && \
        [[ ":${LD_LIBRARY_PATH}:" != *":${CONDA_PREFIX}/lib:"* ]]
    ); then
        export LD_LIBRARY_PATH=$(
            echo "${LD_LIBRARY_PATH}" | 
            sed -E 's|^'"${CONDA_PREFIX}"'/lib:||; s|:'"${CONDA_PREFIX}"'/lib:|:|; s|:'"${CONDA_PREFIX}"'/lib$||; q'
        )
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


    if [ ! -f hand-taudem.log ]; then
        RUN_CMD() {
            touch hand-taudem.log
        }
        RUN_CMD &
        pid=$!
        start_time=$(date -u +%s)
        cmd_run=':'
        echo "index,pid,start_time,queue,elapsed_time,error_long_queue_timeout,complete,last_cmd" > hand-taudem.log
        sed -i -e "1a${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,$cmd_run" hand-taudem.log
        wait ${pid}
    fi


    declare -a outputs=("demfel.tif")
    RUN_CMD() {
        pitremove -z $(basename -- "$argument") \
                  -fel demfel.tif
    }
    cmd_run='pitremove'
    RUN_COMMAND $outputs

    declare -a outputs=("demang.tif" "demslp.tif")
    RUN_CMD() {
        dinfflowdir -fel demfel.tif \
                    -ang demang.tif \
                    -slp demslp.tif
    }
    cmd_run='dinfflowdir'
    RUN_COMMAND $outputs

    declare -a outputs=("demp.tif" "demsd8.tif")
    RUN_CMD() {
        d8flowdir -fel demfel.tif \
                  -p demp.tif \
                  -sd8 demsd8.tif
    }
    cmd_run='d8flowdir'
    RUN_COMMAND $outputs

    declare -a outputs=("demad8.tif")
    RUN_CMD() {
        aread8 -p demp.tif \
               -ad8 demad8.tif \
               -nc
    }
    cmd_run='aread8'
    RUN_COMMAND $outputs

    declare -a outputs=("demsca.tif")
    RUN_CMD() {
        areadinf -ang demang.tif \
                 -sca demsca.tif \
                 -nc
    }
    cmd_run='areadinf'
    RUN_COMMAND $outputs

    ## Skeleton
    declare -a outputs=("demsa.tif")
    RUN_CMD() {
        slopearea -slp demslp.tif \
                  -sca demsca.tif \
                  -sa demsa.tif
    }
    cmd_run='slopearea'
    RUN_COMMAND $outputs

    declare -a outputs=("demssa.tif")
    RUN_CMD() {
        d8flowpathextremeup -p demp.tif \
                            -sa demsa.tif \
                            -ssa demssa.tif \
                            -nc
    }
    cmd_run='d8flowpathextremeup'
    RUN_COMMAND $outputs

#    declare -a outputs=("demthresh.txt")
#    RUN_CMD() {
#        python3 $PATH_HAND_PYS/hand-thresh.py --resolution demfel.tif \
#                                              --output demthresh.txt
#    }
#    cmd_run='hand-thesh.py'
#    RUN_COMMAND $outputs

    declare -a outputs=("demsrc.tif")
    RUN_CMD() {
        threshold -ssa demssa.tif \
                  -src demsrc.tif \
                  -thresh 500.0
                  #-thresh $(cat demthresh.txt)
    }
    cmd_run='threshold'
    RUN_COMMAND $outputs

    declare -a outputs=(
        "demord.tif"
        "demtree.dat"
        "demcoord.dat"
        "demnet.shp"
        "demw.tif"
    )
    RUN_CMD() {
        streamnet -fel demfel.tif \
                  -p demp.tif \
                  -ad8 demad8.tif \
                  -src demsrc.tif \
                  -ord demord.tif \
                  -tree demtree.dat \
                  -coord demcoord.dat \
                  -net demnet.shp \
                  -w demw.tif \
                  -sw
    }
    cmd_run='streamnet'
    RUN_COMMAND $outputs

    CONDA_ACTIVATE 'hand-rasterio'

    declare -a outputs=("outlets.shp")
    RUN_CMD() {
        python3 $PATH_HAND_PYS/hand-tail.py --aread8 demad8.tif \
                                            --output outlets.shp
    }
    cmd_run='hand-tail.py'
    RUN_COMMAND $outputs

    declare -a outputs=("dangles.shp")
    RUN_CMD() {
        python3 $PATH_HAND_PYS/hand-heads.py --network demnet.shp \
                                             --output dangles.shp
    }
    cmd_run='hand-heads.py'
    RUN_COMMAND $outputs

    declare -a outputs=("demwg.tif")
    RUN_CMD() {
        python3 $PATH_HAND_PYS/hand-weights.py --shapefile dangles.shp \
                                               --template demfel.tif \
                                               --output demwg.tif
    }
    cmd_run='hand-weights.py'
    RUN_COMMAND $outputs

    CONDA_ACTIVATE 'hand-libgdal'

    declare -a outputs=("demssa.tif")
    RUN_CMD() {
        aread8 -p demp.tif \
               -ad8 demssa.tif \
               -o outlets.shp \
               -wg demwg.tif \
               -nc
    }
    cmd_run='aread8'
    RUN_COMMAND $outputs

    CONDA_ACTIVATE 'hand-rasterio'

    declare -a outputs=("demthreshmin.txt")
    RUN_CMD() {
        python3 $PATH_HAND_PYS/hand-threshmin.py --resolution demfel.tif \
                                                 --output demthreshmin.txt
    }
    cmd_run='hand-threshmin.py'
    RUN_COMMAND $outputs

    declare -a outputs=("demthreshmax.txt")
    RUN_CMD() {
        python3 $PATH_HAND_PYS/hand-threshmax.py --accumulation demssa.tif \
                                                 --output demthreshmax.txt
    }
    cmd_run='hand-threshmax.py'
    RUN_COMMAND $outputs

    CONDA_ACTIVATE 'hand-libgdal'

    declare -a outputs=("demdrp.txt")
    RUN_CMD() {
        dropanalysis -ad8 demad8.tif \
                     -p demp.tif \
                     -fel demfel.tif \
                     -ssa demssa.tif \
                     -o outlets.shp \
                     -drp demdrp.txt \
                     -par $(cat demthreshmin.txt) $(cat demthreshmax.txt) 10 0
    }
    cmd_run='dropanalysis'
    RUN_COMMAND $outputs

    declare -a outputs=("demsrc.tif")
    RUN_CMD() {
        threshold -ssa demssa.tif \
                  -src demsrc.tif \
                  -thresh $(tail -n 1 demdrp.txt | awk '{print $NF}')
    }
    cmd_run='threshold'
    RUN_COMMAND $outputs

    filename=$(basename -- "$argument")
    filename="${filename%.*}"

    declare -a outputs=("${filename}dd.tif")
    RUN_CMD() {
        dinfdistdown -ang demang.tif \
                     -fel demfel.tif \
                     -src demsrc.tif \
                     -wg demwg.tif \
                     -dd "${filename}dd.tif" \
                     -m ave v \
                     -nc
    }
    cmd_run='dinfdistdown'
    RUN_COMMAND $outputs

    CONDA_ACTIVATE 'hand-rasterio'

    declare -a outputs=(
        "${filename}dd-vis.tif"
        "${filename}dd-vis.shp"
        "${filename}dd-vis.json"
    )
    RUN_CMD() {
        python3 $PATH_HAND_PYS/hand-vis.py \
            --input "${filename}dd.tif" \
            --binmethod 'lin' \
            --raster "${filename}dd-vis.tif" \
            --shapefile "${filename}dd-vis.shp" \
            --geojson "${filename}dd-vis.json" &
    }
    cmd_run='hand-vis.py'
    RUN_COMMAND $outputs

    declare -a outputs=(
        "${filename}dd-vis.tif"
        "${filename}dd-vis.shp"
        "${filename}dd-vis.json"
    )
    RUN_CMD() {
        :
    }
    cmd_run=':'
    RUN_COMMAND $outputs

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
echo ARGS
echo $ARGS
if [ $JOBS -eq 1 ]; then
    for argument in $ARGS; do
#        shift
        echo argument
        echo $argument
        RUN_COMMANDS $argument
    done
else
    export PATH_HAND_PYS
    parallel --will-cite -j $JOBS -k --ungroup RUN_COMMANDS ::: $ARGS
fi

