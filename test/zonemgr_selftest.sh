#! /usr/bin/bash

# Selftest framework for zonemgr.
# Note that the user running it should have pre-set appropriate permissions
# and system privileges (RBAC for pfexec by default, sudo etc. experimentally)
# Test snippets generally run sourced from sub-directories; the default set
# in "./tests" requires that the sandbox of a GIZ and DIZ to manipulate has
# been pre-created with snippets from "./tests-0001-init". This sandbox can
# be cleared by snippets from "./tests-9999-teardown".
#   ./zonemgr_selftest.sh tests-9999-teardown/ --no-fail-fast
#   ./zonemgr_selftest.sh tests-0001-init/
# Copyright (C) 2017 by Jim Klimov

usage() {
    cat << EOF
Usage: $0 [--config FILE] [testname...]
EOF
}

ZONEMGR="`dirname $0`/../bin/zonemgr"
ZONEMGR_CFG="`dirname $0`/zonemgr_selftest.cfg"
# Default to a local test-config instead of a git-tracked one
# (it may source the original test-config, should you want to):
[ -s "$ZONEMGR_CFG".local ] && ZONEMGR_CFG="$ZONEMGR_CFG".local
TESTDIR="`dirname $0`/tests"
FAILFAST=1

TESTS=""
ZONEMGR_DEBUG=1
DO_PRINT_CONFIG=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help|-help) usage; exit 0;;
        --config) ZONEMGR_CFG="$2"; shift ;;
        --print-config) DO_PRINT_CONFIG=1 ;;
        --no-print-config) DO_PRINT_CONFIG=0 ;;
        -q) ZONEMGR_DEBUG=0;;
        -d|--debug)
            if [ "$2" -ge -1 ] 2>/dev/null ; then
                ZONEMGR_DEBUG="$2"
                shift
            else
                ZONEMGR_DEBUG="$(expr $ZONEMGR_DEBUG + 1)" || \
                    ZONEMGR_DEBUG="99"
            fi
            ;;
        --failfast|--fail-fast) FAILFAST=1 ;;
        --no-failfast|--no-fail-fast) FAILFAST=0 ;;
        -*)  echo "ERROR: Unrecognized argument: $1" >&2 ; exit 1;;
        /*) if [ -d "$1" ]; then
                TESTS="$TESTS `ls -1 $1/*.test`"
             else
                TESTS="$TESTS $1"
             fi ;;
        */*) if [ -d "$1" ]; then
                TESTS="$TESTS `ls -1 $(pwd)/$1/*.test`"
             else
                TESTS="$TESTS `pwd`/$1"
             fi ;;
        *)   if [ -d "$1" ]; then
                TESTS="$TESTS `ls -1 $(pwd)/$1/*.test`"
             else
                if [ -f "$1" ]; then
                    TESTS="$TESTS `pwd`/$1"
                 else
                    TESTS="$TESTS $TESTDIR/`basename "$1" .test`.test"
                 fi
             fi ;;
    esac
    shift
done

if [ -z "$TESTS" ]; then
    TESTS="$(ls -1 "$TESTDIR"/*.test | sort -n)"
fi

if [ -z "$TESTS" ]; then
    echo "ERROR: No self-tests requested or found" >&2
    exit 1
fi

if [ -n "$ZONEMGR_CFG" ] && [ ! -f "$ZONEMGR_CFG" ]; then
    echo "ERROR: ZONEMGR_CFG='$ZONEMGR_CFG' requested but not found" >&2
    exit 1
fi

ZONEMGR_CMD="$ZONEMGR -d $ZONEMGR_DEBUG"
if [ "$DO_PRINT_CONFIG" != 0 ]; then
    ZONEMGR_CMD="$ZONEMGR_CMD --print-config"
fi
if [ -n "$ZONEMGR_CFG" ] ; then
    ZONEMGR_CMD="$ZONEMGR_CMD --config $ZONEMGR_CFG"
fi

echo "`date -u`: Starting $0" >&2
# Names of tests that passed or failed
FAILED=""
PASSED=""
COUNT_FAILED=0
COUNT_PASSED=0
for TEST in $TESTS ; do
    TESTBASE="`basename $TEST .test`"
    echo "============ START `date -u`: $TESTBASE" >&2
    ( [ "$ZONEMGR_DEBUG" -gt 1 ] && set -x
      . $TEST ) ; RES=$?
    if [ "$RES" = 0 ]; then
        VERDICT="PASSED"
        PASSED="$PASSED $TESTBASE"
        COUNT_PASSED="$(expr $COUNT_PASSED + 1)"
    else
        VERDICT="FAILED($RES)"
        FAILED="$FAILED $TESTBASE($RES)"
        COUNT_FAILED="$(expr $COUNT_FAILED + 1)"
    fi
    echo "============  END  `date -u`: $TESTBASE   $VERDICT" >&2
    echo "" >&2
    if [ "$RES" != 0 ] && [ "$FAILFAST" = 1 ] ; then
        echo "ABORTING after first sub-test error, as requested" >&2
        echo "" >&2
        break
    fi
done

echo "`date -u`: $0 finished" >&2
if [ -n "$PASSED" ]; then
    echo "PASSED: $COUNT_PASSED tests: $PASSED" >&2
else
    echo "ERROR: No tests passed!" >&2
fi

if [ -n "$FAILED" ]; then
    echo "FAILED: $COUNT_FAILED tests: $FAILED" >&2
fi

if [ -n "$FAILED" ] || [ -z "$PASSED" ]; then
    exit 1
fi

exit 0
