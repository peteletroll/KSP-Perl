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
foreach my $b1 (@b) {
	foreach my $b2 (@b) {
		$b1 == $b2 and next;
		warn $b1->goTo($b2), "\n\n";
	}
}

@b = sort { $a->orbit->a <=> $b->orbit->a } Jool->children;
my %l = ();
foreach my $b1 (@b) {
	foreach my $b2 (@b) {
		$b1 == $b2 and next;
		$l{$b1->name . "\t" . $b2->name} = $b1->goTo($b2)->dv;
	}
}
warn "$_\t", U($l{$_}), "m/s\n" foreach sort { $l{$a} <=> $l{$b} } keys %l;

warn Kerbin->lowOrbit->goTo(Mun), "\n";

warn Mun->lowOrbit->goTo(Kerbin), "\n";

warn Mun->lowOrbit->goTo(Minmus), "\n";

warn Minmus->lowOrbit->goTo(Mun), "\n";

warn "MUN TO MINMUS\n";
warn Mun->goTo(Minmus->orbit), "\n";

warn "MINMUS TO MUN\n";
warn Mun->goTo(Minmus->orbit), "\n";

warn "ANCESTOR TEST\n";
warn Mun->goTo(Duna->orbit), "\n";

