use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

binmode $_, ":utf8" foreach (\*STDOUT, \*STDERR);

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

my $l = $k->lowOrbit();
print $l->desc(), "\n";

my $n1 = KSP::Orbit2D->new($l->body(), pe => $l->pe(), T => $l->T(), trace => 0);
print $n1->desc(), "\n";

my $n2 = KSP::Orbit2D->new($l->body(), ap => $l->ap(), T => $l->T(), trace => 0);
print $n2->desc(), "\n";

my $n3 = KSP::Orbit2D->new($l->body(), e => 0, v => $l->vmax(), h => $l->pe(), e => 0, trace => 0);
print $n3->desc(), "\n";

my $n4 = KSP::Orbit2D->new($l->body(), v => sqrt(2) * $l->vmax(), h => $l->pe(), pe => $l->pe(), trace => 0);
print $n4->desc(), "\n";

my $n5 = KSP::Orbit2D->new($l->body(), v => 1.00001 * sqrt(2) * $l->vmax(), h => $l->pe(), pe => $l->pe(), trace => 0);
print $n5->desc(), "\n";

