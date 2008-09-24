#!/bin/sh

exec >> /etc/my/log/nisplus-import.log 2>&1

INCOMING="/var/ext/ext1/nisplus/vitanis.tar"
TAR="/etc/my/ldap/incoming/vitanis.tar"

[ -r $INCOMING ] && mv -f $INCOMING $TAR

INSTDIR="/etc/my/ldap/bin"
DB="/etc/my/ldap/tmp/nisplus.ldif"
DIR="/etc/my/ldap/tmp/vitanis"
TMP="/etc/my/ldap/tmp"
LOGDIR="/etc/my/log"

if [ ! -r ${TAR} ]; then
  echo "= nisplus not changed: `date`"
  exit 1
fi

echo "+ NISPLUS `date`"

PWD=`pwd` ; rm -rf ${DIR} ; mkdir ${DIR} ; cd ${DIR}/.. ; tar xf ${TAR} ; cd $PWD

mv -f ${TAR} ${TAR}.ok
mv -f ${DB} ${DB}.old

${INSTDIR}/nisplus_convert.sh
${INSTDIR}/nisplus_modify.sh

chown root:root ${TAR} ${TAR}.ok ${DB} ${DB}.old > /dev/null 2>&1
chmod 600 ${TAR} ${TAR}.ok ${DB} ${DB}.old > /dev/null 2>&1
chown -R root:root ${TMP}
chmod 700 ${TMP}
chown root:root /etc/my ${LOGDIR}
chmod 700 ${LOGDIR}
chmod 600 ${LOGDIR}/*

echo "- NISPLUS `date`"
echo "."

