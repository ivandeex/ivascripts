#!/usr/bin/perl
#
# $Id: migrate_netgroup_byuser.pl,v 1.2 1998/10/01 13:14:31 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# netgroup migration tool
#
#

require 'migrate_common.ph';

$PROGRAM = "migrate_netgroup_byuser.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

if (!(-x $REVNETGROUP)) { exit 1; }

&parse_args();
&open_files();

print "dn: nisMapName=netgroup.byuser,$NAMINGCONTEXT\n";
print "objectClass: nisMap\n";
print "objectClass: top\n";
print "nisMapName: netgroup.byuser\n";
print "\n";

open(REVNETGROUP, "$REVNETGROUP -u < $INFILE |");

while(<REVNETGROUP>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#(.*)$//;
	local($key, $val) = split(/\s+/);

	if ($use_stdout) {
		&dump_netgroupbyuser(STDOUT, $key, $val);
	} else {
		&dump_netgroupbyuser(OUTFILE, $key, $val);
	}
}

sub dump_netgroupbyuser
{
	local($HANDLE, $key, $val) = @_;
	return if (!$key);

	print $HANDLE "dn: cn=$key,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: nisObject\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "nisMapName: netgroup.byuser\n";
	print $HANDLE "cn: $key\n";
	print $HANDLE "nisMapEntry: $val\n";
	print $HANDLE "\n";
}

close(INFILE);
close(REVNETGROUP);

if (OUTFILE != STDOUT) { close(OUTFILE); }

