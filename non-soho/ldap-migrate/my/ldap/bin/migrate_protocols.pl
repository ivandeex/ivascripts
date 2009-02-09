#!/usr/bin/perl
#
# $Id: migrate_protocols.pl,v 1.6 2002/06/22 02:50:18 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# protocol migration tool
#
#

require 'migrate_common.ph';

$PROGRAM = "migrate_protocols.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#\s*(.*?)\s*$//;
	my $comment = $1;

	local($name, $number, @aliases) = split(/\s+/);
	if ($use_stdout) {
		&dump_protocol(STDOUT, $name, $number, $comment, @aliases);
	} else {
		&dump_protocol(OUTFILE, $name, $number, $comment, @aliases);
	}
}

sub dump_protocol
{
	local($HANDLE, $name, $number, $comment, @aliases) = @_;
		
	local $dname = &escape_metacharacters($name);
	print $HANDLE "dn: cn=$dname,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: ipProtocol\n";
	print $HANDLE "objectClass: top\n";
	# workaround typo in RFC 2307 where description
	# was made MUST instead of MAY
	print $HANDLE "description: Protocol $name\n" unless $comment;
	print $HANDLE "description: $comment\n" if $comment;
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
