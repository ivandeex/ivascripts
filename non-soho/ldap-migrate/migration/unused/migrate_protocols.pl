#!/usr/bin/perl
#
# $Id: migrate_protocols.pl,v 1.6 2002/06/22 02:50:18 lukeh Exp $
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
# protocol migration tool
#
#

require '/usr/share/openldap/migration/migrate_common.ph';

$PROGRAM = "migrate_protocols.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#(.*)$//;

	local($name, $number, @aliases) = split(/\s+/);
	if ($use_stdout) {
		&dump_protocol(STDOUT, $name, $number, @aliases);
	} else {
		&dump_protocol(OUTFILE, $name, $number, @aliases);
	}
}

sub dump_protocol
{
	local($HANDLE, $name, $number, @aliases) = @_;
		
	local $dname = &escape_metacharacters($name);
	print $HANDLE "dn: cn=$dname,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: ipProtocol\n";
	print $HANDLE "objectClass: top\n";
	# workaround typo in RFC 2307 where description
	# was made MUST instead of MAY
	print $HANDLE "description: Protocol $name\n";
	print $HANDLE "ipProtocolNumber: $number\n";
	print $HANDLE "cn: $name\n";
	@aliases = uniq($name, @aliases);
	foreach $_ (@aliases) {
		print $HANDLE "cn: $_\n";
	}
	print $HANDLE "description: IP protocol $number ($name)\n";
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }
