#!/usr/bin/perl

use utf8;
binmode \*STDOUT, ":utf8";

use strict;
use warnings;

use Math::Trig;
use KSP qw(:all);

use Math::Vector::Real;

my $incl = atan2(Kerbin->orbitNormal, Moho->orbitNormal);
printf "inclination = %3.2f°\n", rad2deg $incl;

my $trans = Sun->orbit(ap => Kerbin->ap, pe => Moho->pe);
print "transfer = $trans\n";

my $vKerbin = V(Kerbin->vmax, 0);
print "vKerbin = $vKerbin\n";

my $vminTrans = V($trans->vmin * cos($incl), $trans->vmin * sin($incl));
print "vminTrans = $vminTrans\n";

my $vOut = $vminTrans - $vKerbin;
print "vOut = $vOut\n";
print "|vOut| = ", U(abs($vOut)), "m/s\n";

my $ej = Kerbin->goTo(Kerbin->orbit(pe => Kerbin->lowHeight, v_soi => abs($vOut)));
print "eject:\n", $ej, "\n";

my $en = $trans->enterTo(Moho)->burnCirc;
print "enter:\n", $en, "\n";

print "total ", U($ej->dv + $en->dv), "m/s\n\n";

