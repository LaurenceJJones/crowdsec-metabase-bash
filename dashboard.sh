#!/bin/bash

## Pre-requisites
# 1. Docker or Podman
# 2. groupadd or addgroup
# 3. Yq to parse the crowdsec yaml file

### Mutable variables
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
GROUPADD_CMD="${GROUPADD_CMD:-groupadd}"
CROWDSEC_CONFIG_FILE="${CROWDSEC_CONFIG_FILE:-/etc/crowdsec/config.yaml}"

## Non mutable variables
DEFAULT_GROUP="crowdsec"
GID=""
DEPS_FOLDER=$(mktemp -d)
YQ_BINARY="${DEPS_FOLDER}/yq"

command_exists() {
    command -v "$@" >/dev/null 2>&1
}

clean_up_and_exit() {
    rm -rf "$DEPS_FOLDER"
    exit "$1"
}

## Get arch anything other than amd64 is not supported
get_arch() {
    case "$(uname -m)" in
    "x86_64" | "amd64")
        echo "amd64"
        ;;
    *)
        echo "Unsupported architecture"
        exit 1
        ;;
    esac
}

YQ_DOWNLOAD_LINK="https://github.com/mikefarah/yq/releases/download/v4.43.1/yq_linux_$(get_arch)"

download() {
    if [ -z "$1" ]; then
        echo "download() requires a URL as first argument"
        exit 1
    fi
    if [ -z "$2" ]; then
        echo "download() requires a destination directory as second argument"
        exit 1
    fi

    if command -v curl >/dev/null; then
        cd "${2%/*}" || (echo "Could not cd to ${2%/*}" && exit 1)
        # older versions of curl don't support --output-dir
        curl -sSLo "${2##*/}" --fail "$1"
        cd - >/dev/null || exit
    elif command -v wget >/dev/null; then
        wget -nv -qO "$2" "$1"
    else
        echo "Neither curl nor wget is available, cannot download files."
        exit 1
    fi
}

download "$YQ_DOWNLOAD_LINK" "$YQ_BINARY"
chmod +x "$YQ_BINARY"

yq_local() {
    if [ -f "$2.local" ] && [[ ! $(YQ_BINARY e "$1" "$2.local") ]] || [ ! -f "$2.local" ]; then
        $YQ_BINARY "$1" "$2"
    fi
}

if [ ! -f "$CROWDSEC_CONFIG_FILE" ]; then
    echo "CrowdSec config file $CROWDSEC_CONFIG_FILE not found. Please provide the correct path to the config file."
    echo "Usage: CROWDSEC_CONFIG_FILE='/path/to/config' $0 {start|stop|setup}"
    clean_up_and_exit 1
fi

if [ -z "$CROWDSEC_DATA_DIR" ]; then
    CROWDSEC_DATA_DIR=$(yq_local '.config_paths.data_dir' "$CROWDSEC_CONFIG_FILE") 
    if [ -z "$CROWDSEC_DATA_DIR" ]; then
        echo "Error parsing the crowdsec config file. Please provide the correct path to the config file."
        clean_up_and_exit 1
    fi
fi

## In some systems, groupadd is not installed, so we need to check for an alternative
if ! command_exists "$GROUPADD_CMD"; then
    echo "groupadd is not installed"
    echo "Checking for alternative groupadd command..."
    GROUPADD_CMD="addgroup"
    if ! command_exists $GROUPADD_CMD; then
        echo "addgroup is not installed"
        clean_up_and_exit 1
    fi
fi

## Check if docker or podman is installed
if ! command_exists "$CONTAINER_RUNTIME"; then
    echo "Docker is not installed"
    echo "Attempting to find podman...."
    CONTAINER_RUNTIME="podman"
    if ! command_exists $CONTAINER_RUNTIME; then
        echo "Podman is not installed either exiting..."
        clean_up_and_exit 1
    fi
fi

## Log the container runtime
echo "Container runtime: $CONTAINER_RUNTIME"

## Case check the argument
case $1 in
setup)
    echo "Setting up dashboard..."
    shift   # Remove the first argument
    ;;
start)
    echo "Starting dashboard..."
    ;;
stop)
    echo "Stopping dashboard..."
    ;;
*)
    echo "Usage: $0 {setup|start|stop}"
    ;;
esac


    # while [[ $# -gt 0 ]]; do
    #     case "$1" in
    #     -a | --argumentA)
    #         argumentA="$2"
    #         shift # Remove argument name from processing
    #         shift # Remove argument value from processing
    #         ;;
    #     -b | --argumentB)
    #         argumentB="$2"
    #         shift # Remove argument name from processing
    #         shift # Remove argument value from processing
    #         ;;
    #     -c | --argumentC)
    #         argumentC="$2"
    #         shift # Remove argument name from processing
    #         shift # Remove argument value from processing
    #         ;;
    #     *) # Unknown option
    #         echo "Unknown argument: $1"
    #         return 1
    #         ;;
    #     esac
    # done
