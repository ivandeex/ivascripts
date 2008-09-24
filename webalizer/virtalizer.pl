#!/usr/bin/perl
use strict;

# gather virtual host definitions
my $httpd_root = "/etc/httpd";
my $httpd_conf = "$httpd_root/conf/httpd.conf";
my $usage_root = "/var/www/usage";
my $global_cfg = "/etc/webalizer.conf";
my $def_vhost = "gclimate.com";
my $webal_bin = "/usr/bin/webalizer";
my $webal_opts = "";
my $strip_domain = 0;
my $debug = 1;
my $skip_port = 1;
my $make_stubs = 0;

my (%vhosts, @vhosts, @logs, %fds, %warn_vhost);
my ($vhost, $alias, $log, $fd);

$webal_opts .= " -d" if $debug;

sub noquot ($) { $_ = $_[0]; s/^\s*\"?\s*//; s/\s*\"?\s*$//; $_; }

sub gather_defs ($$$;$)
{
  my ($path, $root, $vhost, $vprev) = @_;
  #print "gather_defs: $path $vhost $root $vhost $vprev\n";
  $path = "$root/$path" if $path !~ /^\//;
  $vprev = $vhost unless $vprev;
  if ($path =~ /\*/) {
    for my $file (sort glob $path) {
      gather_defs($file,$root,$vhost,$vprev)
        if -f $file && -r $file;
    }
    return;
  }
  local *CONF;
  open (CONF, $path) or return;
  while (<CONF>) {
    next if /^\s*\#/;
    if (/^ServerRoot\s+?(\S+)/) {
      $root = noquot($1);
      $root =~ s/\/+$//;
      next;
    }
    if (/^<\s*VirtualHost.*?>/) {
      $vprev = $vhost;
      next;
    }
    if (/^<\s*\/\s*VirtualHost.*?>/) {
      $vhost = $vprev;
      next;
    }
    if (/^ServerName\s+(\S+)/) {
      $vhost = noquot($1);
      $vhost =~ s/\:\d+$//;
      $vhost =~ s/\..*$// if $strip_domain;
      $vhosts{$vhost} = $vhost;
      next;
    }
    if (/^ServerAlias\s+(\S+)/) {
      $alias = noquot($1);
      $alias =~ s/\:\d+$//;
      $alias =~ s/\..*$// if $strip_domain;
      $vhosts{$alias} = $vhost;
      next;
    }
    if (/^CustomLog\s+(\S+)/) {
      $log = noquot($1);
      $log = "$root/$log" if $log !~ /^\//;
      push @logs, $log;
      next;
    }
    if (/^Include\s+(\S+)/) {
      gather_defs($1,$root);
      next;
    }
  }
  close CONF;
}

gather_defs($httpd_conf, $httpd_root, "root");
my %tmp;
@tmp{values %vhosts} = ();
@vhosts = sort keys %tmp;
%tmp = ();
@tmp{@logs} = ();
@logs = sort keys %tmp;

if ($debug) {
  print "vhosts: ".join(',',@vhosts)."\n";
  print "logs: ".join(',',@logs)."\n";
  for (sort keys %vhosts) { print "$_ -> $vhosts{$_}\n" }
}

mkdir $usage_root;
system "rm -rf $usage_root/*";

open(INDEX, ">", "$usage_root/index.html");
print INDEX <<EOF;
<html>
  <head>
    <title>Web site usage statistics by subsite</title>
  </head>
<body>
  <h2>Web site usage statistics by subsite</h2>
  <table width="100%" border="0"><tr>
    <td width="100"></td>
    <td>
      <table style="border: thin dotted #8080cc; background: #faffff"
             border="0" cellspacing="4" cellpadding="4">
EOF
for $vhost (@vhosts) {
  print INDEX <<EOF;
        <tr><td>
          <a href="$vhost/index.html">$vhost</a>
        </td></tr>
EOF
}
print INDEX <<EOF;
      </table>
    </td>
  </tr></table>
</body>
</html>
EOF
close(INDEX);

for $vhost (@vhosts) {
  my $vhost_dir = "$usage_root/$vhost";
  my $stage_dir = "$vhost_dir/stage";
  mkdir $vhost_dir;
  mkdir $stage_dir;
  open(HTACCESS, ">", "$stage_dir/.htaccess");
  print HTACCESS "Order Allow,Deny\nDeny from All\n";
  close HTACCESS;
  open(GLOBAL, "<", $global_cfg);
  open(LOCAL, ">", "$stage_dir/webalizer.conf");
  while(<GLOBAL>) {
    if (/^(LogFile)\s/) {
      $_ = "#$_$1\t$stage_dir/access_log\n";
    } elsif (/^(OutputDir)\s/) {
      $_ = "#$_$1\t$usage_root/$vhost\n";
    } elsif (/^(HistoryName|IncrementalName)\s+(\S+)/) {
      $_ = "#$_$1\t$2.$vhost\n";
    } elsif (/^(HostName)\s+(\S+)/) {
      $_ = "#$_$1\t$vhost\n";
    }
    print LOCAL;
  }
  close LOCAL;
  close GLOBAL;
}

for $log (@logs) {
  open(LOG, "<", $log) or next;
  while (<LOG>) {
    my @x = split;
    pop @x if $skip_port;
    $vhost = pop @x;
    unless (defined $vhosts{$vhost}) {
      print "$vhost: vhost not found\n"
        unless $warn_vhost{$vhost};
      $warn_vhost{$vhost} = 1;
      $vhost = $def_vhost;
    }
    $vhost = $vhosts{$vhost};
    $fd = $fds{$vhost};
    unless (defined $fd) {
      open($fd, ">>", "$usage_root/$vhost/stage/access_log") or next;
      $fds{$vhost} = $fd;
    }
    print $fd $_;
  }
  close LOG;
}

for $fd (values %fds) { close($fd) }

for $vhost (@vhosts) {
  my $cmd = "$webal_bin $webal_opts -c $usage_root/$vhost/stage/webalizer.conf";
  print "run: $cmd\n" if $debug;
  system $cmd;
  my $index_path = "$usage_root/$vhost/index.html";
  next if -e $index_path;
  next unless $make_stubs;
  open(STUBINDEX, ">", $index_path);
  print STUBINDEX "No data\n";
  close STUBINDEX;
}

