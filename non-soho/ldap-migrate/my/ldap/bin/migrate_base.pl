#!/usr/bin/perl
#
# $Id: migrate_base.pl,v 1.6 2002/01/15 18:06:12 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
#
# LDIF entries for base DN
#
#

require 'migrate_common.ph';

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

