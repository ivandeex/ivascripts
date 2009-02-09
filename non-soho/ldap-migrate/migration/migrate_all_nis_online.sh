#!/bin/sh
#
# $Id: migrate_all_nis_online.sh,v 1.1.1.1 1998/07/16 11:51:12 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#        This product includes software developed by Luke Howard.
# 4. The name of the other may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE LUKE HOWARD ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL LUKE HOWARD BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

#
# Migrate NIS/YP accounts using ldapadd
#

PATH=$PATH:.
export PATH
INSTDIR=/usr/share/openldap/migration/

TMPDIR="/tmp"
ETC_PASSWD=`mktemp $TMPDIR/passwd.ldap.XXXXXX`
ETC_GROUP=`mktemp $TMPDIR/group.ldap.XXXXXX`
ETC_SERVICES=`mktemp $TMPDIR/services.ldap.XXXXXX`
ETC_PROTOCOLS=`mktemp $TMPDIR/protocols.ldap.XXXXXX`
ETC_FSTAB=`mktemp $TMPDIR/fstab.ldap.XXXXXX`
ETC_RPC=`mktemp $TMPDIR/rpc.ldap.XXXXXX`
ETC_HOSTS=`mktemp $TMPDIR/hosts.ldap.XXXXXX`
ETC_NETWORKS=`mktemp $TMPDIR/networks.ldap.XXXXXX`
ETC_ALIASES=`mktemp $TMPDIR/aliases.ldap.XXXXXX`
EXIT=no

question="Enter the NIS domain to import from (optional): "
echo "$question " | tr -d '\012' > /dev/tty
read DOM
if [ "X$DOM" = "X" ]; then
        DOMFLAG=""
else
	DOMFLAG="-d $DOM"
fi

ypcat $DOMFLAG passwd > $ETC_PASSWD
ypcat $DOMFLAG group > $ETC_GROUP
ypcat $DOMFLAG services > $ETC_SERVICES
ypcat $DOMFLAG protocols > $ETC_PROTOCOLS
touch $ETC_FSTAB
ypcat $DOMFLAG rpc.byname > $ETC_RPC
ypcat $DOMFLAG hosts > $ETC_HOSTS
ypcat $DOMFLAG networks > $ETC_NETWORKS
#ypcat $DOMFLAG -k aliases > $ETC_ALIASES

. ${INSTDIR}migrate_all_online.sh $@

rm -f $ETC_PASSWD
rm -f $ETC_GROUP
rm -f $ETC_SERVICES
rm -f $ETC_PROTOCOLS
rm -f $ETC_FSTAB
rm -f $ETC_RPC
rm -f $ETC_HOSTS
rm -f $ETC_NETWORKS
rm -f $ETC_ALIASES

