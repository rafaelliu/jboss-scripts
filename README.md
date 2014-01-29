Jboss Management 
=================

More info: http://www.rafaelliu.net/2013/10/04/jboss-as7-enhanced-init-script-domain-mode/

## Features

* Allows to configure remote DC/HCs
* Can deal with custom instances (e.g. $JBOSS_HOME/domain,  $JBOSS_HOME/my-domain, etc.)
* Uses CLI instead of Linux commands (ps and pid files) for operations
* Checks whether there’s already a running instance before start
* Caches DC configuration by default, allowing to start with cached config (in case DC is down)
* Parameters are: {start [console|sync|async|cached]|stop|restart|status|cli|tail [server name]}
* start or start async: fires and forget, will return true even if boot process later fails
* start sync: start JBoss process and only exists after verifying host-state
* start console: starts JBoss and tail $JBOSS_CONSOLE_LOG file (must be defined)
* start cached: to be used in case DC is down, it will use the latest cached version of DC configuration (starts with –cached-dc by default)
* cli: open instance’s CLI or executes anything after as a command (e.g. service jboss cli /host=master:shutdown)
* tail: tail instance’s host-controller.log or use the parameter after to look for a server’s server.log (e.g. service jboss tail server-one)

## How to use it

The main script is jboss-as-domain.sh but it is not used directly. For each instance you should create a init script based on jboss-init.sh, this is the only file you should be editing. Most of the parameters are self-explanatory, but a few are worth mentioning:

* **MASTER_ADDRESS**: this should be set with DC’s address if (and only if) this instance is a HC. Leave it commented if it’s the DC
* **JBOSS_CONSOLE_LOG**: useful for debugging. If defined, all STDOUT will be redirected to this file. It is not rotated, it’s a simple bash redirect as in &>
* **DOMAIN_PROFILE**: is the name of the domain folder (e.g. production, staging, development, etc)
* The script relays on a few standards I use:

* Configuration of HC is done through host-slave.xml
* Configuration of DC is done through host-master.xml
* Profiles have their own bin dir

## Provisioning a DC

1. Copy the template to DC’s server
2. Edit **$JBOSS_HOME/production/bin/jboss-init.sh**
3. Set the **BIND_ADDRESS**
4. Comment **MASTER_ADDRESS**
5. Link the init script ln -s **$JBOSS_HOME/production/bin/jboss-init.sh /etc/init.d/jboss-prod**
6. Provisioning HCs

## Provisioning HCs

1. Copy the template to HC’s server
2. Edit **$JBOSS_HOME/production/bin/jboss-init.sh**
	1. Set the **BIND_ADDRESS**
	2. Set the **MASTER_ADDRESS** with DC’s BIND_ADDRESS
3. Register this HC’s user in DC’s ManagementRealm
4. Link the init script **ln -s $JBOSS_HOME/production/bin/jboss-init.sh /etc/init.d/jboss-prod**

## NOTE 

For some reason WildFly’s jboss-cli is now using HTTP endpoint (instead of native), which is not enabled by default on host-slave.xml. It’s still in Alpha and this may change in the future, but for now enable the HTTP connector in order for the script to work.