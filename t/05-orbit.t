use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

use Data::Dump qw(dump);

warn "\n";

foreach my $b (sort { $a->name() cmp $b->name() } KSP::Body->all()) {
	warn $b->lowOrbit()->desc(), "\n";
	warn $b->highOrbit()->desc(), "\n";
}

