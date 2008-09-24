#!/usr/bin/perl
#
# $Id: migrate_networks.pl,v 1.4 1998/10/01 13:14:32 lukeh Exp $
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
# networks migration tool
#
#

require '/usr/share/openldap/migration/migrate_common.ph';

$PROGRAM = "migrate_networks.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#(.*)$//;
	local($networkname, $networkaddr, @aliases) = split(/\s+/);
	
	if ($use_stdout) {
		&dump_network(STDOUT, $networkaddr, $networkname, @aliases);
	} else {
		&dump_network(OUTFILE, $networkaddr, $networkname, @aliases);
	}
}

sub dump_network
{
	local($HANDLE, $networkaddr, $networkname, @aliases) = @_;
	local($dn, $revnetwork);
	return if (!$networkaddr);
	local($cn) = $networkname; # could be $revnetwork

	print $HANDLE "dn: cn=$networkname,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: ipNetwork\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "ipNetworkNumber: $networkaddr\n";
	print $HANDLE "cn: $networkname\n";
	@aliases = uniq($networkname, @aliases);
	foreach $_ (@aliases) {
		if ($_ ne $networkname) {
			print $HANDLE "cn: $_\n";
		}
	}
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

