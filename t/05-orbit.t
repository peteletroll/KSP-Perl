use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

use Data::Dump qw(dump);

my $k = KSP::Body->get("Kerbin");
print KSP::Orbit2D->new($k, a => -$k->radius() * 10, e => 1.1)->desc(), "\n";
print KSP::Orbit2D->new("Kerbin", T => 21549.425183089825, e => 0)->desc(), "\n";

foreach my $b (sort { $a->name() cmp $b->name() } KSP::Body->all()) {
	my $n = $b->name();
	my $o = $b->orbit();
	my $l = $b->lowOrbit();
	my $h = $b->highOrbit();
	print "O($n):", ($o ? $o->desc() : "undef"), "\n";
	print "L($n):", $l->desc(), "\n";
	print "H($n):", $h->desc(), "\n";
	print "D($n):", $h->vmax() - $l->vmin(), "\n";
}

local $KSP::Orbit2D::TRACE = 0;

warn "\n";
my $l = $k->lowOrbit();
warn $l->desc(), "\n";

my $n1 = KSP::Orbit2D->new($l->body(), pe => $l->pe(), T => $l->T(), trace => 1);
warn $n1->desc(), "\n";

my $n2 = KSP::Orbit2D->new($l->body(), ap => $l->ap(), T => $l->T(), trace => 1);
warn $n2->desc(), "\n";

my $n3 = KSP::Orbit2D->new($l->body(), e => 0, v => $l->vmax(), r => $l->rpe(), trace => 1);
warn $n3->desc(), "\n";

