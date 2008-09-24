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

/usr/bin/ldapsearch -xD $BINDDN -w $SECRET -b $ROOTDN -s sub -LLL '(objectClass=*)' dn | \
	egrep -v '^$' | \
	grep -v "cn=admin,$ROOTDN" | \
	grep -v "cn=proxy,$ROOTDN" | \
	sort -u > $TMP/cmp-old.dn

cat $FILE | egrep -v '^#' | egrep '^dn:' | \
	sort -u > $TMP/cmp-new.dn

diff -dub $TMP/cmp-old.dn $TMP/cmp-new.dn > $TMP/cmp-uni.dn

cat $TMP/cmp-uni.dn | egrep "^\+dn:" | cut -c 6- > $TMP/cmp-add.dn
cat $TMP/cmp-uni.dn | egrep "^\-dn:" | cut -c 6- > $TMP/cmp-del.dn

delcount=`cat $TMP/cmp-del.dn | wc -w`
if [ $delcount -gt 0 ]; then
  echo "Deleting $delcount records online with $FILE ..."
  [ $DUMMY = n ] && /usr/bin/ldapdelete -xD $BINDDN -w $SECRET -c -v -f $TMP/cmp-del.dn \
			1> ${LOG_DELETE}.log 2> ${LOG_DELETE}.err
fi

addcount=`cat $TMP/cmp-add.dn | wc -w`
AFILE="${FILE}.ok"
cp -f ${FILE} ${AFILE}
if [ $addcount -gt 0 ]; then
  echo "Adding $addcount records online with $FILE ..."
  cat $TMP/cmp-add.dn | \
	awk '{printf("/^dn: %s/ { print \$0; print \"changetype: add\"; n=1; }\n",$1); }' \
	> $TMP/add.awk
  echo '{ if(n==0) print $0; n=0; }' >> $TMP/add.awk
  rm -f ${AFILE}
  cat ${FILE} | awk -f $TMP/add.awk > ${AFILE}
fi

echo "Modifying online with $FILE ..."
[ $DUMMY = n ] && /usr/bin/ldapmodify -xD $BINDDN -w $SECRET -c -v -f ${AFILE} \
			1> ${LOG_MODIFY}.log 2> ${LOG_MODIFY}.err

echo "Update done."

