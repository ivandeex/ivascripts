#!/usr/bin/perl
#
# $Id: migrate_profile.pl,v 1.2 2001/01/07 22:31:46 lukeh Exp $
#
# Copyright (c) 2001 Luke Howard.
# All rights reserved.
#
# LDIF entries for base DN
#
#

require 'migrate_common.ph';

$PROGRAM = "migrate_profile.pl";

sub gen_profile
{
	print "dn: cn=config,$DEFAULT_BASE\n";
	print "cn: config\n";
	print "objectClass: DUAConfigProfile\n";
	print "objectClass: posixNamingProfile\n";
	print "defaultServerList: $LDAPHOST\n";
	print "defaultSearchBase: $DEFAULT_BASE\n";
	print "defaultSearchScope: one\n";

	foreach $_ (keys %NAMINGCONTEXT) {
		if (!/_/) {
			print "serviceSearchDescriptor: $_:$NAMINGCONTEXT{$_},$DEFAULT_BASE\n";
		}
	}
	print "\n";
}

sub main
{
	if ($#ARGV < 0) {
		print STDERR "Usage: $PROGRAM ldaphost\n";
		exit 1;
	}

	$LDAPHOST = $ARGV[0];
	&gen_profile();
}

&main;

