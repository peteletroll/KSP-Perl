use strict;
use warnings;

use utf8;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

use KSP qw(:all);

use Data::Dump qw(dump);

binmode $_, ":utf8" foreach (\*STDOUT, \*STDERR);

warn "\n";

my @b = sort { $a->orbit->a <=> $b->orbit->a } Sun->children;
warn scalar @b, "\n";
foreach my $b1 (@b) {
	foreach my $b2 (@b) {
		$b1 == $b2 and next;
		warn $b1->orbit->goTo($b2->orbit), "\n";
	}
}

warn Kerbin->lowOrbit->goTo(Mun), "\n";

warn Mun->lowOrbit->goTo(Kerbin), "\n";

warn Mun->lowOrbit->goTo(Minmus), "\n";

warn Minmus->lowOrbit->goTo(Mun), "\n";

