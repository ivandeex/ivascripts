#!/usr/bin/perl
#
# $Id: migrate_networks.pl,v 1.4 1998/10/01 13:14:32 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# networks migration tool
#
#

require 'migrate_common.ph';

$PROGRAM = "migrate_networks.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#(.*)$//;
	local($networkname, $networkaddr, @aliases) = split(/\s+/);
	
	if ($use_stdout) {
		&dump_network(STDOUT, $networkaddr, $networkname, @aliases);
	} else {
		&dump_network(OUTFILE, $networkaddr, $networkname, @aliases);
	}
}

sub dump_network
{
	local($HANDLE, $networkaddr, $networkname, @aliases) = @_;
	local($dn, $revnetwork);
	return if (!$networkaddr);
	local($cn) = $networkname; # could be $revnetwork

	print $HANDLE "dn: cn=$networkname,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: ipNetwork\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "ipNetworkNumber: $networkaddr\n";
	print $HANDLE "cn: $networkname\n";
	@aliases = uniq($networkname, @aliases);
	foreach $_ (@aliases) {
		if ($_ ne $networkname) {
			print $HANDLE "cn: $_\n";
		}
	}
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

