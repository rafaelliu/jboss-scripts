jboss-scripts
=============
Custom scripts I use for JBoss AS7 and EAP6.

Works on WildFly too, but for some reason it's jboss-cli is now using HTTP endpoint (instead of native), which is not enabled by default on host-slave.xml. It's still in Alpha and this may change in the future, but for now enable the HTTP connector in order for the scripts to work.
