#!/bin/sh
#
# Utility for adding user to this specific instance
#
# Rafael Liu <rafaelliu@gmail.com>
#

DIR=$( dirname $0 )
PROFILE_HOME=$( readlink -f $DIR/../ )
JBOSS_HOME=$( readlink -f $DIR/../../ )

JAVA_OPTS="$JAVA_OPTS -Djboss.domain.config.user.dir=$PROFILE_HOME/configuration" $JBOSS_HOME/bin/add-user.sh $*
