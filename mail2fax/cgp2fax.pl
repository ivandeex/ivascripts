#!/usr/bin/perl
use strict;
use Getopt::Std;

my $group = "faxlords";
my $faxmailopts = "-n -N -T -s a4";
my $log = "/var/log/cgp2fax.log";
my $tmp = "/tmp/tmpfax-$$";
my $debug = 0;

my %faxhosts = (
  0 => 'fax.gclimate.com',
  1 => 'fax1.gclimate.com',
  2 => 'fax2.gclimate.com',
);

sub logdie {
  my $msg = join '', @_;
  print "$msg\n";
  die "$msg\n";
}

open(LOG, ">>", $log);
select LOG;

$_ = `date`; chop; print "=== $_ ===\n";
#print join(' ',@ARGV)."\n";

my %opt;
getopt("t:n:f:p:", \%opt);
my ($target, $num, $email, $from) = ($opt{t}, $opt{n}, $opt{f}, $opt{p});
my $faxhost = $faxhosts{$target};
print "target=$target num=$num from=$from email=$email prefix=$tmp.\n";
unless (defined($target) && $target ne '' && $num && $email && $from) {
  print "usage: send-fax -t target -n number -p from -f file\n" if $debug;
  logdie "usage syntax error";
}
unless ($faxhost) {
  print "available targets: 0 1 2\n" if $debug;
  logdie "incorrect target '$target'";
}

my $getent = `getent group $group 2>/dev/null`;
chop $getent;
my ($nil1, $nil2, $nil3, $members) = split /:/, $getent;
my %members;
for (split /,/, $members) { $members{$_} = 1; }

my $user = $from;
$user = $1 if $user =~ /<\s*(\S+)\s*>/;
$user = $1 if $user =~ /^(.*?)\@/;

unless ($members{$user}) {
  if ($debug) {
    print "group=$group\nmembers=".join(',',keys %members)."\n";
  }
  logdie "user '$user' is NOT authorized to send faxes";
}

`cp $email $tmp.in`;

# Remove PIPE headers
open(IN, "<", "$tmp.in");
open(OUT, ">", "$tmp.eml");
my $inhead = 1;
while(<IN>) {
  if ($inhead) {
    $inhead = 0 if /^\s*$/;
    next;
  }
  print OUT;
}
close IN;
close OUT;

`/usr/bin/faxmail $faxmailopts < $tmp.eml > $tmp.0ps 2> $tmp.err`;
`cat $tmp.err`;

# Remove first page (It contains mail headers etc)
open(IN, "<", "$tmp.0ps");
open(OUT, ">", "$tmp.ps");
my $firstpage = 1;
while(<IN>) {
  if ($firstpage && /^showpage$/) {
    print OUT "%".$_;
    $firstpage = 0;
    next;
  }
  print OUT;
}
close IN;
close OUT;

# Convert to PDF
`/usr/bin/ps2pdfwr $tmp.ps $tmp.pdf 2>&1` if $debug;

`/usr/bin/sendfax -h $faxhost -n -R -f "$from" -d $num $tmp.ps 2>&1`;

`/bin/rm -f $tmp.in $tmp.eml $tmp.0ps $tmp.err $tmp.ps $tmp.pdf 2>/dev/null`
  if !$debug;

print "==== done ====\n";
exit 0;

