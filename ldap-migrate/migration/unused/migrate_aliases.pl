#!/usr/bin/perl
#
# $Id: migrate_aliases.pl,v 1.8 2002/06/22 02:50:18 lukeh Exp $
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
# alias migration tool
# thanks to Dave McPike
#

require '/usr/share/openldap/migration/migrate_common.ph';

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
