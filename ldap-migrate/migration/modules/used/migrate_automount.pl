#!/usr/bin/perl
#
# migrate_automount.pl by Adrian Likins <alikins@redhat.com>
# Based on migrate_services.pl, Copyright (c) 1997 Luke Howard.
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
# services migration tool
#

require '/usr/share/openldap/migration/migrate_common.ph';
 
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

