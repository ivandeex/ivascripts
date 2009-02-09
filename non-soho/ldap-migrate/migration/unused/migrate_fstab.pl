#!/usr/bin/perl
#
# $Id: migrate_fstab.pl,v 1.5 2002/07/10 22:43:19 lukeh Exp $
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
# fstab migration tool
# These classes were not published in RFC 2307.
# They are used by MacOS X Server, however.
#

require '/usr/share/openldap/migration/migrate_common.ph';

$PROGRAM = "migrate_fstab.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&open_files();

while(<INFILE>)
{
	chop;
	next if /^#/;
	s/#(.*)$//;

	local($fsname, $dir, $type, $opts, $freq, $passno) = split(/\s+/);
	if ($use_stdout) {
		&dump_mount(STDOUT, $fsname, $dir, $type, $opts, $freq, $passno);
	} else {
		&dump_mount(OUTFILE, $fsname, $dir, $type, $opts, $freq, $passno);
	}
}

sub dump_mount
{
	local($HANDLE, $fsname, $fsdir, $type, $opts, $freq, $passno) = @_;
	local (@options) = split(/,/, $opts);

	print $HANDLE "dn: cn=$fsname,$NAMINGCONTEXT\n";
	print $HANDLE "cn: $fsname\n";
	print $HANDLE "objectClass: mount\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "mountDirectory: $fsdir\n";
	print $HANDLE "mountType: $type\n";
	if (defined($freq)) {
		print $HANDLE "mountDumpFrequency: $freq\n";
	}
	if (defined($passno)) {
		print $HANDLE "mountPassNo: $passno\n";
	}
	foreach $_ (@options) {
		print $HANDLE "mountOption: $_\n";
	}

	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }
