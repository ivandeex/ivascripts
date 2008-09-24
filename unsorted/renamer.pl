#!/usr/bin/perl
use strict;

my $REAL = 1;

workdir(".");

sub workdir
{
  my $dir = shift;
  return if $dir eq ".svn";
  my @files = sort glob "$dir/*";
  for (@files) { workdir($_) if -d $_; }
  for (@files) { workfile($_) if $_ =~ /\.(t|pm|xs|c|h|cpp)$/ && -r $_; }
  #for (@files) { workfile($_) if $_ =~ /\.(oxf)$/ && -r $_; }
}

sub workfile
{
  my $s = shift;
  my $d = "$s.__";
  print "$s ... \n";
  open(S, "< $s") || die "cannot read $s\n";
  open(D, "> $d") || die "cannot write $d\n";
  while(<S>) {
    substall();
    print D $_;
  }
  close S;
  close D;
  if ($REAL) {
    unlink($s);
    rename($d, $s);
  }
  unlink $d;
}

sub substall
{
  #s/\bFormLink\b/Link/g;
}

