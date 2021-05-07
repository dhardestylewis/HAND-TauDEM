## Usage:
##  source conda_wrappers.sh

## conda_wrappers.sh provides wrappers around conda
##  to ensure it always activates and deactivates

## Author: Daniel Hardesty Lewis
## Copyright: Copyright 2021, Daniel Hardesty Lewis
## Credits: Daniel Hardesty Lewis
## License: GPLv3
## Version: 1.0.0
## Maintainer: Daniel Hardesty Lewis
## Email: dhl@tacc.utexas.edu
## Status: Production


CONDA_INITIALIZE() {

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
    if [[ "${CONDA_DEFAULT_ENV}" != $1 ]]; then
        if [[ "${CONDA_DEFAULT_ENV}" == 'base' ]]; then
            conda activate $1
        elif [[ "${CONDA_DEFAULT_ENV}" ]]; then
            conda deactivate
            conda activate $1
        else
            conda activate
            conda activate $1
        fi
    fi
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"

    : &

}


CONDA_ACTIVATE() {

    ## Properly initialise non-interactive shell
    eval "$(conda shell.bash hook)"

    export LD_LIBRARY_PATH=$(
        echo "${LD_LIBRARY_PATH}" |
        sed -E 's|^'"${CONDA_PREFIX}"'/lib:||'
    )
    conda deactivate
    conda activate $1
    export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}"

    : &

}


CONDA_DEACTIVATE() {

    ## Properly initialise non-interactive shell
    eval "$(conda shell.bash hook)"

    export LD_LIBRARY_PATH=$(echo "${LD_LIBRARY_PATH}" | sed -E 's|^'"${CONDA_PREFIX}"'/lib:||')
    conda deactivate

    : &

}
