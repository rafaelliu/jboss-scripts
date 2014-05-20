#!/bin/sh
#
# Rafael Liu <rafaelliu@gmail.com>
#
# You really shouldn't be editing this. Most of variables defined here can be overwriten on jboss-init.sh:
#  JBOSS_HOME: yes, you guessed it!
#  JBOSS_USER: owner of the process
#  JBOSS_CONSOLE_LOG: log file to which redirect ouput
#  JBOSS_STARTUP_WAIT: timout to consider a startup failed (process will be left intact)
#  JBOSS_SHUTDOWN_WAIT: timout to consider a shutdown failed (process will be left intact)
#  JBOSS_OPTS: custom JBoss options can go here
#  BIND_ADDRESS: general IP
#  PUBLIC_ADDRESS: public IP (defaults to $BIND_ADDRESS)
#  MANAGEMENT_ADDRESS: management IP (defaults to $BIND_ADDRESS)
#  MASTER_ADDRESS: address to which HC should connect
#  JBOSS_DOMAIN_CONFIG: domain.xml to be used if it's a DC
#  JBOSS_HOST_CONFIG: host.xml to be used (default: automatically detected)
#  DOMAIN_PROFILE: path to the profile dir
#

# Source function library.

if [[ $OSTYPE == *linux* ]]; then
	. /etc/init.d/functions
fi

# Load Java configuration.
export JAVA_HOME

# Set defaults.

if [ -z "$JBOSS_HOME" ]; then
  echo "ERROR: must define JBOSS_HOME"
  exit 1
fi

export JBOSS_HOME

JBOSS_USER=${JBOSS_USER:-"jboss"}

JBOSS_CONSOLE_LOG=${JBOSS_CONSOLE_LOG:-"/dev/null"}

JBOSS_STARTUP_WAIT=${JBOSS_STARTUP_WAIT:-"30"}
JBOSS_SHUTDOWN_WAIT=${JBOSS_SHUTDOWN_WAIT:-"30"}

# initialize opts
JBOSS_OPTS=${JBOSS_OPTS:-""}

BIND_ADDRESS=${BIND_ADDRESS:-"127.0.0.1"}

PUBLIC_ADDRESS=${PUBLIC_ADDRESS:-"$BIND_ADDRESS"}

MANAGEMENT_ADDRESS=${MANAGEMENT_ADDRESS:-"$BIND_ADDRESS"}

DOMAIN_PROFILE=${DOMAIN_PROFILE:-"$JBOSS_HOME/domain"}

# check for a domain config file, defaults to domain.xml
JBOSS_DOMAIN_CONFIG=${JBOSS_DOMAIN_CONFIG:-"domain.xml"}

JBOSS_SCRIPT=$JBOSS_HOME/bin/domain.sh

#
# validations
#

id $JBOSS_USER > /dev/null
if [ "$?" != "0" ]; then
  echo "User '$JBOSS_USER' doesn't exist. Create it or change JBOSS_USER param"
  exit 1
fi

#
#
#

if [ -z "$MASTER_ADDRESS" ]; then
  # if there's a master, defaults to host-master.xml (can still set explicitly)
  JBOSS_HOST_CONFIG=${JBOSS_HOST_CONFIG:-"host-master.xml"}
  
else
  # if there's no master, defaults to host-slave.xml (can still set explicitly)
  JBOSS_HOST_CONFIG=${JBOSS_HOST_CONFIG:-"host-slave.xml"}

  # also add master's address
  JBOSS_OPTS="$JBOSS_OPTS --master-address=$MASTER_ADDRESS"
fi

# JBoss host's name (will be used in jboss-cli)
HOST=$(grep -ro '<host[ \t].*name="[^"]*"' $PROFILE_HOME/configuration/$JBOSS_HOST_CONFIG | cut -f2 -d ' ' | cut -f2 -d'"')
if [ ! "$HOST" ]; then 
  if [ -z "$MASTER_ADDRESS" ]; then
    HOST="$( hostname )"
  else
    HOST="master"
  fi
fi

# build final opts
JBOSS_OPTS="$JBOSS_OPTS -Djboss.domain.base.dir=$PROFILE_HOME --domain-config=$JBOSS_DOMAIN_CONFIG --host-config=$JBOSS_HOST_CONFIG -b $PUBLIC_ADDRESS -bmanagement $MANAGEMENT_ADDRESS"

prog='jboss-as'

start() {
  echo "Starting $prog: "
  cat /dev/null > $JBOSS_CONSOLE_LOG
  
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
    else
      su - $JBOSS_USER -c "LAUNCH_JBOSS_IN_BACKGROUND=1 JBOSS_PIDFILE=$JBOSS_PIDFILE $CMD" 2>&1 > $JBOSS_CONSOLE_LOG &
    fi
  fi

  if [ "$?" != "0" ]; then
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
  if [ "$JBOSS_CONSOLE_LOG" = "/dev/null" ]; then
    echo

    echo "- You must set JBOSS_CONSOLE_LOG in order to see the console output. You may also use 'service jboss tail'"
    echo "- NOTE: that doesn't mean JBoss wasn't started!'"

    exit 1
  fi

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
    sleep 10
    let count=$count+10;
  done

  if [ $launched ]; then
    echo
    exit 0
  else
    echo
    exit 1
  fi
}

start_async() {
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
  echo $"Stopping $prog: "

  cli "/host=$HOST:shutdown" &> /dev/null

  count=0
  stoped=false
  until [ $count -gt $JBOSS_SHUTDOWN_WAIT ]; do
    status &> /dev/null
    if [ "$?" != "0" ] ; then
      stoped=true
      break
    fi 
    sleep 10
    let count=$count+10;
  done

  if [ $stopped ]; then    
    echo
  else
    echo "Looks like JBoss is not responding"
    echo "You may force a kill issuing a $0 kill"
  fi
}

get_pids_for() {
  if [ -z "$1" ]; then
    PIDS=$( jps -lvm | grep "jboss.domain.base.dir=$PROFILE_HOME" 2> /dev/null )
  else
    PIDS=$( jps -lvm | grep "jboss.domain.base.dir=$PROFILE_HOME" | grep "\[$1\]" 2> /dev/null )
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
  cp -a "$PROFILE_HOME/log" "$DUMP_PATH/log" &

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

    cp -a "$PROFILE_HOME/servers/$SERVER/log" "$DUMP_PATH/$SERVER/log" &
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
    echo "$prog process is up, but CLI is not responsive (may be shuting down or botting)"
    return 2
  fi

  echo "$prog is up (pid: $PID, status: $STATUS)"
  return 0
}

cli() {
  OPTS="--connect --controller=$MANAGEMENT_ADDRESS "
  if [ ! -z "$*" ]; then
     OPTS="$OPTS --command=$@"
  fi

  $JBOSS_HOME/bin/jboss-cli.sh $OPTS
}

tail_log() {
  if [ $# = 0 ]; then
    tail -100f "$PROFILE_HOME/log/host-controller.log"
  else
    tail -100f "$PROFILE_HOME/servers/$1/log/server.log"
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
      $0 stop
      $0 start $2
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
  *)
      ## If no parameters are given, print which are avaiable.
      echo "Usage: $0 {start [console|sync|async|cached]|stop|kill|restart|status|cli|tail [server name]|dump}"
      exit 1
      ;;
esac

