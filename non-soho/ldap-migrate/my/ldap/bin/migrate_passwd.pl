#!/usr/bin/perl
#
# $Id: migrate_passwd.pl,v 1.13 2002/07/06 21:06:45 lukeh Exp $
#
# Copyright (c) 1997 Luke Howard.
# All rights reserved.
#
# Password migration tool. Migrates /etc/shadow as well, if it exists.
#
# Thanks to Peter Jacob Slot <peter@vision.auk.dk>.
#

require 'migrate_common.ph';

$PROGRAM = "migrate_passwd.pl";
$NAMINGCONTEXT = &getsuffix($PROGRAM);

&parse_args();
&read_shadow_file($ARGS[0]);
&open_files();

while(<INFILE>)
{
    chop;
    next if /^#/;
    next if /^\+/;

    s/Ä/Ae/g;
    s/Ë/Ee/g;
    s/Ï/Ie/g;
    s/Ö/Oe/g;
    s/Ü/Ue/g;

    s/ä/ae/g;
    s/ë/ee/g;
    s/ï/ie/g;
    s/ö/oe/g;
    s/ü/ue/g;
    s/ÿ/ye/g;

    s/Æ/Ae/g;
    s/æ/ae/g;
    s/Ø/Oe/g;
    s/ø/oe/g;
    s/Å/Ae/g;
    s/å/ae/g;

    local($user, $pwd, $uid, $gid, $gecos, $homedir, $shell) = split(/:/);
    
    if ($use_stdout) {
	&dump_user(STDOUT, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell);
    } else {
	&dump_user(OUTFILE, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell);
    }
}

sub dump_user
{
	local($HANDLE, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell) = @_;
	local($name,$office,$wphone,$hphone)=split(/,/,$gecos);
	local($sn);	
	local($givenname);	
	local($cn);
	local(@tmp);

	if ($name) { $cn = $name; } else { $cn = $user; }

	$_ = $cn;
	@tmp = split(/\s+/);
	$sn = $tmp[$#tmp];
	pop(@tmp);
	$givenname=join(' ',@tmp);
	
	print $HANDLE "dn: uid=$user,$NAMINGCONTEXT\n";
	print $HANDLE "uid: $user\n";
	print $HANDLE "cn: $cn\n";

	if ($EXTENDED_SCHEMA) {
		if ($wphone) {
			print $HANDLE "telephoneNumber: $wphone\n";
		}
		if ($office) {
			print $HANDLE "roomNumber: $office\n";
		}
		if ($hphone) {
			print $HANDLE "homePhone: $hphone\n";
		}
		if ($givenname) {
			print $HANDLE "givenName: $givenname\n";
		}
		print $HANDLE "sn: $sn\n";
		if ($DEFAULT_MAIL_DOMAIN) {
			print $HANDLE "mail: $user\@$DEFAULT_MAIL_DOMAIN\n";
		}
		if ($DEFAULT_MAIL_HOST) {
			print $HANDLE "mailRoutingAddress: $user\@$DEFAULT_MAIL_HOST\n";
			print $HANDLE "mailHost: $DEFAULT_MAIL_HOST\n";
			#[vit]#print $HANDLE "objectClass: mailRecipient\n";
			print $HANDLE "objectClass: inetLocalMailRecipient\n";
		}
		print $HANDLE "objectClass: person\n";
		print $HANDLE "objectClass: organizationalPerson\n";
		print $HANDLE "objectClass: inetOrgPerson\n";
	} else {
		print $HANDLE "objectClass: account\n";
	}

	print $HANDLE "objectClass: posixAccount\n";
	print $HANDLE "objectClass: top\n";

	if ($DEFAULT_REALM) {
		print $HANDLE "objectClass: kerberosSecurityObject\n";
	}

	if ($shadowUsers{$user} ne "") {
		&dump_shadow_attributes($HANDLE, split(/:/, $shadowUsers{$user}));
	} else {
		print $HANDLE "userPassword: {crypt}$pwd\n";
	}

	if ($DEFAULT_REALM) {
		print $HANDLE "krbName: $user\@$DEFAULT_REALM\n";
	}

	if ($shell) {
		print $HANDLE "loginShell: $shell\n";
	}

	if ($uid ne "") {
		print $HANDLE "uidNumber: $uid\n";
	} else {
		print $HANDLE "uidNumber:\n";
	}

	if ($gid ne "") {
		print $HANDLE "gidNumber: $gid\n";
	} else {
		print $HANDLE "gidNumber:\n";
	}

	if ($homedir) {
		print $HANDLE "homeDirectory: $homedir\n";
	} else {
		print $HANDLE "homeDirectory:\n";
	}

	if ($gecos) {
		print $HANDLE "gecos: $gecos\n";
	}

	print $HANDLE "\n";
}

close(INFILE);
if (OUTFILE != STDOUT) { close(OUTFILE); }

sub read_shadow_file
{
	my $file = shift;
	#print STDERR "trial arg: $file\n";
	$file = $ENV{'ETC_SHADOW'} unless $file;
	#print STDERR "trial ENV: $file\n";
	$file = '/etc/shadow' unless $file;
	#print STDERR "trial final: $file\n";
	open(SHADOW, "$file") || return;
	while(<SHADOW>) {
		chop;
		($shadowUser) = split(/:/, $_);
		$shadowUsers{$shadowUser} = $_;
	}
	close(SHADOW);
}

sub dump_shadow_attributes
{
	local($HANDLE, $user, $pwd, $lastchg, $min, $max, $warn, $inactive, $expire, $flag) = @_;

	print $HANDLE "objectClass: shadowAccount\n";
	if ($pwd) {
		print $HANDLE "userPassword: {crypt}$pwd\n";
	}
	if ($lastchg) {
		print $HANDLE "shadowLastChange: $lastchg\n";
	}
	if ($min) {
		print $HANDLE "shadowMin: $min\n";
	}
	if ($max) {
		print $HANDLE "shadowMax: $max\n";
	}
	if ($warn) {
		print $HANDLE "shadowWarning: $warn\n";
	}
	if ($inactive) {
		print $HANDLE "shadowInactive: $inactive\n";
	}
	if ($expire) {
		print $HANDLE "shadowExpire: $expire\n";
	}
	if ($flag) {
		print $HANDLE "shadowFlag: $flag\n";
	}
}

