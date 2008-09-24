#!/usr/bin/perl
#
# $Id: migrate_group.pl,v 1.6 1998/10/01 13:14:27 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
#
# Group migration tool
#
#

require 'migrate_common.ph';

$PROGRAM = "migrate_group.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next if /^#/;
	next if /^\+/;

	local($group, $pwd, $gid, $users) = split(/:/);
	
	if ($use_stdout) {
		&dump_group(STDOUT, $group, $pwd, $gid, $users);
	} else {
		&dump_group(OUTFILE, $group, $pwd, $gid, $users);
	}
}

sub dump_group
{
	local($HANDLE, $group, $pwd, $gid, $users) = @_;
	
	local(@members) = split(/,/, $users);
	
	print $HANDLE "dn: cn=$group,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: posixGroup\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "cn: $group\n";
	if ($pwd) {
		print $HANDLE "userPassword: {crypt}$pwd\n";
	}

	print $HANDLE "gidNumber: $gid\n";

	@members = uniq($group, @members);
	foreach $_ (@members) {
		print $HANDLE "memberUid: $_\n";
	}

	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

