use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

use Data::Dump qw(dump);

my $o = KSP::Orbit2D->new(KSP::Body->get("Kerbin"), 700e3, 0);

# warn dump($o), "\n";
warn "\n", $o->desc();

