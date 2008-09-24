#!/bin/bash

DUMMY=n

FILE="/etc/my/ldap/tmp/nisplus.ldif"
BINDDN="cn=admin,ou=div03,o=rsce"
ROOTDN="ou=div03,o=rsce"
SECRET=`head -1 /etc/ldap.secret`
LOG_DELETE="/etc/my/log/ldap-delete"
LOG_MODIFY="/etc/my/log/ldap-modify"
TMP="/etc/my/ldap/tmp"

[ "x$1" = "x" ] || FILE=$1

PID=`/usr/bin/pgrep -n slapd`
if [ "x$PID" = "x" ]; then
  echo "error: slapd not running"
  exit 1
fi

/usr/bin/ldapsearch -xD $BINDDN -w $SECRET -b $ROOTDN -s sub -LLL '(objectClass=*)'  \
	> $TMP/ldap-cur.dn

