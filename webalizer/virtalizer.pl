#!/usr/bin/perl
use strict;

# gather virtual host definitions
my $httpd_root = "/etc/httpd";
my $httpd_conf = "$httpd_root/conf/httpd.conf";
my $usage_root = "/var/www/usage";
my $global_cfg = "/etc/webalizer.conf";
my $def_vhost = "";
my $webal_bin = "/usr/bin/webalizer";
my $webal_opts = "";
my $expire_min = "60";
my $debug = 0;
my $quiet = 1;
my $strip_domain = 0;
my $skip_port = 1;
my $make_stubs = 1;
my $use_history = 1;
my $cleanup = 1;

my (%vhosts, @vhosts, @logs, @suffixes, %fds, %warn_vhost);
my ($vhost, $alias, $log, $log0, $fd, $suffix, $outlog);

$webal_opts .= " -d" if $debug;
$webal_opts .= " -Q" if $quiet;

@suffixes = ( "" );
if ($use_history) {
  @suffixes = qw(.9 .8 .7 .6 .5 .4 .3 .2 .1),"";
}

sub noquot ($) {
  $_ = $_[0];
  s/^\s*\"?\s*//;
  s/\s*\"?\s*$//;
  $_;
}

sub gethost ($) {
  $_ = noquot($_[0]);
  s/\:\d+$//;
  s/\..*$// if $strip_domain;
  if (!$def_vhost && /\.((?:[^\.]+\.)+[^\.]+)$/) {
    $def_vhost = $1;
    print "def_vhost: $def_vhost\n" if $debug;
  }
  $_;
}

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
  my $ignore = 0;
  while (<CONF>) {
    next if /^\s*\#/;
    if (/^<IfModule\s+DISABLE/) {
      $ignore++;
      next;
    }
    if (/^<IfModule\s/ && $ignore) {
      $ignore++;
      next;
    }
    if (/^<\/IfModule>/ && $ignore) {
      $ignore--;
      next;
    }
    next if $ignore;
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
      $vhost = gethost($1);
      $vhosts{$vhost} = $vhost;
      next;
    }
    if (/^ServerAlias\s+(\S+)/) {
      $alias = gethost($1);
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
system "rm -rf $usage_root/*" if $cleanup;

open(INDEX, ">", "$usage_root/index.html");
print INDEX <<EOF;
<html>
  <head>
    <title>Web site usage statistics by subsite</title>
    <style type="text/css" media="screen">
/*<![CDATA[*/
a {
  color: #2050a0;
  text-decoration: none;
  background: transparent;
  display: block;
  width: 100%;
  padding: 5px;
}
a:hover {
  color: #173878;
  text-decoration: underline;
  background: #ffffd0;
  display: block;
  width: 100%;
  padding: 5px;
}
a:visited {
  color: #2050b0;
}
/*]]>*/
    </style>
  </head>
<body>
  <h2>Web site usage statistics by subsite</h2>
  <table width="100%" border="0"><tr>
    <td width="100"></td>
    <td>
      <table style="border: thin dotted #8080cc; background: #faffff"
             border="0" cellspacing="3" cellpadding="6">
EOF
for $vhost (@vhosts) {
  print INDEX <<EOF;
        <tr>
          <td><a href="$vhost/index.html">$vhost</a></td>
          <td><a href="$vhost/index.html">statistics</a></td>
          <td><a href="http://$vhost">site</a></td>
        </tr>
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

open(HTACCESS,">",  "$usage_root/.htaccess");
print HTACCESS <<EOF;
ExpiresActive On
ExpiresDefault "access $expire_min minutes"
EOF
close HTACCESS;

for $vhost (@vhosts) {
  my $vhost_dir = "$usage_root/$vhost";
  my $stage_dir = "$vhost_dir/stage";
  mkdir $vhost_dir;
  mkdir $stage_dir;
  open(HTACCESS, ">",  "$vhost_dir/.htaccess");
  print HTACCESS <<EOF;
ExpiresActive On
ExpiresDefault "access $expire_min minutes"
EOF
  close HTACCESS;
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
    } elsif (/^(HistoryName)\s+(\S+)/) {
      $_ = "#$_$1\t$stage_dir/history\n";
    } elsif (/^(IncrementalName)\s+(\S+)/) {
      $_ = "#$_$1\t$stage_dir/incremental\n";
    } elsif (/^(HostName)\s+(\S+)/) {
      $_ = "#$_$1\t$vhost\n";
    }
    print LOCAL;
  }
  close LOCAL;
  close GLOBAL;
}


for $vhost (@vhosts) {
  $outlog = "$usage_root/$vhost/stage/access_log";
  truncate $outlog, 0;
}

for $log0 (@logs) {
  for $suffix (@suffixes) {
    $log = "$log0$suffix";
    open(LOG, "<", $log) or next;
    print "READ $log\n" if $debug;
    while (<LOG>) {
      my @x = split;
      pop @x if $skip_port;
      $vhost = pop @x;
      unless (defined $vhosts{$vhost}) {
        print "$vhost: vhost not found\n"
          if !$warn_vhost{$vhost} && !$quiet;
        $warn_vhost{$vhost} = 1;
        $vhost = $def_vhost;
      }
      $vhost = $vhosts{$vhost};
      $fd = $fds{$vhost};
      unless (defined $fd) {
        $outlog = "$usage_root/$vhost/stage/access_log";
        open($fd, ">>", $outlog) or next;
        $fds{$vhost} = $fd;
        print "WRITE: $outlog\n" if $debug;
      }
      print $fd $_ if $fd ne "-";
    }
    close LOG;
  }
  for $fd (values %fds) { close($fd) if $fd ne "-" }
}

for $vhost (@vhosts) {
  my $vhost_dir = "$usage_root/$vhost";
  my $vhost_log = "$vhost_dir/stage/access_log";
  my $cmd = "$webal_bin $webal_opts -c $vhost_dir/stage/webalizer.conf";
  $cmd .= " >/dev/null 2>&1" if $quiet;
  print "run: $cmd\n" if $debug;
  system $cmd;
  my $index_path = "$usage_root/$vhost/index.html";
  next if (-e $index_path);
  next unless $make_stubs;
  print (-e $index_path).": will remake $index_path\n"
    if $debug;
  open(STUBINDEX, ">", $index_path);
  print STUBINDEX <<EOF;
<html>
  <head><title>$vhost: no data</title><head>
  <body>$vhost: no data</body>
</html>
EOF
  close STUBINDEX;
}

