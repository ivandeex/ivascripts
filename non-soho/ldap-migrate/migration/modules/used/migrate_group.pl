#!/usr/bin/perl
#
# $Id: migrate_group.pl,v 1.6 1998/10/01 13:14:27 lukeh Exp $
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
# Group migration tool
#
#

require '/usr/share/openldap/migration/migrate_common.ph';

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

