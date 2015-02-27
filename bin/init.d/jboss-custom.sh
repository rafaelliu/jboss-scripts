#!/bin/sh
#
# Author: Rafael Liu <rafaelliu@gmail.com>
# Modified by: Anderson Deluiz <https://github.com/anddeluiz>
# Modified by: Karina Macedo <https://github.com/kmacedovarela>
# Modified by: Rodrigo Ramalho <https://github.com/hodrigohamalho>
#
# You really shouldn't be editing this. Most of variables defined here can be overwriten on jboss-init.sh:
#  JBOSS_HOME: yes, you guessed it!
#  JBOSS_USER: owner of the process
#  JBOSS_CONSOLE_LOG: log file to which redirect ouput
#  JBOSS_STARTUP_WAIT: timout to consider a startup failed (process will be left intact)
#  JBOSS_SHUTDOWN_WAIT: timout to consider a shutdown failed (process will be left intact)
#  JBOSS_OPTS: custom JBoss options can go here
#  JBOSS_DOMAIN_LOG_DIR: log directory for domain
#  BIND_ADDRESS: general IP
#  PUBLIC_ADDRESS: public IP (defaults to $BIND_ADDRESS)
#  MANAGEMENT_ADDRESS: management IP (defaults to $BIND_ADDRESS)
#  MANAGEMENT_PORT: management port (it's usefull to use more than one HC on same machine)
#  MANAGEMENT_NATIVE_PORT: management native port (it's usefull to use more than one HC on same machine)
#  MASTER_ADDRESS: address to which HC should connect
#  MASTER_MGMT_PORT: master server management port (it's usefull to use more than one DC on same machine)
#  JBOSS_DOMAIN_CONFIG: domain.xml to be used if it's a DC
#  JBOSS_HOST_CONFIG: host.xml to be used (default: automatically detected)
#  DOMAIN_PROFILE: path to the profile dir
#

# Source function library.

if [[ $OSTYPE == *linux* ]]; then
  . /etc/init.d/functions
else
  alias warning=echo -n
  alias success=echo -n
  alias failure=echo -n
fi

# Load Java configuration.
export JAVA_HOME

#
# Set defaults.
#

if [ -z "$JBOSS_HOME" ]; then
  echo "ERROR: couldn't find JBOSS_HOME, must defined"
  exit 1
fi

export JBOSS_HOME

BIND_ADDRESS=${BIND_ADDRESS:-"127.0.0.1"}
DOMAIN_PROFILE=${DOMAIN_PROFILE:-"$JBOSS_HOME/domain"}
JBOSS_CONSOLE_LOG=${JBOSS_CONSOLE_LOG:-"/dev/null"}
JBOSS_DOMAIN_CONFIG=${JBOSS_DOMAIN_CONFIG:-"domain.xml"}
JBOSS_DOMAIN_LOG_DIR=${JBOSS_DOMAIN_LOG_DIR:-"$PROFILE_HOME/log/"}
JBOSS_OPTS=${JBOSS_OPTS:-""}
JBOSS_SCRIPT=$JBOSS_HOME/bin/domain.sh
JBOSS_SHUTDOWN_WAIT=${JBOSS_SHUTDOWN_WAIT:-"30"}
JBOSS_STARTUP_WAIT=${JBOSS_STARTUP_WAIT:-"30"}
JBOSS_USER=${JBOSS_USER:-"jboss"}
MANAGEMENT_ADDRESS=${MANAGEMENT_ADDRESS:-"$BIND_ADDRESS"}
MANAGEMENT_NATIVE_PORT=${MANAGEMENT_NATIVE_PORT:-"9999"}
MANAGEMENT_PORT=${MANAGEMENT_PORT:-"9990"}
MASTER_MGMT_PORT=${MASTER_MGMT_PORT:-"9999"}
PUBLIC_ADDRESS=${PUBLIC_ADDRESS:-"$BIND_ADDRESS"}

#
# validations
#

if [ "$(id -un)" != "root" -a "$(id -un)" != "${JBOSS_USER}" ]
then
   echo "ERROR: this must be run by user root or user ${JBOSS_USER}"
   exit 1
fi

id $JBOSS_USER > /dev/null
if [ "$?" != "0" ]; then
  echo "ERROR: User '$JBOSS_USER' doesn't exist. Create it or change JBOSS_USER param"
  exit 1
fi

#
# Check if this is a DC and adjust config files and JBoss opts
#

if [ -z "$MASTER_ADDRESS" ]; then
  # if there's a master, defaults to host-master.xml (can still set explicitly)
  JBOSS_HOST_CONFIG=${JBOSS_HOST_CONFIG:-"host-master.xml"}
  
else
  # if there's no master, defaults to host-slave.xml (can still set explicitly)
  JBOSS_HOST_CONFIG=${JBOSS_HOST_CONFIG:-"host-slave.xml"}

  # also add master's address and port
  JBOSS_OPTS="$JBOSS_OPTS --master-address=$MASTER_ADDRESS -Djboss.domain.master.port=${MASTER_MGMT_PORT}"
fi

# JBoss host's name (will be used in jboss-cli)
HOST=$(grep -ro '<host[ \t].*name="[^"]*"' $PROFILE_HOME/configuration/$JBOSS_HOST_CONFIG | cut -f2 -d ' ' | cut -f2 -d'"')
if [ ! "$HOST" ]; then 
  if [ -z "$MASTER_ADDRESS" ]; then
    HOST="master"
  else
    HOST="$( hostname )"
  fi
fi

# build final opts
JBOSS_OPTS="$JBOSS_OPTS -Djboss.domain.base.dir=$PROFILE_HOME --domain-config=$JBOSS_DOMAIN_CONFIG --host-config=$JBOSS_HOST_CONFIG -b $PUBLIC_ADDRESS -bmanagement $MANAGEMENT_ADDRESS -Djboss.domain.log.dir=$JBOSS_DOMAIN_LOG_DIR -Djboss.management.native.port=$MANAGEMENT_NATIVE_PORT -Djboss.management.http.port=$MANAGEMENT_PORT "

prog='jboss-as'

start() {
  if [ -e $JBOSS_CONSOLE_LOG ]
  then
    if [ -w $JBOSS_CONSOLE_LOG ]
    then
       cat /dev/null > $JBOSS_CONSOLE_LOG
    else
       echo "ERROR: console log file $JBOSS_CONSOLE_LOG doesn't have write permission for user $JBOSS_USER"
       exit 1
    fi
  else
     if [ -w $(dirname ${JBOSS_CONSOLE_LOG}) ]
     then
        cat /dev/null > $JBOSS_CONSOLE_LOG
        chmod 644 $JBOSS_CONSOLE_LOG
	chown ${JBOSS_USER}:$(id -gn ${JBOSS_USER}) $JBOSS_CONSOLE_LOG
     else
        echo "ERROR: error creating console log file $JBOSS_CONSOLE_LOG"
	echo "ERROR: check permissions for user $JBOSS_USER on $(dirname JBOSS_CONSOLE_LOG) directory."
	exit 1
     fi
  fi
  
  echo -n "Starting $prog: "
  status &> /dev/null
  if [ "$?" = "0" ]; then
    echo "$prog already running"
    return 1
  fi

  cleanup

  if [ "$1" = "cached" ]; then
    JBOSS_OPTS="$JBOSS_OPTS --cached-dc"
  else
    JBOSS_OPTS="$JBOSS_OPTS --backup"
  fi

  if [ ! -z "$JBOSS_USER" ]; then
    CMD="$JBOSS_SCRIPT $JBOSS_OPTS"
    if [ "$( id -un )" = "$JBOSS_USER" ]; then
      $CMD 2>&1 > $JBOSS_CONSOLE_LOG &
    elif [ "$( id -un )" = "root" ]; then
      su - $JBOSS_USER -c "LAUNCH_JBOSS_IN_BACKGROUND=1 $CMD" 2>&1 > $JBOSS_CONSOLE_LOG &
    else
      failure
      echo
      echo "Must logged as either $JBOSS_USER or root to launch $prog"
      exit 1
    fi
  fi

  if [ "$?" != "0" ]; then
    failure
    echo
    exit 1
  fi

  case "$1" in
    console)
      start_console
      ;;
    sync)
      start_sync
      ;;
    async | *)
      start_async
      ;;
  esac

}

start_console() {
  if [ -z "$JBOSS_CONSOLE_LOG" ] || [ "$JBOSS_CONSOLE_LOG" = "/dev/null" ]; then
    warning
    echo

    echo "- You must set JBOSS_CONSOLE_LOG in order to see the console output. You may also use 'service jboss tail'"
    echo "- NOTE: that doesn't mean JBoss wasn't started!'"

    exit 1
  fi

  echo
  tail -100f $JBOSS_CONSOLE_LOG

  exit 0
}

start_sync() {
  count=0
  launched=false

  until [ $count -gt $JBOSS_STARTUP_WAIT ]; do
    status &> /dev/null
    if [ "$?" = "0" ] ; then
      launched=true
      break
    fi 
    sleep 1
    let count=$count+1;
  done

  if [ $launched ]; then
    success
    echo
    exit 0
  else
    failure
    echo
    exit 1
  fi
}

start_async() {
  success
  echo

  echo "- NOTE: that doesn't mean JBoss was started!'"

  exit 0
}

cleanup() {

  #chown -R $JBOSS_USER: $JBOSS_HOME

  # https://bugzilla.redhat.com/show_bug.cgi?id=901210
  rm -rf $DOMAIN_PROFILE/tmp/*
 
}

stop() {
  echo -n "Stopping $prog: "

  cli "/host=$HOST:shutdown" &> /dev/null

  count=0
  stopped=false
  until [ $count -gt $JBOSS_SHUTDOWN_WAIT ]; do
    status &> /dev/null
    if [ "$?" = "1" ] ; then
      stopped=true
      break
    fi 
    sleep 1
    let count=$count+1;
  done

  if [ $stopped ]; then    
    success
    echo
  else
    failure
    echo "Looks like JBoss is not responding"
    echo "You may force a kill issuing a $0 kill"
  fi
}

get_pids_for() {
  if [ -z "$1" ]; then
    PIDS=$( ps ax | grep "jboss.domain.base.dir=$PROFILE_HOME" 2> /dev/null )
  else
    PIDS=$( ps ax | grep "jboss.domain.base.dir=$PROFILE_HOME" | grep "\[$1\]" 2> /dev/null )
  fi
  echo $PIDS | cut -f1 -d' '
}

force_kill() {
  PID=$( get_pids_for 'Process Controller' )
  kill -9 $PID

  # this is just to supress kill message
  wait $PIDS 2>/dev/null # so bash doesn't warn
  sleep 1

  echo "Issued a kill -9 for PID: $PID"
}

jdr() {
  $JBOSS_HOME/bin/jdr.sh
}

dump_all() {

  status &> /dev/null
  if [ "$?" != "0" ]; then
    echo "$prog is not running"
    return 1
  fi

  DUMP_FILE="jboss-dump-$( date +%Y%m%d-%H%M%S )"
  DUMP_PATH="/tmp/$DUMP_FILE"
  mkdir "$DUMP_PATH"

  cli "/:read-resource(recursive=true,include-runtime=true)" &> "$DUMP_PATH/cli.dump" &

  # copy logs
  cp -a "$JBOSS_DOMAIN_LOG_DIR" "$DUMP_PATH/log" &

  # process controller
  PC_PID=$( get_pids_for "Process Controller" )
  ps aux | grep $PC_PID &> "$DUMP_PATH/pc_ps.out"
  jstack $PC_PID &> "$DUMP_PATH/pc_jstack.out"
  jmap -heap $PC_PID &> "$DUMP_PATH/pc_jmap.out"

  # host controller
  HC_PID=$( get_pids_for "Host Controller" )
  ps aux | grep $HC_PID &> "$DUMP_PATH/hc_ps.out"
  jstack $HC_PID &> "$DUMP_PATH/hc_jstack.out"
  jmap -heap $HC_PID &> "$DUMP_PATH/hc_jmap.out"

  # servers
  for SERVER in $( ls $PROFILE_HOME/servers); do
    mkdir "$DUMP_PATH/$SERVER" &
    PID=$( get_pids_for "Server:$SERVER" )

    if [ "$PID" != "" ]; then
      ps aux | grep $PID &> "$DUMP_PATH/$SERVER/ps.out"
      jstack $PID &> "$DUMP_PATH/$SERVER/jstack.out"
      jmap -heap $PID &> "$DUMP_PATH/$SERVER/jmap.out"
    fi

    cp -a "$JBOSS_DOMAIN_LOG_DIR/servers/$SERVER/log" "$DUMP_PATH/$SERVER/log" &
  done

  tar zcvf "${DUMP_FILE}.tar.gz" "$DUMP_PATH" &> /dev/null
  echo "Generated dump file: ${DUMP_FILE}.tar.gz"
}

status() {
  PID=$( get_pids_for 'Process Controller' )
  if [ -z $PID ] ; then
    echo "$prog is dead"
    return 1
  fi

  STATUS=$( cli "/host=$HOST:read-attribute(name=host-state)" 2> /dev/null | grep "result" | sed 's/.*=> "\(.*\)"/\1/g' )
  if [ -z $STATUS ]; then
    echo "$prog process is up, but CLI is not responsive (may be shuting down or booting)"
    return 2
  fi

  echo "$prog is up (pid: $PID, status: $STATUS)"
  return 0
}

cli() {
  OPTS="--connect --controller=$MANAGEMENT_ADDRESS:$MANAGEMENT_NATIVE_PORT "
  if [ ! -z "$*" ]; then
     # hack: jboss-cli doesn't handle quotes well
     FILE="/tmp/jboss-cli_$( date +%Y%m%d-%H%M%S%N )"
     echo "$*" > $FILE
     OPTS="$OPTS --file=$FILE"
  fi

  $JBOSS_HOME/bin/jboss-cli.sh $OPTS
}

tail_log() {
  if [ $# = 0 ]; then
    tail -100f "$JBOSS_DOMAIN_LOG_DIR/host-controller.log"
  else
    tail -100f "$JBOSS_DOMAIN_LOG_DIR/servers/$1/server.log"
  fi
}

case "$1" in
  start)
      start $2
      ;;
  stop)
      stop
      ;;
  kill)
      force_kill
      ;;
  restart)
      stop
      start $2
      ;;
  status)
      status
      ;;
  cli)
      cli ${*#"cli"} # pass the second parameter forward
      ;;
  tail)
      tail_log ${*#"tail"}  # pass the second parameter forward
      ;;
  dump)
      dump_all
      ;;
  jdr)
      dump_all
      ;;
  *)
      ## If no parameters are given, print which are avaiable.
      echo "Usage: $0 {start [console|sync|async|cached]|stop|kill|restart|status|cli [cmd]|tail [server name]|dump|jdr}"
      exit 1
      ;;
esac

