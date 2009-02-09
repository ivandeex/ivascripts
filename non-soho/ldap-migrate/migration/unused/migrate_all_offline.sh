#!/bin/sh
#
# $Id: migrate_all_offline.sh,v 1.11 2001/08/13 08:54:26 lukeh Exp $
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
# Migrate all entities from flat files. 
#
# Make sure that you configure migrate_common.ph to suit
# your site's X.500 naming context and DNS mail domain;
# the defaults may not be correct.
#
# Luke Howard <lukeh@padl.com> April 1997
#

INSTDIR=/usr/share/openldap/migration/
DB=`mktemp /tmp/nis.ldif.XXXXXX`

if [ "X$ETC_ALIASES" = "X" ]; then
	ETC_ALIASES=/etc/aliases
fi
#if [ "X$ETC_FSTAB" = "X" ]; then
#	ETC_FSTAB=/etc/fstab
#fi
if [ "X$ETC_HOSTS" = "X" ]; then
	ETC_HOSTS=/etc/hosts
fi
if [ "X$ETC_NETWORKS" = "X" ]; then
	ETC_NETWORKS=/etc/networks
fi
if [ "X$ETC_PASSWD" = "X" ]; then
	ETC_PASSWD=/etc/passwd
fi
if [ "X$ETC_GROUP" = "X" ]; then
	ETC_GROUP=/etc/group
fi
if [ "X$ETC_SERVICES" = "X" ]; then
	ETC_SERVICES=/etc/services
fi
if [ "X$ETC_PROTOCOLS" = "X" ]; then
	ETC_PROTOCOLS=/etc/protocols
fi
if [ "X$ETC_RPC" = "X" ]; then
	ETC_RPC=/etc/rpc
fi
if [ "X$ETC_NETGROUP" = "X" ]; then
	ETC_NETGROUP=/etc/netgroup
fi

# saves having to change #! path in each script
if [ "X$PERL" = "X" ]; then
	if [ -x /usr/bin/perl ]; then
		PERL="/usr/bin/perl"
	elif [ -x /usr/local/bin/perl ]; then
		PERL="/usr/local/bin/perl"
	else
		echo "Can't find Perl!"
		exit 1
	fi
fi

if [ "X$LDIF2LDBM" = "X" ]; then
	if [ -x /usr/local/etc/ldif2ldbm ]; then
		LDIF2LDBM="/usr/local/etc/ldif2ldbm"
	elif [ -x /usr/local/sbin/ldif2ldbm ]; then
		LDIF2LDBM="/usr/local/sbin/ldif2ldbm"
	elif [ -x /usr/sbin/ldif2ldbm ]; then
		LDIF2LDBM="/usr/sbin/ldif2ldbm"
	elif [ -x "$NSHOME/bin/slapd/server/ns-slapd" ]; then
		LDIF2LDBM="$NSHOME/bin/slapd/server/ns-slapd ldif2db -f $NSHOME/slapd-$serverID"
	elif [ -x /usr/iplanet/servers/bin/slapd/server/dsimport ]; then
		LDIF2LDBM="/usr/iplanet/servers/bin/slapd/server/dsimport"
	elif [ -x /usr/local/sbin/slapadd ]; then
		SLAPADD="/usr/local/sbin/slapadd"
	elif [ -x /usr/sbin/slapadd ]; then
		SLAPADD="/usr/sbin/slapadd"
	else
		echo "Can't find ldif2ldbm or slapadd!"
		exit 2
	fi
fi

echo "Creating naming context entries..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_base.pl		> $DB
echo "Migrating aliases..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_aliases.pl 	$ETC_ALIASES >> $DB
#echo "Migrating fstab..."
#$PERL -I${INSTDIR} ${INSTDIR}migrate_fstab.pl		$ETC_FSTAB >> $DB
echo "Migrating groups..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_group.pl		$ETC_GROUP >> $DB
echo "Migrating hosts..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_hosts.pl		$ETC_HOSTS >> $DB
echo "Migrating networks..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_networks.pl	$ETC_NETWORKS >> $DB
echo "Migrating users..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_passwd.pl		$ETC_PASSWD >> $DB
echo "Migrating protocols..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_protocols.pl	$ETC_PROTOCOLS >> $DB
echo "Migrating rpcs..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_rpc.pl		$ETC_RPC >> $DB
echo "Migrating services..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_services.pl	$ETC_SERVICES >> $DB
echo "Migrating netgroups..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_netgroup.pl	$ETC_NETGROUP >> $DB
echo "Importing into LDAP..."
echo "Migrating netgroups (by user)..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_netgroup_byuser.pl	$ETC_NETGROUP >> $DB
echo "Migrating netgroups (by host)..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_netgroup_byhost.pl	$ETC_NETGROUP >> $DB
echo "Preparing LDAP database..."
if [ "X$SLAPADD" = "X" ]; then
	$LDIF2LDBM -i $DB $@
else
	$SLAPADD -l $DB $@
fi
EXITCODE=$?

rm -f $DB

if [ "X$EXIT" != "Xno" ]; then
	exit $EXITCODE
fi

echo "Done."
