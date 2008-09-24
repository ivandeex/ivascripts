#!/usr/bin/perl
#
# $Id: migrate_netgroup_byhost.pl,v 1.2 1998/10/01 13:14:30 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# netgroup migration tool
#
#

require 'migrate_common.ph';

$PROGRAM = "migrate_netgroup_byhost.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

if (!(-x $REVNETGROUP)) { exit 1; }

&parse_args();
&open_files();

print "dn: nisMapName=netgroup.byhost,$NAMINGCONTEXT\n";
print "objectClass: nisMap\n";
print "objectClass: top\n";
print "nisMapName: netgroup.byhost\n";
print "\n";

open(REVNETGROUP, "$REVNETGROUP -h < $INFILE |");

while(<REVNETGROUP>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#(.*)$//;
	local($key, $val) = split(/\s+/);

	if ($use_stdout) {
		&dump_netgroupbyhost(STDOUT, $key, $val);
	} else {
		&dump_netgroupbyhost(OUTFILE, $key, $val);
	}
}

sub dump_netgroupbyhost
{
	local($HANDLE, $key, $val) = @_;
	return if (!$key);

	print $HANDLE "dn: cn=$key,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: nisObject\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "nisMapName: netgroup.byhost\n";
	print $HANDLE "cn: $key\n";
	print $HANDLE "nisMapEntry: $val\n";
	print $HANDLE "\n";
}

close(INFILE);
close(REVNETGROUP);

if (OUTFILE != STDOUT) { close(OUTFILE); }

