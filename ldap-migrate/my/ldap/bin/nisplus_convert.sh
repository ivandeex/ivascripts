#!/bin/sh
# $Id: migrate_all_offline.sh,v 1.11 2001/08/13 08:54:26 lukeh Exp $
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
# Migrate all entities from flat files. 
# Make sure that you configure migrate_common.ph to suit
# your site's X.500 naming context and DNS mail domain;
# the defaults may not be correct.
# Luke Howard <lukeh@padl.com> April 1997

INSTDIR="/etc/my/ldap/bin/"
DB="/etc/my/ldap/tmp/nisplus.ldif"
DIR="/etc/my/ldap/tmp/vitanis"

ETC_PASSWD="$DIR/passwd.ldap"
ETC_SHADOW="$DIR/shadow.ldap"
ETC_GROUP="$DIR/group.ldap"
ETC_SERVICES="$DIR/services.ldap"
ETC_PROTOCOLS="$DIR/protocols.ldap"
ETC_FSTAB="$DIR/fstab.ldap"
ETC_RPC="$DIR/rpc.ldap"
ETC_HOSTS="$DIR/hosts.ldap"
ETC_NETWORKS="$DIR/networks.ldap"
ETC_NETGROUP="$DIR/netgroup.ldap"
ETC_ALIASES="$DIR/aliases.ldap"
ETC_ALIASES=/etc/aliases

# saves having to change #! path in each script
PERL=/usr/bin/perl

rm -f $DB
touch $DB

echo "Creating naming context entries..."
echo "# ++++++++ base ++++++++" >> $DB
$PERL -I${INSTDIR} ${INSTDIR}migrate_base.pl		>> $DB
#echo "Migrating aliases..."
#echo "# ++++++++ aliases ++++++++" >> $DB
#$PERL -I${INSTDIR} ${INSTDIR}migrate_aliases.pl 	$ETC_ALIASES >> $DB
#echo "Migrating fstab..."
#$PERL -I${INSTDIR} ${INSTDIR}migrate_fstab.pl		$ETC_FSTAB >> $DB
echo "Migrating groups..."
echo "# ++++++++ groups ++++++++" >> $DB
$PERL -I${INSTDIR} ${INSTDIR}migrate_group.pl		$ETC_GROUP >> $DB
echo "Migrating hosts..."
echo "# ++++++++ hosts ++++++++" >> $DB
$PERL -I${INSTDIR} ${INSTDIR}migrate_hosts.pl		$ETC_HOSTS >> $DB
#echo "Migrating networks..."
#echo "# ++++++++ networks ++++++++" >> $DB
#$PERL -I${INSTDIR} ${INSTDIR}migrate_networks.pl	$ETC_NETWORKS >> $DB
echo "Migrating users..."
export ETC_SHADOW
echo "# ++++++++ passwords ++++++++" >> $DB
$PERL -I${INSTDIR} ${INSTDIR}migrate_passwd.pl		$ETC_PASSWD >> $DB
#echo "Migrating protocols..."
#echo "# ++++++++ protocols ++++++++" >> $DB
#$PERL -I${INSTDIR} ${INSTDIR}migrate_protocols.pl	$ETC_PROTOCOLS >> $DB
#echo "Migrating rpcs..."
#echo "# ++++++++ rpc ++++++++" >> $DB
#$PERL -I${INSTDIR} ${INSTDIR}migrate_rpc.pl		$ETC_RPC >> $DB
#echo "Migrating services..."
#echo "# ++++++++ services ++++++++" >> $DB
#$PERL -I${INSTDIR} ${INSTDIR}migrate_services.pl	$ETC_SERVICES >> $DB
echo "Migrating netgroups..."
echo "# ++++++++ netgroups ++++++++" >> $DB
$PERL -I${INSTDIR} ${INSTDIR}migrate_netgroup.pl	$ETC_NETGROUP >> $DB
#echo "Migrating netgroups (by user)..."
#echo "# ++++++++ netgroups (by user) ++++++++" >> $DB
#$PERL -I${INSTDIR} ${INSTDIR}migrate_netgroup_byuser.pl	$ETC_NETGROUP >> $DB
#echo "Migrating netgroups (by host)..."
#echo "# ++++++++ netgroups (by host) ++++++++" >> $DB
#$PERL -I${INSTDIR} ${INSTDIR}migrate_netgroup_byhost.pl	$ETC_NETGROUP >> $DB
echo "# ++++++++ Das ist fantastisch... ++++++++" >> $DB
echo "Preparing LDAP database..."

echo "Conversion done."

