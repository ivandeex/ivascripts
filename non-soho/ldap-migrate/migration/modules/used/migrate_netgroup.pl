#!/usr/bin/perl
#
# $Id: migrate_netgroup.pl,v 1.7 2002/06/22 18:36:22 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#        This product includes software developed by Luke Howard.
# 4. The name of the other may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE LUKE HOWARD ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL LUKE HOWARD BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
#
# netgroup migration tool
# line continuation support by Bob Apthorpe
#

require '/usr/share/openldap/migration/migrate_common.ph';

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
			print $HANDLE "nisNetgroupTriple: $_\n";
		} else {
			print $HANDLE "memberNisNetgroup: $_\n";
		}
	}
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

