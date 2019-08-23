#!/bin/sh
if [ -n "$TEST_STEP" ]; then
    STEPS_TO_RUN="step-${TEST_STEP}.sh"
else
    STEPS_TO_RUN="step-*"
fi

ROOT_DIR="C:/Program Files"
mkdir -p "$ROOT_DIR/githooks" || true
cp base-template.sh "$ROOT_DIR/githooks"/ || exit 1
cp install.sh "$ROOT_DIR/githooks"/ || exit 1
cp uninstall.sh "$ROOT_DIR/githooks"/ || exit 1
cp cli.sh "$ROOT_DIR/githooks"/ || exit 1
cp -r examples "$ROOT_DIR/githooks"/ || exit 1

GITHOOKS_TESTS="$ROOT_DIR/tests"

git config --global user.email "githook@test.com" || exit 2
git config --global user.name "Githook Tests" || exit 2

mkdir -p "$GITHOOKS_TESTS" || true
cp tests/exec-steps.sh "$GITHOOKS_TESTS"/ || exit 3
# shellcheck disable=SC2086
cp tests/$STEPS_TO_RUN "$GITHOOKS_TESTS"/ || exit 3

# Do not use the terminal in tests
sed -i 's|</dev/tty|</dev/null|g' "$ROOT_DIR"/githooks/install.sh || exit 4
# Change the base template so we can pass in the hook name and accept flags
# shellcheck disable=SC2016
sed -i -E 's|HOOK_NAME=.*|HOOK_NAME=\${HOOK_NAME:-\$(basename "\$0")}|' "$ROOT_DIR"/githooks/base-template.sh &&
    sed -i -E 's|HOOK_FOLDER=.*|HOOK_FOLDER=\${HOOK_FOLDER:-\$(dirname "\$0")}|' "$ROOT_DIR"/githooks/base-template.sh &&
    sed -i 's|ACCEPT_CHANGES=|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|' "$ROOT_DIR"/githooks/base-template.sh &&
    sed -i 's|read -r "\$VARIABLE"|eval "\$VARIABLE=\$\$(eval echo "\$VARIABLE")" # disabled for tests: read -r "\$VARIABLE"|' "$ROOT_DIR"/githooks/base-template.sh || exit 5

# Patch all paths to use windows base path
sed -i -E "s|([^\"])/var/lib/|\1\"$ROOT_DIR\"/|g" "$ROOT_DIR"/tests/exec-steps.sh "$ROOT_DIR"/tests/step-* || exit 7
sed -i -E "s|\"/var/lib/|\"$ROOT_DIR/|g" "$ROOT_DIR"/tests/exec-steps.sh "$ROOT_DIR"/tests/step-* || exit 7

# Allow running outside of Docker containers
sed -i -E "s|if ! grep '/docker/' </proc/self/cgroup >/dev/null 2>&1; then|if false; then|" "$ROOT_DIR"/tests/exec-steps.sh

sh "$ROOT_DIR"/tests/exec-steps.sh
