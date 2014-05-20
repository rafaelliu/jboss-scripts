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

. ../../bin/init.d/jboss-custom.sh $*




