#!/usr/bin/perl
#
# $Id: migrate_fstab.pl,v 1.5 2002/07/10 22:43:19 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
#
# fstab migration tool
# These classes were not published in RFC 2307.
# They are used by MacOS X Server, however.
#

require 'migrate_common.ph';

$PROGRAM = "migrate_fstab.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next if /^#/;
	s/#(.*)$//;

	local($fsname, $dir, $type, $opts, $freq, $passno) = split(/\s+/);
	if ($use_stdout) {
		&dump_mount(STDOUT, $fsname, $dir, $type, $opts, $freq, $passno);
	} else {
		&dump_mount(OUTFILE, $fsname, $dir, $type, $opts, $freq, $passno);
	}
}

sub dump_mount
{
	local($HANDLE, $fsname, $fsdir, $type, $opts, $freq, $passno) = @_;
	local (@options) = split(/,/, $opts);

	print $HANDLE "dn: cn=$fsname,$NAMINGCONTEXT\n";
	print $HANDLE "cn: $fsname\n";
	print $HANDLE "objectClass: mount\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "mountDirectory: $fsdir\n";
	print $HANDLE "mountType: $type\n";
	if (defined($freq)) {
		print $HANDLE "mountDumpFrequency: $freq\n";
	}
	if (defined($passno)) {
		print $HANDLE "mountPassNo: $passno\n";
	}
	foreach $_ (@options) {
		print $HANDLE "mountOption: $_\n";
	}

	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }
