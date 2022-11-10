#!/usr/bin/perl

use utf8;
binmode \*STDOUT, ":utf8";

use strict;
use warnings;

use POSIX qw(floor ceil);
use Math::Trig;
use KSP qw(:all);

@ARGV >= 1 && @ARGV <= 2 or die "usage: $0 <body> [ <time module> ]\n";

my $body = Kerbin->system->body($ARGV[0]);
my $system = $body->system;

my $N = 3;
print "N = $N\n";

my $r = $body->radius;
print "r = ", U($r), "m\n";

my $hmin = ($body->lowHeight + $r) / cos(pi / $N) - $r;
print "hmin = ", U($hmin), "m\n";

my $omin = $body->orbit($hmin);
print "omin: $omin\n";

my $M = $ARGV[1] || 30 * 60;
if ($M =~ /^(\d+)([smhdy])$/) {
	$M = $2 eq "s" ? $1 :
		$2 eq "m" ? 60 * $1 :
		$2 eq "h" ? 60 * 60 * $1 :
		$2 eq "d" ? $system->secs_per_day * $1 :
		$2 eq "y" ? $system->secs_per_year * $1 :
		$M;
}
print "module: ", $body->system->pretty_interval($M), "\n";

my $T = $M * ceil($omin->T / $M);

my ($of, $ot);
for (;; $T += $M) {
	$of = $body->orbit(e => 0, T => $T);
	print "trying of = $of\n";
	my $h = $of->pe;
	$h > $hmin or next;
	$ot = $body->orbit(ap => $h, T => (($N - 1) / $N) * $T);
	print "trying ot = $ot\n";
	$ot->pe >= $body->lowHeight or next;
	last;
}

print "\nflight plan:\n", $body->lowOrbit->burnTo($of->ap)->goAp->burnTo($ot->pe)->goAp->burnCirc;

print "\ndeorbit:\n", $of->burnTo(0), "\n";

