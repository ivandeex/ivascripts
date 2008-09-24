#!/usr/bin/perl
#
# $Id: migrate_aliases.pl,v 1.8 2002/06/22 02:50:18 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# alias migration tool
# thanks to Dave McPike
#

require 'migrate_common.ph';

$PROGRAM = "migrate_aliases.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#(.*)$//;

	local($name, $memberstr) = split(/:/,$_,2);
	if ($use_stdout) {
		&dump_alias(STDOUT, $name, $memberstr);
	} else {
		&dump_alias(OUTFILE, $name, $memberstr);
	}
}

sub dump_alias
{
	local($HANDLE, $name, $memberstr) = @_;
	local(@aliases) = split(/,/, $memberstr);
	local $dname = &escape_metacharacters($name);
	print $HANDLE "dn: cn=$dname,$NAMINGCONTEXT\n";
	print $HANDLE "cn: $name\n";
	print $HANDLE "objectClass: nisMailAlias\n";
	print $HANDLE "objectClass: top\n";
	foreach $_ (@aliases) {
		s/^\s+//g;
		print $HANDLE "rfc822MailMember: $_\n";
	}
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }
