#!/usr/bin/perl

use utf8;
binmode \*STDOUT, ":utf8";

use strict;
use warnings;

use Math::Trig;
use KSP qw(:all);

@ARGV == 1 or die "usage: $0 <body>\n";

my $body = Kerbin->system->body($ARGV[0]);

my $N = 3;
print "N = $N\n";

my $r = $body->radius;
print "r = ", U($r), "m\n";

my $hmin = 1 / cos(pi / $N) * ($body->lowHeight + $r) - $r;
print "hmin = ", U($hmin), "m\n";

my $omin = $body->orbit($hmin);
print "omin: $omin\n";

my $M = 30 * 60;
print "module: ", $body->system->pretty_interval($M), "\n";

my $T = $M * (int($omin->T / $M) + 1);

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

