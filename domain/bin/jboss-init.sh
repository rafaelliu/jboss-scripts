#!/bin/sh
#
# JBoss domain control script
#
# chkconfig: - 80 20
# description: JBoss AS Domain
# processname: domain
#
# Author: Rafael Liu <rafaelliu@gmail.com>
# Modified by: Anderson Deluiz <https://github.com/anddeluiz>
#

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

  if [ ! -f "$JBOSS_HOME/bin/product.conf" ]; then
    echo "ERROR: couldn't auto-find JBoss Application Server at ${JBOSS_HOME}"
    echo "ERROR: Please check JBOSS_HOME environment variable."
    exit 1
  fi
fi

source $DIR/setup.conf

source $JBOSS_HOME/bin/init.d/jboss-custom.sh $*

