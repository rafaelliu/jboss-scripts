#!/bin/sh
#
# Rafael Liu <rafaelliu@gmail.com>
#

if [ $# -lt 1 -o $# -gt 2 ]; then
        echo "USAGE: register-hc.sh <DC's address> [DC's SSH user]"

        exit 1
fi

source ./common.sh

USER="$( hostname )"
USER_FQN="$( hostname -f )"
PASS="abcd@1234"

SSH_USER=${SSH_USER:-"jboss"}

ssh $SSH_USER@$ADDRESS << EOF
	$PROFILE_HOME/bin/add-user.sh -u "$USER" -p "$PASS" -s
	$PROFILE_HOME/bin/add-user.sh -u "$USER_FQN" -p "$PASS" -s
EOF

