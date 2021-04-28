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
        --job )                   args+=( -j ) ;;
        --queue )                 args+=( -q ) ;;
        --path_hand_cmds )        args+=( -c ) ;;
        --path_hand_cmd_outputs ) args+=( -o ) ;;
        --path_hand_log )         args+=( -l ) ;;
        --path_hand_rc )          args+=( -r ) ;;
        --start_time )            args+=( -t ) ;;
        *)                        args+=( "$arg" ) ;;
    esac
done

set -- "${args[@]}"

ARGS=""
while [ $# -gt 0 ]; do
    unset OPTIND
    unset OPTARG
    while getopts "j:q:c:o:l:r:t:" OPTION; do
        : "$OPTION" "$OPTARG"
        case $OPTION in
            j) JOBS="$OPTARG";;
            q) QUEUE="$OPTARG";;
            c) PATH_HAND_CMDS="$(readlink -f $OPTARG)";;
            o) PATH_HAND_CMD_OUTPUTS="$(readlink -f $OPTARG)";;
            l) PATH_HAND_LOG="$OPTARG";;
            r) PATH_HAND_RC="$(readlink -f $OPTARG)";;
            t) START_TIME="$OPTARG";;
        esac
    done
    shift $((OPTIND-1))
    ARGS="${ARGS} $1 "
    shift
done


INITIATE_LOG() {

    cmd="touch $1 &"
    eval "$cmd"
    pid=$!
    start_time=$(date -u +%s)
    cmd_run='touch'
    echo "index,pid,start_time,queue,elapsed_time,error_long_queue_timeout,complete,last_cmd,exit_code" > $1
    sed -i -e "1a${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,${cmd_run}," $1
    wait ${pid}
    exitcode="$?"
    sed -i -e "2s/$/${exitcode}/" $1

}


LOG_COMPLETION() {

    cmd="touch $1 &"
    eval "$cmd"
    pid=$!
    start_time=$(date -u +%s)
    cmd_run='touch'
    sed -i -e "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,True,${cmd_run}," $1
    wait ${pid}
    exitcode="$?"
    sed -i -e "2s/$/${exitcode}/" $1

}


RUN_COMMAND() {

    name=$(eval "echo $2")
    IFS=',' read -r -a outputs <<< "${name}"
    output_exists=true
    if [ ${#outputs[@]} -eq 0 ]; then
        outputs=($(mktemp /tmp/tmp.XXXXXX))
        rm "${outputs[0]}"
    fi
    for output in "${outputs[@]}"; do
        if [ ! -f $output ]; then
            output_exists=false
            break
        fi
    done

    if ! $output_exists; then
        eval "$cmd"
        pid=$!
        start_time=$(date -u +%s)
        sed -i "2i${start_time}${pid},${pid},${start_time},${QUEUE},$((${start_time} - ${START_TIME})),False,False,${cmd_run}," $1
        wait ${pid}
        exitcode="$?"
        sed -i -e "2s/$/${exitcode}/" $1
    fi

}


RUN_COMMANDS() {

    argument="$(readlink -f $1)"
    cd $(dirname -- "$argument")
    argument=$(basename -- "$argument")
    filename="${argument%.*}"

    ## Source environment before initiating children
    source $PATH_HAND_RC
    if [ ! -f $PATH_HAND_LOG ]; then
        INITIATE_LOG $PATH_HAND_LOG
    else
        exitcode=$(sed '2q;d' $PATH_HAND_LOG | awk -F ',' '{print $NF;}')
        if [ -z "${exitcode}" ]; then
            exitcode=0
        fi
        if [ "${exitcode}" -gt 0 ]; then
            return ${exitcode}
        fi
    fi

    while read -r cmd <&3 && read -r outputs <&4; do
        cmd_run=$(echo "$cmd" | awk '{print $1;}')
        RUN_COMMAND $PATH_HAND_LOG ${outputs}
    done 3<$PATH_HAND_CMDS 4<$PATH_HAND_CMD_OUTPUTS

    LOG_COMPLETION $PATH_HAND_LOG

}

export -f RUN_COMMANDS


export NPROC=$(($(grep -c ^processor /proc/cpuinfo) - 1))
if [ $JOBS -gt $NPROC ]; then
    JOBS=$NPROC
fi
if [ $JOBS -eq 1 ]; then
    for argument in $ARGS; do
#        shift
        RUN_COMMANDS $argument
    done
else
    parallel --will-cite -j $JOBS -k --ungroup RUN_COMMANDS ::: $ARGS
fi

