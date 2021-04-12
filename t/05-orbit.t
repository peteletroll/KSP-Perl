use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

use Data::Dump qw(dump);

warn "\n";

my $k = KSP::Body->get("Kerbin");
warn KSP::Orbit2D->new($k, -$k->radius() * 10, 1.1)->desc(), "\n";

warn "\n";

foreach my $b (sort { $a->name() cmp $b->name() } KSP::Body->all()) {
	my $n = $b->name();
	my $o = $b->orbit();
	my $l = $b->lowOrbit();
	my $h = $b->highOrbit();
	warn "O($n):", ($o ? $o->desc() : "undef"), "\n";
	warn "L($n):", $l->desc(), "\n";
	warn "H($n):", $h->desc(), "\n";
	warn "D($n):", $h->vmax() - $l->vmin(), "\n";
}

