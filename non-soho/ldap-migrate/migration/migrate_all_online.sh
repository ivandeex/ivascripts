#!/bin/sh
#
# $Id: migrate_all_online.sh,v 1.11 2001/08/13 08:54:26 lukeh Exp $
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

# generic migration script for flat files, YP and NetInfo.
# uses ldapadd

SHELL=/bin/sh
export SHELL

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

if [ "X$LDAPADD" = "X" ]; then
	if [ -x ldapadd ]; then
		LDAPADD=ldapadd
	elif [ -x /usr/local/bin/ldapadd ]; then
		LDAPADD="/usr/local/bin/ldapadd"
	elif [ -x /usr/bin/ldapadd ]; then
		LDAPADD="/usr/bin/ldapadd"
	elif [ -x "$NSHOME/bin/slapd/server/ldapmodify" ]; then
		LDAPADD="$NSHOME/bin/slapd/server/ldapmodify -a -c"
	elif [ -x /usr/iplanet/servers/shared/bin/ldapmodify ]; then
		LDAPADD="/usr/iplanet/servers/shared/bin/ldapmodify -a -c"
	fi
fi

if [ "X$LDAPADD" = "X" ]; then
	echo "Please set the LDAPADD environment variable to point to ldapadd."
	echo
	exit 1
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

if [ "X$LDAP_BASEDN" = "X" ]; then
	defaultcontext=`$PERL -I${INSTDIR} -e 'require "'${INSTDIR}migrate_common.ph'"; print \$DEFAULT_BASE';`
	question="Enter the X.500 naming context you wish to import into: [$defaultcontext]"
	echo "$question " | tr -d '\012' > /dev/tty
	read LDAP_BASEDN
	if [ "X$LDAP_BASEDN" = "X" ]; then
		if [ "X$defaultcontext" = "X" ]; then
			echo "You must specify a default context."
			exit 2
		else
			LDAP_BASEDN=$defaultcontext
		fi
	fi
fi
export LDAP_BASEDN

if [ "X$LDAPHOST" = "X" ]; then
	question="Enter the name of your LDAP server [ldap]:"
	echo "$question " | tr -d '\012' > /dev/tty
	read LDAPHOST
	if [ "X$LDAPHOST" = "X" ]; then
		LDAPHOST="ldap"
	fi
fi

if [ "X$LDAP_BINDDN" = "X" ]; then
	question="Enter the manager DN: [cn=manager,$LDAP_BASEDN]:"
	echo "$question " | tr -d '\012' > /dev/tty
	read LDAP_BINDDN
	if [ "X$LDAP_BINDDN" = "X" ]; then
		LDAP_BINDDN="cn=manager,$LDAP_BASEDN"
	fi
fi
export LDAP_BINDDN

if [ "X$LDAP_BINDCRED" = "X" ]; then
	question="Enter the credentials to bind with:"
	echo "$question " | tr -d '\012' > /dev/tty
	stty -echo
	read LDAP_BINDCRED
	stty echo
	echo
fi

if [ "X$LDAP_PROFILE" = "X" ]; then
	question="Do you wish to generate a DUAConfigProfile [yes|no]?"
	echo "$question " | tr -d '\012' > /dev/tty
	read LDAP_PROFILE
	if [ "X$LDAP_PROFILE" = "X" ]; then
		LDAP_PROFILE="no"
	fi
fi

echo
echo "Importing into $LDAP_BASEDN..."
echo
echo "Creating naming context entries..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_base.pl -n		> $DB
if [ "X$LDAP_PROFILE" = "Xyes" ]; then
	echo "Creating DUAConfigProfile entry..."
	$PERL -I${INSTDIR} ${INSTDIR}migrate_profile.pl "$LDAPHOST" >> $DB
fi
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
echo "Migrating netgroups (by user)..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_netgroup_byuser.pl	$ETC_NETGROUP >> $DB
echo "Migrating netgroups (by host)..."
$PERL -I${INSTDIR} ${INSTDIR}migrate_netgroup_byhost.pl	$ETC_NETGROUP >> $DB

# Try to add the top-level object, because it's usually missing.
TYPE=`echo $LDAP_BASEDN | cut -f1 -d=`
TOP=`echo $LDAP_BASEDN | cut -f1 -d, | cut -f2 -d=`
CLASS=$TYPE
if [ "$CLASS" = "dc" ] ; then
	CLASS=domain
elif [ "$CLASS" = "o" ] ; then
	CLASS=organization
elif [ "$CLASS" = "l" ] ; then
	CLASS=locality
elif [ "$CLASS" = "c" ] ; then
	CLASS=country
elif [ "$CLASS" = "nismapname" ] ; then
	CLASS=nisMap
elif [ "$CLASS" = "cn" ] ; then
	CLASS=container
fi

cat << EOF | $LDAPADD -h $LDAPHOST -D "$LDAP_BINDDN" -x -w "$LDAP_BINDCRED"
dn: $LDAP_BASEDN
$TYPE: $TOP
objectClass: top
objectClass: $CLASS
EOF

echo "Importing into LDAP..."

if [ `basename $LDAPADD` = "slapadd" ]; then
	$LDAPADD -h $LDAPHOST -D "$LDAP_BINDDN" -w "$LDAP_BINDCRED" $@ -f $DB
else
	$LDAPADD -x -h $LDAPHOST -D "$LDAP_BINDDN" -w "$LDAP_BINDCRED" $@ -f $DB
fi

if [ $? -ne 0 ]; then
	echo "$LDAPADD: returned non-zero exit status"
	e=$?
else
	echo "$LDAPADD: succeeded"
	e=$?
fi

rm -f $DB

if [ "X$EXIT" != "Xno" ]; then
	exit $e
fi

