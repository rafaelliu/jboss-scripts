#!/bin/sh
#
# JBoss domain control script
#
# chkconfig: - 80 20
# description: JBoss AS Domain
# processname: domain
#
# Rafael Liu <rafaelliu@gmail.com>
#

BIND_ADDRESS="127.0.0.1"

# uncomment if (and only if) it's a remote HC
#MASTER_ADDRESS="xxx.xxx.xxx.xxx"

# need in order to use service jboss start console
#JBOSS_CONSOLE_LOG="/tmp/jboss-console.log"

# 
# Great default: courtesy of the bin directory in the profile
#

DIR=$( dirname $0 )


DOMAIN_PROFILE=${PWD%%/bin}
DOMAIN_PROFILE=${DOMAIN_PROFILE##*/}

if [[ $OSTYPE == *linux* ]]; then
	
  PROFILE_HOME=$( readlink -f  $DIR/../ )
  JBOSS_HOME=$( readlink -f $DIR/../../ )

# To work with OS X
elif [[ $OSTYPE == *darwin* ]]; then 
	
	if hash greadlink 2>/dev/null; then
	    PROFILE_HOME=$( greadlink -f $DIR/../ )
	    JBOSS_HOME=$( greadlink -f $DIR/../../ )
	else
		echo "You need greadlink to run this, please run: brew install coreutils"
		echo "Or: macports install coreutils"
		echo "And try again."
		exit
	fi
	
fi

. $JBOSS_HOME/bin/init.d/jboss-as-domain.sh $*




