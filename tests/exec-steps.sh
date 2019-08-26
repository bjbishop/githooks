#!/bin/sh

if ! grep '/docker/' </proc/self/cgroup >/dev/null 2>&1; then
    echo "! This script is only meant to be run in a Docker container"
    exit 1
fi

TEST_RUNS=0
FAILED=0
SKIPPED=0
TIMEOUT=${TEST_TIMEOUT:-10}

FAILED_TEST_LIST=""

for STEP in /var/lib/tests/step-*.sh; do
    STEP_NAME=$(basename "$STEP" | sed 's/.sh$//')
    STEP_DESC=$(head -3 "$STEP" | tail -1 | sed 's/#\s*//')

    echo "> Executing $STEP_NAME"
    echo "  :: $STEP_DESC"

    if [ -w /usr/share/git-core ]; then
        mkdir -p /usr/share/git-core/templates/hooks
        rm -rf /usr/share/git-core/templates/hooks/*
    fi

    rm -rf ~/test*
    rm -rf ~/.githooks
    rm -rf /tmp/*

    mkdir -p /var/lib/backup/githooks &&
        cp -r /var/lib/githooks/* /var/lib/backup/githooks/.

    TEST_RUNS=$((TEST_RUNS + 1))

    TEST_TIME_START=$(date +%s)
    TEST_OUTPUT=$(timeout "$TIMEOUT" sh "$STEP" 2>&1)
    TEST_RESULT=$?
    TEST_TIME_END=$(date +%s)

    TEST_DURATION=$((TEST_TIME_END - TEST_TIME_START))
    if [ $TEST_DURATION -gt 1 ]; then
        echo "  __ Took $TEST_DURATION seconds"
    fi

    # shellcheck disable=SC2181
    if [ $TEST_RESULT -eq 249 ]; then
        REASON=$(echo "$TEST_OUTPUT" | tail -1)
        echo "  x  $STEP has been skipped, reason: $REASON"
        SKIPPED=$((SKIPPED + 1))

    elif [ $TEST_RESULT -eq 124 ] || [ $TEST_RESULT -eq 142 ]; then
        echo "! $STEP has timed out after $TIMEOUT seconds, output:"
        echo "$TEST_OUTPUT"
        FAILED=$((FAILED + 1))
        FAILED_TEST_LIST="$FAILED_TEST_LIST
- $STEP (timeout)"

    elif [ $TEST_RESULT -ne 0 ]; then
        FAILURE=$(echo "$TEST_OUTPUT" | tail -1)
        echo "! $STEP has failed with code $TEST_RESULT ($FAILURE), output:"
        echo "$TEST_OUTPUT"
        FAILED=$((FAILED + 1))
        FAILED_TEST_LIST="$FAILED_TEST_LIST
- $STEP ($TEST_RESULT -- $FAILURE)"

    fi

    if [ -w /usr/share/git-core ]; then
        mkdir -p /usr/share/git-core/templates/hooks
    fi

    UNINSTALL_OUTPUT=$(printf "y\\n\\n" | sh /var/lib/githooks/uninstall.sh 2>&1)
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Uninstall failed in $STEP, output:"
        echo "$UNINSTALL_OUTPUT"
        FAILED=$((FAILED + 1))
    fi

    git config --global --unset init.templateDir
    git config --global --unset githooks.shared
    git config --global --unset githooks.autoupdate.enabled
    git config --global --unset githooks.autoupdate.lastrun
    git config --global --unset githooks.previous.searchdir
    git config --global --unset githooks.disable
    git config --global --unset alias.hooks
    git config --global --unset githooks.installDir

    cp -r /var/lib/backup/githooks/* /var/lib/githooks/. 2>/dev/null

    echo

done

echo "$TEST_RUNS tests run: $FAILED failed and $SKIPPED skipped"
echo

if [ -n "$FAILED_TEST_LIST" ]; then
    echo "Failed tests: $FAILED_TEST_LIST"
    echo
fi

if [ $FAILED -ne 0 ]; then
    exit 1
else
    exit 0
fi
