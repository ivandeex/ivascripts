#!/usr/bin/perl
#
# $Id: migrate_hosts.pl,v 1.4 1998/10/01 13:14:28 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# hosts migration tool
#
#

require 'migrate_common.ph';

$PROGRAM = "migrate_hosts.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next unless ($_);
	next if /^\s*#/;
	s/#\s*(.*?)\s*$//;
	my $comment = $1;
	local($hostaddr, $hostname, @aliases) = split(/\s+/);
	
	if ($use_stdout) {
		&dump_host(STDOUT, $hostaddr, $hostname, $comment, @aliases);
	} else {
		&dump_host(OUTFILE, $hostaddr, $hostname, $comment, @aliases);
	}
}


sub dump_host
{
	local($HANDLE, $hostaddr, $hostname, $comment, @aliases) = @_;
	local($dn);
	return if (!$hostaddr);

	print $HANDLE "dn: cn=$hostname,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "objectClass: ipHost\n";
	print $HANDLE "objectClass: device\n";
	print $HANDLE "ipHostNumber: $hostaddr\n";
	print $HANDLE "cn: $hostname\n";
	print $HANDLE "description: $comment\n" if $comment;
	@aliases = uniq($hostname, @aliases);
	foreach $_ (@aliases) {
		if ($_ ne $hostname) {
			print $HANDLE "cn: $_\n";
		}
	}
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

