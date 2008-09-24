#!/usr/bin/perl
#
# $Id: migrate_rpc.pl,v 1.5 2001/02/02 14:20:56 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# Rpc migration tool
#
#

require 'migrate_common.ph';

$PROGRAM = "migrate_rpc.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#(.*)$//;
	local($rpcname, $rpcnumber, @aliases) = split(/\s+/);
	
	if ($use_stdout) {
		&dump_rpc(STDOUT, $rpcname, $rpcnumber, @aliases);
	} else {
		&dump_rpc(OUTFILE, $rpcname, $rpcnumber, @aliases);
	}
}

sub dump_rpc
{
	local($HANDLE, $rpcname, $rpcnumber, @aliases) = @_;
	
	return if (!$rpcname);
	
	print $HANDLE "dn: cn=$rpcname,$NAMINGCONTEXT\n";
	print $HANDLE "objectClass: oncRpc\n";
	print $HANDLE "objectClass: top\n";
	# workaround typo in RFC 2307 where description
	# was made MUST instead of MAY
	print $HANDLE "description: RPC $rpcname\n";
	print $HANDLE "oncRpcNumber: $rpcnumber\n";
	print $HANDLE "cn: $rpcname\n";
	@aliases = uniq($rpcname, @aliases);
	foreach $_ (@aliases) {
		print $HANDLE "cn: $_\n";
	}
	print $HANDLE "description: ONC RPC number $rpcnumber ($rpcname)\n";
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }
