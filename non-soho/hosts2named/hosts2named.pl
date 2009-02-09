#!/usr/bin/perl
#    h2n - Translate host table to name server file format
#    $Date: 2001/02/02 04:33:35 $  $Revision: 1.1 $
#    h2n -d DOMAIN -n NET [options]

use strict;

# Various defaults
my ($out_dir, $named_dir);
my ($do_aliases, $do_mx, $do_txt, $no_domains, $prefer_mx);
my ($host_file, $comment_file);
my ($dns_host, $dns_user, @server_names, @server_addrs, @mail_hubs);
my ($forced_serial, $def_serial, $def_netmask);
my ($def_refresh, $def_retry, $def_expire, $def_ttl, $def_weight);
my ($domain, $domain_file, $DOM);
my (@skip_domains, %import_domains);
my (%res_recs, %all_comments, %all_hosts, %all_aliases);
my (%has_cnames, %networks, %files, %byname, %byaddr);

sub mangle_time;
sub uniq;

sub pad { sprintf "%-24s",$_[0] }

sub set_defaults
{
    $dns_host = `hostname`; chop $dns_host; $dns_host =~ s/\..*//;
    $dns_user = "root";
    $do_aliases = $do_mx = 1;
    $do_txt = $no_domains = 0;
    $prefer_mx = 2;
    $host_file = "/etc/hosts";
    $comment_file = "";
    $named_dir = "/var/named\n";
    ($def_refresh,$def_retry,$def_expire,$def_ttl) = ("3h","1h","1w","1d");
    $def_weight = 10;
    $def_netmask = "";
    $forced_serial = -1;
    my ($SS,$MM,$HH,$dd,$mm,$yy,$dow,$yday,$isdst) = localtime(time);
    $def_serial = sprintf '%d%02d%02d%02d%02d',
                          ($yy % 100),($mm + 1),$dd,$HH,$MM;
}

# Reverse the octets of an IP address and append in-addr.arpa.
sub rev_net  {
    join('.', reverse(split('\.', $_[0]))) 
    . ($_[1] =~ /[nc]/i ? '' : '.IN-ADDR.ARPA.');
}

# generate resource record data for strings from the
# commment field that are found in the comment file.
sub make_rr
{
    my ($name, @addrs) = @_;
    my $comments;
    foreach my $addr (@addrs) {
	my $key = "$name/$addr";
	$comments .= " $all_comments{$key}";
    }
    my @comments = split(' ', $comments);
    foreach my $comment (@comments) {
	if($res_recs{$comment}){
            # Allow for multiple resource records for a host
	    my (@RRs) = split(/\bIN\b/, $res_recs{$comment});
	    shift @RRs;  # The first entry of the split will be blank
	    foreach my $rr (@RRs)   {
	        printf $DOM pad($name)."  IN  $rr\n";
	    }
	}
    }
}

# generate TXT record data
sub make_txt
{
    my ($name, @addrs) = @_;
    my $comments;
    foreach my $addr (@addrs) {
        my $key = "$name/$addr";
        $comments .= " $all_comments{$key}";
    }
    $comments =~ s/\[no smtp\]//g;
    $comments =~ s/^\s*//;
    $comments =~ s/\s*$//;
    return if $comments eq '';
    printf $DOM pad($name)."  IN  TXT    \"$comments\"\n";
}

# generate MX record data
sub make_mx
{
    my ($name, @addrs) = @_;
    if ($has_cnames{$name})  {
	warn "$name: can't create MX record - CNAME already exists.\n";
	return;
    }
    my $f = 1;
    my $comments;
    foreach my $addr (@addrs) {
        my $key = "$name/$addr";
        $comments .= " $all_comments{$key}";
    }
    if ($comments !~ /\[no smtp\]/ && $prefer_mx == 1) {
	printf $DOM pad($f?$name:'')
                    ."  IN  MX  $def_weight $name.$domain.\n";
	$f = 0;
    }
    foreach my $mx (@mail_hubs)  {
        printf $DOM pad($f?$name:'')."  IN  MX  $mx\n";
        $f = 0;
    }
}

# case insensitive unique
sub uniq
{
    my $name = shift;
    my @vec = sort {$a cmp $b} @_;
    my ($next, $last, @ret);
    foreach $next (@vec) {
	push (@ret, $next) if ($next ne $last) && ($next ne $name);
	$last = $next;
    }
    return @ret;
}

# convert different time units to seconds
# w|W = weeks, d|D = days,
# h|H = hours, m|M = minutes, s|S = seconds
sub mangle_time
{
    my ($t, $u);
    foreach my $p (@_)  {
        $t = $$p;
        $t =~ s/\s//g;
        next if $t =~ /^\d+$/;
        $t =~ tr/A-Z/a-z/;
        $t =~ s/week/w/;  $t =~ s/day/d/;
        $t =~ s/hour/h/;  $t =~ s/min/m/;  $t =~ s/sec/s/;
        die "wrong time units '$$p'\n" unless $t =~ /^(\d+)([wdhm])$/;
        ($t, $u) = ($1, $2);
        $t *= 1      if $u eq 's';
        $t *= 60     if $u eq 'm';
        $t *= 3600   if $u eq 'h';
        $t *= 86400  if $u eq 'd';
        $t *= 604800 if $u eq 'w';
        $$p = $t;
    }
}

# register <name/address> pair in hashes
sub register_pair
{
    my ($name, $addr) = @_;
    $byname{$name} = [] unless (exists $byname{$name});
    push (@{$byname{$name}}, $addr)
        unless (grep {$_ eq $addr} @{$byname{$name}});
    $byaddr{$addr} = [] unless (exists $byaddr{$addr});
    push (@{$byaddr{$addr}}, $name)
        unless (grep {$_ eq $name} @{$byname{$name}});
}

# process name mangling rules
sub mangle_name
{
    my $name = shift;
    my $strip_domain = "." . $domain;
    $strip_domain =~ s/\./\\./g;
    return '' if $no_domains && ($name =~ /\./)
                 && ($name !~ /$strip_domain/);
    foreach my $pat (@skip_domains)  {
        return '' if $name =~ /\.$pat/ or $name eq $pat;
    }
    foreach my $pat (keys %import_domains) {
        if ($name =~ /$pat/)  {
            my $subst = $import_domains{$pat};
            $name =~ s{$pat}{$subst};
            last;
        }
    }
    $name =~ s{$strip_domain}{};
    return $name;
}

sub host_line
{
    my $line = shift;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    #print "got [$line]\n";
    my $comment = "";
    $comment = $1 if $line =~ s{\#\s*(.*?)\s*$}{};
    my ($addr, $name, @aliases) = split(/\s+/,$line);
    my $i;

    $name = mangle_name $name;
    return if $name eq '';
    my @n_aliases;
    for ($i=0; $i<=$#aliases; $i++)  {
        my $tmp = mangle_name $aliases[$i];
        push(@n_aliases, $tmp) if $tmp ne '';
    }
    @aliases = uniq ($name, @n_aliases);

    # find appropriate network.
    my $net;
    my $match = 'none';
    foreach my $n (sort keys %networks) {
        $net = $n;
        $match = $networks{$n}{pattern};
        last if ($addr =~ /^$match\./);
    }
    return if $match eq 'none';
    #print "n=$name a=$addr c=".join(',',@aliases)."t=[$comment]\n";
    register_pair $name, $addr;
    foreach my $alias (@aliases)  {
        register_pair $alias, $addr;
    }
    $all_hosts{$name} .= $addr . " ";
    $all_aliases{$addr} .= join(' ',@aliases) . " ";
    $all_comments{"$name/$addr"} = $comment;
    my $REV = $networks{$net}{file};
    print $REV pad(rev_net($addr,'c'))."  IN  PTR  $name.$domain.\n";
}

sub handle_aliases
{
    # Print cname or address records for each alias.
    my ($name, $addr, $numifs) = @_;
    my @aliases = split(/\s+/, $all_aliases{$addr});
    @aliases = uniq $name, @aliases;
    my $strip_domain = "." . $domain;
    $strip_domain =~ s/\./\\./g;
    foreach my $alias (sort @aliases)  {
        # Skip over the alias if the alias and canonical name only
        # differ in that one of them has the domain appended to it.
        next if $no_domains && $alias =~ /\./; # skip domain names
        $alias =~ s/$strip_domain//;
        next if $alias eq $name;
        # Flag aliases that have already been used
        # in CNAME records or have A records.
        if ($has_cnames{$alias} || $all_hosts{$alias})  {
            #warn "$alias - CNAME or A exists already; alias ignored\n";
            next;
        }
        # For multi-homed host, print an address record for each alias.
        # For a single address host, print a cname record.
        if (0 && $numifs > 1)  {
            print $DOM pad($alias)."  IN  A      $addr\n";
            next;
        }
        print $DOM pad($alias)."  IN  CNAME  $name\n";
        $has_cnames{$alias} = 1;
    }
}

sub handle_host
{
    my $name = shift;
    my @addrs = split(' ', $all_hosts{$name});
    my $numaddrs = $#addrs + 1;
    my $first = 1;
    foreach my $addr (sort @addrs) {
        # Print address record for canonical name.
        if ($has_cnames{$name})  {
            warn "$name - can't create A record: CNAME already exists.\n";
        } else {
            printf $DOM pad($first?$name:'')."  IN  A      $addr\n";
            $first = 0;
        }
    }
    foreach my $addr (sort @addrs) {
        handle_aliases($name,$addr,$numaddrs) if $do_aliases;
    }
    make_mx($name, @addrs) if $do_mx;
    make_txt($name, @addrs) if $do_txt;
    make_rr($name, @addrs) if $comment_file ne "";
}

sub hosts2named
{
    open(HOSTS, $host_file) || die "can not open $host_file";
    while(<HOSTS>)  {
        next if /\s*^#/ or /^\s*$/;  # skip comments and empty lines
        chop;            # remove the trailing newline
        tr/A-Z/a-z/;	 # translate to lower case
        host_line $_;
    }
    close HOSTS;
    # Go through the list of canonical names.
    # If there is more than 1 address associated with the
    # name, it is a multi-homed host.  For each address 
    # look up the aliases since the aliases are associated 
    # with the address, not the canonical name.
    foreach my $name (sort keys %all_hosts)  {
        handle_host $name;
    }
}

# Calculate all the subnets from a network number and mask.
sub make_subnets
{
    my ($network, $mask) = @_;
    my @ans;
    my @net = split(/\./, $network);
    my @mask = split(/\./, $mask);
    my $number = '';
    # Only expand bytes 1, 2, or 3 for DNS purposes
    for (my $i = 0; $i < 3; $i++) {
	if ($mask[$i] == 255) {
	    $number = $number . $net[$i] . '.';
	} elsif ($mask[$i] == 0 || $mask[$i] eq '') {
	    push(@ans, $network);
	    last;
	} else {
	    # This should be a bit-wise or but awk has no or symbol
	    my $howmany = 255 - $mask[$i];
	    for (my $j = 0; $j <= $howmany; $j++) {
		if ($net[$i] + $j <= 255) {
		    my $buf = sprintf("%s%d", $number, $net[$i] + $j);
		    push(@ans, $buf);
		}
	    }
	    last;
	}
    }
    push(@ans, $network) if $#ans < 0;
    return @ans;
}

# build_net
sub build_net
{
    my $net = shift;
    # Create pattern to match against.  
    # The dots must be changed to \. so they aren't used as wildcards.
    my $netpat = $net;
    $netpat =~ s/\./\\./g;
    # Create db files for PTR records.
    my $revaddr = rev_net($net);
    chop $revaddr;   # remove trailing dot
    my $fname = "rev.$net";
    $networks{$net} = { net => $net, rev => $revaddr, pattern => $netpat,
                        fname => $fname, file => "FILE", rev => $revaddr };
    $files{$fname} = { type => "rev", key => $net, name => $revaddr,
                           fname => $fname, file => "FILE" };
}

# parse single option
my @args;

sub parse_option
{
    my ($op, $i) = @_;
    die "unknown argument: $op.\n" if $op !~ /^-.*/;
    my ($net, $subnetmask);
    if ($op eq "--out-dir")  {
        $out_dir = $args[++$i];
        $out_dir =~ s/^\s*//;
        $out_dir =~ s/\s*$//;
        $out_dir .= "/" if $out_dir ne "" && $out_dir !~ /\/$/;
        return $i;
    }
    if ($op eq "-d" || $op eq "--domain")  {
        $domain = $args[++$i];
        # Add entry to the boot file.
        $domain_file = $domain;  #$domain_file =~ s/\..*$//;
        my $fname = "fwd.$domain_file";
        $files{$fname} = { type => "fwd", key => "DOMAIN", name => $domain,
                           fname => $fname, file => "FILE" };
        return $i;
    }
    if ($op eq "-f" || $op eq "--config")  {
        my $file = $args[++$i];
        open(F, $file) || die "Unable to open args file $file: $!";
        my @newargs;
        while (<F>) {
	    next if /^#/ or /^$/;
	    chop;
	    my @targs = split(' ');
	    push(@newargs, @targs);
        }
	close(F);
        my (@saveargs) = @args;
	parse_args(@newargs);
        (@args) = @saveargs;
        return $i;
    }
    if ($op eq "-z" || $op eq "-Z" || $op eq "--primary")  {
        my $adr = $args[++$i];
        push @server_addrs, $adr;
        return $i;
    }
    if ($op eq "--aliases")  { $do_aliases = 1; return; }
    if ($op eq "-A" || $op eq "--no-aliases")  { $do_aliases = 0; return; }
    if ($op eq "--mx")  { $do_mx = 1; return; }
    if ($op eq "-M" || $op eq "--no-mx")  { $do_mx = 0; return; }
    if ($op eq "--external")  { $no_domains = 0; return; }
    if ($op eq "-D" || $op eq "--no-external")  { $no_domains = 1; return; }
    if ($op eq "-t" || $op eq "--txt")  { $do_txt = 1; return; }
    if ($op eq "--no-txt")  { $do_txt = 0; return; }
    if ($op eq "-u" || $op eq "--user")  {
        $dns_user = $args[++$i];
        return $i;
    }
    if ($op eq "-s" || $op eq "--server")  {
	push @server_names, $args[++$i];
        return $i;
    }
    if ($op eq "-m" || $op eq "--mail-hub")  {
        die "Improper format for -m option ignored ($args[$i]).\n"
            if ($args[++$i] !~ /:/);
	push(@mail_hubs, $args[$i]);
        return $i;
    }
    if ($op eq "--import-any-domain")  {
        $import_domains{'\..*'} = ".$domain";
        return;
    }
    if ($op eq "--import-domain")  {
        my $dom = $args[++$i];
        $dom .= ".$domain" if $dom !~ /\./;
        my $pat = ".$dom";
        $pat =~ s/\./\\./g; 
        $import_domains{$pat} = ".$domain";
        return $i;
    }
    if ($op eq "-e" or $op eq "--skip-domain")  {
        my $tmp1 = $args[++$i];
        $tmp1 .= ".$domain" if $tmp1 !~ /\./;
        $tmp1 =~ s/\./\\./g; 
        push @skip_domains, $tmp1;
        return $i;
    }
    if ($op eq "-h" || $op eq "--host")  {
        $dns_host = $args[++$i];
        return $i;
    }
    if ($op eq "-o" || $op eq "--timeouts")  {
        die "Improper format for -o ($args[$i]).\n"
            if ( $args[++$i] !~ /^[:\d]*$/ || split(':', $args[$i]) != 4);
        ($def_refresh, $def_retry, $def_expire, $def_ttl)
            = split(':', $args[$i]);
        return $i;
    }
    if ($op eq "-i" || $op eq "--force-serial")  {
        $forced_serial = $args[++$i];
        return $i;
    }
    if ($op eq "-I" || $op eq "--serial")  {
        $def_serial = $args[++$i];
        return $i;
    }
    if ($op eq "-H" || $op eq "--host-file")  {
        $host_file = $args[++$i];
        die "Invalid file specified for -H ($host_file).\n"
            if (! -r $host_file || -z $host_file);
	return $i;
    }
    if ($op eq "-C" || $op eq "--comment-file")  {
        $comment_file = $args[++$i];
        die "Invalid file specified for -C ($comment_file).\n"
            if (! -r $comment_file || -z $comment_file);
        return $i;
    }
    if ($op eq "-N" || $op eq "--netmask")  {
        $def_netmask = $args[++$i];
        die "Improper subnet mask ($def_netmask).\n"
            if ($def_netmask !~ /^[.\d]*$/ || split('\.', $def_netmask) != 4);
        warn "-N option should come before -n options.\n"
            if scalar(keys(%networks)) > 0;
        return $i;
    }
    if ($op eq "-n" || $op eq "--network")  {
        my ($net, $mask) = split(':',$args[++$i]);
        if ($mask eq '')  {
            $mask = $def_netmask;
        } else {
            die "Improper subnet mask ($mask).\n"
	        if ($mask !~ /^[.\d]*$/ || split('\.', $mask) != 4);
        }
        foreach my $net (make_subnets($net, $mask)) {
            build_net $net;
        }
        return $i;
    }
    die "improper option $op\n";
}

# parse arguments
sub parse_args
{
    @args = @_;
    for (my $i = 0; $i <= $#args; $i++)   {
        my $ni = parse_option ($args[$i], $i);
        $i = $ni if defined $ni;
    }
    die "Must specify at least -d and one -n.\n"
        if scalar(keys(%networks))==0 || $domain eq "";
}

# Establish what we will be using for SOA records
sub fix_up
{
    # Clean up Host
    if ($dns_host =~ /\./) {
	$dns_host = "$dns_host.";
    } else {
	$dns_host = "$dns_host.$domain.";
    }
    $dns_host =~ s/\.+/./g;
    # Clean up authoritative user
    if ($dns_user =~ /@/) {
	if ($dns_user =~ /\./) {
	    $dns_user = "$dns_user.";
	} else {
	    $dns_user = "$dns_user.$domain.";
	}
	$dns_user =~ s/@/./;
    } elsif ($dns_user =~ /\./) {
	$dns_user = "$dns_user.";
    } else {
	$dns_user = "$dns_user.$dns_host";
    }
    $dns_user =~ s/\.+/./g;
    # Clean up nameservers
    if (!defined(@server_names)) {
	push(@server_names, "$dns_host");
    } else {
        my @n_server_names;
	foreach my $s (@server_names) {
            $s .= ".$domain" if $s !~ /\./;
            $s .= "." if $s !~ /\.$/;
            push @n_server_names, $s;
	}
        @server_names = @n_server_names;
    }
    # Clean up MX hosts
    my @n_mail_hubs;
    foreach my $s (@mail_hubs) {
	$s =~ s/:/ /;
        $s .= ".$domain" if $s !~ /\./;
        $s .= "." if $s !~ /\.$/;
        push @n_mail_hubs, $s;
    }
    @mail_hubs = @n_mail_hubs;
    # Create files and make SOAs
    foreach my $fname (sort keys %files)  {
        # Create the SOA record at the beginning of the file
        my ($serial, $refresh, $retry, $expire, $ttl);
        $serial = $forced_serial > 0 ? $forced_serial : $def_serial;
        unless (defined($refresh)) {
            $refresh = $def_refresh;
            $retry = $def_retry;
            $expire = $def_expire;
            $ttl = $def_ttl;
        }
        mangle_time \$refresh, \$retry, \$expire, \$ttl;
        my $fpath = $out_dir . $fname;
        my $type = $files{$fname}{type};
        my $key = $files{$fname}{key};
        open (my $file, "> $fpath") or die "Unable to open $fpath: $!";
        print $file "\$TTL $ttl\n";
        print $file "\@   IN  SOA $dns_host $dns_user ";
        print $file "( ", $serial, " $refresh $retry $expire $ttl )\n";
        foreach (@server_names) { print $file "    IN  NS  $_\n"; }
        if ($type eq "rev")  {
            print $file "\$ORIGIN in-addr.arpa.\n";
            $networks{$key}{file} = $file;
            $files{$fname}{file} = $file;
        } elsif ($type eq "fwd")  {
            foreach my $mx (@mail_hubs)  {
                print $file "    IN  MX  $mx\n" if $prefer_mx == 2 && 0;
            }
            print $file "\$ORIGIN $domain.\n";
            $DOM = $file;
            $files{$fname}{file} = $file;
        } else {
            die "unknown soa file type: $type\n";
        }
        print $file "\n";
    }
    # Generate MX records for the domain
    foreach (@mail_hubs)  { print $DOM pad($domain)."  IN  MX  $_\n"; }
    #printf $DOM "%-20s IN  A     127.0.0.1\n", "localhost";
    #my $file = "DB.127.0.0.1";
    #make_soa ("db.127.0.0", $file);
    #printf $file "%-30s\tIN  PTR   localhost.\n", rev_net("127.0.0.1");
    #close($file);
}

# generate boot.* files
sub gen_boot
{
    # Now open boot file and print saved data
    my $fname;
    $fname = $out_dir . "named.primary";
    open(BOOT, "> $fname")  || die "can not open $fname";
    print BOOT "\ndirectory $named_dir\n";
    foreach my $key (sort keys %files)  {
        my %soa = %{$files{$key}};
        print BOOT "primary\t\t$soa{name}\t\t$soa{type}/$soa{fname}\n";
    }
    print BOOT "cache\t. db.cache\n";
    # boot.cacheonly
    my $fname = $out_dir . "named.cacheonly";
    open (F, ">$fname") || die "Unable to open $fname: $!";
    print F "directory\t$named_dir\n";
    print F "primary\t\t0.0.127.IN-ADDR.ARPA      rev/db.127.0.0\n";
    print F "cache  \t\t.                         db.cache\n";
    close F;
    # xferring secondary
    $fname = $out_dir . "named.secondary";
    open (F, ">$fname") || die "Unable to open $fname: $!";
    print  F "directory\t$named_dir\n";
    print  F "primary\t\t0.0.127.IN-ADDR.ARPA      rev/db.127.0.0\n";
    printf F "secondary\t%-25s  %s\n",
             $domain, join(' ',@server_addrs);
    foreach my $net (sort keys %networks)  {
        printf F "secondary\t%-25s  %s\n",
                 $networks{$net}{rev}, join(' ',@server_addrs);
    }
    print  F "cache\t\t.                       db.cache\n";
    close F;
}

sub main
{
    set_defaults;
    #push(@bootmsgs, "primary\t0.0.127.IN-ADDR.ARPA rev/db.127.0.0\n");
    parse_args(@ARGV);
    if ($comment_file) {
	open(F, $comment_file) or die "cannot open $comment_file: $!";
	while (<F>) {
	    chop;
	    my ($key, $c) = split(':', $_, 2);
	    $res_recs{$key} .= $c;
	}
	close(F);
    }
    fix_up;
    hosts2named;
    # Deal with spcl's
    if (-s "spcl.$domain_file") {
        print $DOM "\$INCLUDE fwd/spcl.$domain_file\n";
    } else {
        unlink "spcl.$domain_file";
    }
    foreach my $net (sort keys %networks) {
        next unless -s "spcl.$net";
        my $netfile = "DB.$net";
        print $netfile "\$INCLUDE fwd/spcl.$net\n";
    }
    gen_boot;
    # close files
    foreach my $fname (sort keys %files)  {
        close $files{$fname}{file};
    }
}

main;


