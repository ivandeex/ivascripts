#!/usr/bin/perl
#
# $Id: migrate_netgroup.pl,v 1.7 2002/06/22 18:36:22 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# netgroup migration tool
# line continuation support by Bob Apthorpe
#

require 'migrate_common.ph';

$PROGRAM = "migrate_netgroup.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

local $continuing = 0;
local $card = '';
local $record = '';
readloop:
while(defined($card = <INFILE>))
{
	chomp $card;
	next readloop unless ($card);
	next readloop if ($card =~ m/^\s*#/o);
	$card =~ s/#.*$//o;
	$card =~ s/^\s+//o;
	$card =~ s/\s+$//o;

	unless ($continuing) {
		if ($record) {
			local($netgroupname, @members) = split(m/\s+/o, $record);

			if ($use_stdout) {
				&dump_netgroup(STDOUT, $netgroupname, @members);
			} else {
				&dump_netgroup(OUTFILE, $netgroupname, @members);
			}
			$record = '';
		}
	}

	if ($card =~ m#\\\s*$#o) {
 		$card =~ s#\s*\\\s*$# #o;
		$continuing = 1;
	} else {
		$continuing = 0;
	}

	if ($record) {
		$record .= ' ' . $card;
	} else {
		$record = $card;
	}
}

if ($continuing) {
	print STDERR <<"TRUNCMSG";
# Warning: It appears your netgroup file has been truncated or there's a
# stray continuation marker (\\) in the file. The record causing problems
# is:
# $record
# Sorry.
TRUNCMSG

} else {
	if ($record) {
		local($netgroupname, @members) = split(m/\s+/o, $record);

		if ($use_stdout) {
			&dump_netgroup(STDOUT, $netgroupname, @members);
		} else {
			&dump_netgroup(OUTFILE, $netgroupname, @members);
		}
		$record = '';
	}
}

sub ces_uniq
{
	local(@vec) = sort @_;
	local(@ret);
	local($next, $last);
	foreach $next (@vec) {
		if ($next ne $last) {
			push (@ret, $next);
		}
		$last = $next;
	}
	return @ret;
}

sub dump_netgroup
{
	local($HANDLE, $netgroupname, @members) = @_;
	return if (!$netgroupname);

	print $HANDLE "dn: cn=$netgroupname,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: nisNetgroup\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "cn: $netgroupname\n";

	@members = ces_uniq(@members);

	foreach $_ (@members) {
		if (/^\(/) {
			# [vit] 05.12.2003
			#	hack for OpenLDAP not supporting underscores in host names
			my $s = $_;
			$s =~ s/_/\-/g;
			print $HANDLE "nisNetgroupTriple: $s\n";
			##print $HANDLE "nisNetgroupTriple: $_\n";
			# /[vit]
		} else {
			print $HANDLE "memberNisNetgroup: $_\n";
		}
	}
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

