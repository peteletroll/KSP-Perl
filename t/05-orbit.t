use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

use Data::Dump qw(dump);

warn "\n";

KSP::Body->get("Z");

foreach my $b (KSP::Body->all()) {
	my $o = $b->lowOrbit();
	warn $o->desc(), "\n";
}

