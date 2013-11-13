#!/bin/sh
#
# Utility for adding user to this specific instance
#
# Rafael Liu <rafaelliu@gmail.com>
#

DEPLOY_FOLDER="/srv/deploy" 
CONTROLLER="10.0.16.115:9999" 


execute_cli() {
       /opt/jboss/default/bin/jboss-cli.sh --connect --controller=$CONTROLLER --commands="$1"
}

# deploy
for MARKER in $( find -name '*.dodeploy') ; do
        MARKER_FILE="$( readlink -f $MARKER )"
        PKG_FILE="${MARKER_FILE%%'.dodeploy'}"

        # try to deploy it
        execute_cli "deploy $PKG_FILE --server-groups=desenvolvimento"

        # if it went ok, fine. exit
        if [ $? == 0 ]; then
                mv -v $MARKER_FILE $(echo $MARKER_FILE |sed 's/dodeploy/deployed/g')
                continue
        fi

        # maybe an error ocurred because the package is "already exists in the deployment repository" 
        execute_cli "deploy $PKG_FILE --force"

        # now we do a last check
        if [ $? == 0 ]; then
                mv -v $MARKER_FILE $(echo $MARKER_FILE |sed 's/dodeploy/deployed/g')
        else
                mv -v $MARKER_FILE $(echo $MARKER_FILE |sed 's/dodeploy/failed/g')
        fi

done

# undeploy
for MARKER in $( find -name '*.undeploy') ; do
        MARKER_FILE="$( readlink -f $MARKER )"
        PKG_FILE="${MARKER_FILE%%'.undeploy'}"
        WAR_NAME="$( basename $PKG_FILE )"

        # try to deploy it
        execute_cli "undeploy $WAR_NAME --all-relevant-server-groups"

        # now we do a last check
        if [ $? == 0 ]; then
                mv -v $MARKER_FILE $(echo $MARKER_FILE |sed 's/undeploy/undeployed/g')
        else
                mv -v $MARKER_FILE $(echo $MARKER_FILE |sed 's/undeploy/failed/g')
        fi

done
