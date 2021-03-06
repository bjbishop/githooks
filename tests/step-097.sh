#!/bin/sh
# Test:
#   Direct template execution: list of staged files (hook types)

MANAGED_HOOK_NAMES="
    applypatch-msg pre-applypatch post-applypatch
    pre-commit prepare-commit-msg commit-msg post-commit
    pre-rebase post-checkout post-merge pre-push
    pre-receive update post-receive post-update
    push-to-checkout pre-auto-gc post-rewrite sendemail-validate
"

SINGLE="--single"
if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    # Do not use single install with core.hooksPath
    SINGLE=""
fi

# shellcheck disable=SC2086
mkdir -p /tmp/test097/.git/hooks &&
    cd /tmp/test097 &&
    git init &&
    sh /var/lib/githooks/install.sh $SINGLE &&
    git config githooks.autoupdate.enabled false ||
    exit 1

for HOOK_TYPE in ${MANAGED_HOOK_NAMES}; do
    mkdir -p ".githooks/${HOOK_TYPE}" || exit 1

    cat <<EOF >".githooks/${HOOK_TYPE}/${HOOK_TYPE}" || exit 1
printf "hook=\$(basename \$0) -- " >> /tmp/test097.out

for STAGED in \${STAGED_FILES}; do
    echo "\${STAGED}" >> /tmp/test097.out
done
EOF
done

echo "test" >testing.txt
git add testing.txt

ACCEPT_CHANGES=A git commit -m 'testing hooks'

cat /tmp/test097.out

if [ "$(grep -c "testing.txt" /tmp/test097.out)" != "3" ]; then
    echo "! Unexpected number of output rows"
    exit 1
fi

if [ "$(grep -c "hook=" /tmp/test097.out)" != "4" ]; then
    echo "! Unexpected number of hooks run"
    exit 1
fi
