use strict;
use warnings;

use utf8;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

binmode $_, ":utf8" foreach (\*STDOUT, \*STDERR);

warn "\n";

my @b = qw(Mun Minmus);

my $b1 = KSP::Body->get($b[0]);
my $b2 = KSP::Body->get($b[1]);

warn "B1\t", $b1->name(), "\t", $b1->orbit->desc(), "\n";
warn "B2\t", $b2->name(), "\t", $b2->orbit->desc(), "\n";

my $l1 = $b1->lowOrbit();
my $l2 = $b2->lowOrbit();

my $tr = $b1->hohmannTo($b2);

my $e1 = KSP::Orbit2D->new($b1,
	pe => $b1->lowHeight(),
	r => $b1->SOI(),
	v => $tr->vmax() - $b1->orbit->vmax());

my $e2 = KSP::Orbit2D->new($b2,
        pe => $b2->lowHeight(),
        r => $b2->SOI(),
        v => $tr->vmin() - $b2->orbit->vmin());

warn "START\t", $l1->desc(), "\n";
warn "Δv\t", $e1->vmax() - $l1->vmax(), "\n";
warn "ESC1\t", $e1->desc(), "\n";
warn "TRANS\t", $tr->desc(), "\n";
warn "ESC2\t", $e2->desc(), "\n";
warn "Δv\t", $e2->vmax() - $l2->vmax(), "\n";
warn "END\t", $l1->desc(), "\n";

