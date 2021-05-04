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
warn "$_\t", U($l{$_}), "m/s\t$l{$_}m/s\n" foreach sort { $l{$a} <=> $l{$b} } keys %l;

warn Kerbin->lowOrbit->goTo(Mun), "\n";

warn Mun->lowOrbit->goTo(Kerbin), "\n";

warn Mun->lowOrbit->goTo(Minmus), "\n";

warn Minmus->lowOrbit->goTo(Mun), "\n";

warn "\n";
warn "MOHO ", Moho->orbit, "\n";
warn "JOOL ", Moho->orbit, "\n";
warn "\n";

warn "MOHO/PE TO JOOL/PE\n";
warn Moho->orbit->goTo(Jool), "\n";

warn "MOHO/AP TO JOOL/PE\n";
warn Moho->orbit->goAp->goTo(Jool), "\n";

warn "MOHO/PE TO JOOL/AP\n";
warn Moho->orbit->goTo(Jool), "\n";

warn "MOHO/AP TO JOOL/AP\n";
warn Moho->orbit->goAp->goTo(Jool), "\n";

