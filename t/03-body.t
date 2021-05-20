use strict;
use warnings;

use Test::More tests => 6;
BEGIN { use_ok('KSP') };

#########################

my $system = KSP::SolarSystem->new("SolarSystemDump");

is($system->root()->name(), "Sun");
is($system->body("Kerbin")->name(), "Kerbin");
# is(KSP::Body->G(), 6.67408e-11);

is($system->body("Kerbin")->commonAncestor($system->body("Duna"))->name(), "Sun");
is($system->body("Mun")->commonAncestor($system->body("Minmus"))->name(), "Kerbin");
is($system->body("Laythe")->commonAncestor($system->body("Gilly"))->name(), "Sun");

