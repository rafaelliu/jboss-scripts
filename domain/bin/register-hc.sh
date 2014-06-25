#!/bin/sh
#
# Rafael Liu <rafaelliu@gmail.com>
#

if [ $# -lt 1 -o $# -gt 2 ]; then
        echo "USAGE: register-hc.sh <DC's address> [DC's SSH user]"

        exit 1
fi

derelativize() {
  if [[ $OSTYPE == *linux* ]]; then
    readlink -f $1
  elif [[ $OSTYPE == *darwin* ]]; then
    if hash greadlink 2>/dev/null; then
      greadlink -f $1
    else
      echo "ERROR: You need greadlink to run this, please run: brew install coreutils / macports install coreutils"
      exit 1
    fi
  fi
}

PROGRAM=$( derelativize $0 )
DIR=$( dirname $PROGRAM )

if [ -z "$JBOSS_HOME" ]; then
  DOMAIN_PROFILE=${DIR%%/bin}
  DOMAIN_PROFILE=${DOMAIN_PROFILE##*/}

  PROFILE_HOME=$( derelativize $DIR/../ )
  JBOSS_HOME=$( derelativize $DIR/../../ )

  if [ -z "$JBOSS_HOME/bin/product.conf" ]; then
    echo "ERROR: couldn't auto-find JBOSS_HOME, must defined"
    exit 1
  fi
fi

source $DIR/setup.conf

USER="$( hostname )"
USER_FQN="$( hostname -f )"
PASS="abcd@1234"

SSH_USER=${SSH_USER:-"jboss"}

ssh $SSH_USER@$ADDRESS << EOF
	$PROFILE_HOME/bin/add-user.sh -u "$USER" -p "$PASS" -s
	$PROFILE_HOME/bin/add-user.sh -u "$USER_FQN" -p "$PASS" -s
EOF

