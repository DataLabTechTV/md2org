#!/usr/bin/env bash

log() {
    level=$1
    shift

    case $level in
        INFO)
            color=4
            prefix=I
            ;;
        WARN)
            color=3
            prefix=W
            ;;
        ERROR)
            color=1
            prefix=E
            ;;
        DEBUG)
            color=8
            prefix=D
            ;;
        *)
            echo "error: invalid level: $level"
            return 2
    esac

    msg="$1"
    shift

    printf "$(tput setaf $color)$prefix $msg$(tput sgr0)\n" "$@" >&2
}
