#!/bin/bash

FILE="/etc/my/ldap/tmp/nisplus.ldif"
BINDDN="cn=admin,ou=div03,o=rsce"
SECRET=`head -1 /etc/ldap.secret`
LOG_INIT="/etc/my/log/ldap-init.log"

[ "x$1" = "x" ] || FILE=$1

PID=`/usr/bin/pgrep -n slapd`
if [ "x$PID" = "x" ]; then
  echo "Modifying OFFLINE from $FILE..."
  /usr/sbin/slapadd -n 0 -v -c -l $FILE > $LOG_INIT 2>&1
else
  echo "Modifying online from $FILE..."
  /usr/bin/ldapmodify -xD $BINDDN -w $SECRET -c -v -f $FILE > $LOG_INIT 2>&1
fi

echo "Modification done. See details in ${LOG}."

