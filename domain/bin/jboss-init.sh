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

BIND_ADDRESS="xxx.xxx.xxx.xxx"

# uncomment if (and only if) it's a remote HC
#MASTER_ADDRESS="xxx.xxx.xxx.xxx"

# need in order to use service jboss start console
#JBOSS_CONSOLE_LOG="/tmp/jboss-console.log"

# 
# Great default: courtesy of the bin directory in the profile
#

DIR=$( dirname $0 )
PROFILE_HOME=$( readlink -f $DIR/../ )
JBOSS_HOME=$( readlink -f $DIR/../../ )

DOMAIN_PROFILE=${PWD%%/bin}
DOMAIN_PROFILE=${DOMAIN_PROFILE##*/}

. $JBOSS_HOME/bin/init.d/jboss-as-domain.sh $*

