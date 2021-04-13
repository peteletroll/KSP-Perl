use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

binmode $_, ":utf8" foreach (\*STDOUT, \*STDERR);

my $k = KSP::Body->get("Kerbin");
my $d = KSP::Body->get("Duna");

my $h = $k->hohmannTo($d);

warn "\n";

warn "FROM\t", $k->orbit->desc(), "\n",
	"\t", $k->lowOrbit()->desc(), "\n";
warn "TO\t", $d->orbit->desc(), "\n",
	"\t", $d->lowOrbit()->desc(), "\n";
warn "ESC\t", KSP::Orbit2D->new($k,
	pe => $k->lowHeight(),
	r => $k->SOI(),
	v => $h->vmax() - $k->orbit->vmax(),
	trace => 0)->desc(), "\n";
warn "TRANS\t", $h->desc(), "\n";
warn "CAPT\t", KSP::Orbit2D->new($d,
	pe => $d->lowHeight(),
	r => $d->SOI(),
	v => $h->vmin() - $d->orbit->vmin(),
	trace => 0)->desc(), "\n";

