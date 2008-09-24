#!/usr/bin/perl
#
# $Id: migrate_netgroup_byuser.pl,v 1.2 1998/10/01 13:14:31 lukeh Exp $
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
#
#

require '/usr/share/openldap/migration/migrate_common.ph';

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

