use strict;
use warnings;

use Test::More tests => 7;
BEGIN { use_ok('KSP') };

#########################

is(KSP::Body->root()->name(), "Sun");
is(KSP::Body->get("Kerbin")->name(), "Kerbin");
is(KSP::Body->G(), 6.67408e-11);

is(KSP::Body->get("Kerbin")->common_ancestor(KSP::Body->get("Duna"))->name(), "Sun");
is(KSP::Body->get("Mun")->common_ancestor(KSP::Body->get("Minmus"))->name(), "Kerbin");
is(KSP::Body->get("Laythe")->common_ancestor(KSP::Body->get("Gilly"))->name(), "Sun");

