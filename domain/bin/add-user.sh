#!/bin/sh
#
# Utility for adding user to this specific instance
#
# Rafael Liu <rafaelliu@gmail.com>
#

source ./common.sh

JAVA_OPTS="$JAVA_OPTS -Djboss.domain.config.user.dir=$PROFILE_HOME/configuration" $JBOSS_HOME/bin/add-user.sh $*
