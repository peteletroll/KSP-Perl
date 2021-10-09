use strict;
use warnings;

use utf8;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

use KSP::Util qw(U);

use Math::Trig;

binmode $_, ":utf8" foreach (\*STDOUT, \*STDERR);

my $system = KSP::SolarSystem->new();

my @b = qw(Mun Minmus);

my $b1 = $system->body($b[0]);
my $b2 = $system->body($b[1]);

print "B1\t", $b1->name(), "\t", $b1->orbit->desc(), "\n";
print "B2\t", $b2->name(), "\t", $b2->orbit->desc(), "\n";
print "B1N\t", $b1->name(), "\t", $b1->orbitNormal(), "\n";
print "B2N\t", $b2->name(), "\t", $b2->orbitNormal(), "\n";

my $incl = atan2($b1->orbitNormal(), $b2->orbitNormal());
print "INCL\t", U(180 / pi * $incl), "°\n";

my $l1 = $b1->lowOrbit();
my $l2 = $b2->lowOrbit();

my ($tr, $htr1, $htr2) = $b1->orbit->hohmannTo($b2->orbit);

my $e1 = KSP::Orbit2D->new($b1,
	pe => $b1->lowHeight(),
	v_soi => $tr->v($htr1) - $b1->orbit->vmax());

my $e2 = KSP::Orbit2D->new($b2,
	pe => $b2->lowHeight(),
	v_soi => $tr->v($htr2) - $b2->orbit->vmin());

my $delta_v = 0;
print "START\t", $l1->desc(), "\n";
my $dve1 = $e1->vmax() - $l1->vmax();
$delta_v += $dve1;
print "Δv esc\t", U($dve1), "m/s\n";
print "ESC1\t", $e1->desc(), "\n";
print "TRANS\t", $tr->desc(), "\n";
print "TRANS\t", U($htr1), "m -> ", U($htr2), "m\n";
my $vincl = $tr->vmax();
my $dvincl = 2 * sin($incl / 2) * $vincl;
$delta_v += $dvincl;
print "Δv incl\t", U($dvincl), "m/s @ ", U($vincl), "m/s\n";
print "ESC2\t", $e2->desc(), "\n";
my $dve2 = $e2->vmax() - $l2->vmax();
$delta_v += $dve2;
print "Δv capt\t", U($dve2), "m/s\n";
print "END\t", $l2->desc(), "\n";
print "Δv tot\t", U($delta_v), "m/s\n";

