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
	warn "L:", $b->lowOrbit()->desc(), "\n";
	warn "H:", $b->highOrbit()->desc(), "\n";
}

