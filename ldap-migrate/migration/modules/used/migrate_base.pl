#!/usr/bin/perl
#
# $Id: migrate_base.pl,v 1.6 2002/01/15 18:06:12 lukeh Exp $
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
# LDIF entries for base DN
#
#

require '/usr/share/openldap/migration/migrate_common.ph';

$PROGRAM = "migrate_base.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);


sub gen_namingcontexts
{
	# uniq naming contexts
	local (@ncs, $map, $nc);
	foreach $map (keys %NAMINGCONTEXT) {
		$nc = $NAMINGCONTEXT{$map};
		if (!grep(/^$nc$/, @ncs)) {
			push(@ncs, $nc);
			&ldif_entry(STDOUT, $nc, $DEFAULT_BASE);
		}
	}
}

sub gen_suffix
{
	@dn_components = split(/,/, $DEFAULT_BASE);
	for ($dnloc = ($#dn_components-1); $dnloc >= 0; $dnloc--)
		{
		&base_ldif;
		}
}

sub base_ldif
{
	# we don't handle multivalued RDNs here; they're unlikely
	# in a base DN.
	# Don't escape commas either XXX
	local ($rdn) = $dn_components[$dnloc];
	local ($remaining_dn) = join(',', @dn_components[($dnloc + 1)..$#dn_components]);
	&ldif_entry(STDOUT, $rdn, $remaining_dn);
}

sub main
{
	if ($ARGV[0] ne "-n") {
		&gen_suffix();
	}
	&gen_namingcontexts();
}

&main;

