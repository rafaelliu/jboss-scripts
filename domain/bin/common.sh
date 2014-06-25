#!/bin/sh

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
