#!/usr/bin/perl
#
# migrate_automount.pl by Adrian Likins <alikins@redhat.com>
# Based on migrate_services.pl, Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# services migration tool
#

require 'migrate_common.ph';
 
$PROGRAM = "migrate_automount.pl"; 
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

$mapname=$ARGV[0];
# normalize the mapname
$mapname =~ s?/etc/(.*)?$1?;

if ($use_stdout){
	$HANDLE=STDOUT;
} else {
	$HANDLE=OUTFILE;
}

# setup the top level for this automounter map
print $HANDLE "dn: nisMapName=$mapname,$NAMINGCONTEXT\n";
print $HANDLE "objectClass: top\n";
print $HANDLE "objectClass: nisMap\n";
print $HANDLE "nisMapName: $mapname\n";
print $HANDLE "\n";

while(<INFILE>)
{
	chop;
	next unless ($_);
	next if /^#/;
	s/#(.*)$//;
#	local($mountkey, $portproto, @aliases) = split(/\s+/);
	if(m/(.*?)\s(.*)/){
	  $key = $1;
	  $value = $2;
	}	
	if ($use_stdout) {
		&dump_automount(STDOUT,$key,$value,$mapname);
	} else {
		&dump_automount(OUTFILE, $key,$value,$mapname);
	}
}

sub dump_automount
{
	local($HANDLE, $key, $value,$mapname) = @_;
	
#	local($port, $proto) = split(/\//, $portproto);
	
	return if (!$mapname);

	if ($key eq "*"){	
		# since * isnt a valid attrib, replace it with "/" 
		# which isnt a valid filename :->
		print $HANDLE "dn: cn=/,nisMapName=$mapname,$NAMINGCONTEXT\n";
	} else {
		print $HANDLE "dn: cn=$key,nisMapName=$mapname,$NAMINGCONTEXT\n";
	}
	print $HANDLE "objectClass: nisObject\n";
	print $HANDLE "cn: $key\n";
	print $HANDLE "nisMapEntry: $value\n";
	print $HANDLE "nisMapName: $mapname\n";
	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

