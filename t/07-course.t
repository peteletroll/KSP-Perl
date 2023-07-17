use strict;
use warnings;

use utf8;

use Test::More tests => 273;
BEGIN { use_ok('KSP') };

#########################

use KSP qw(:all);

use Data::Dump qw(dump);

binmode $_, ":utf8" foreach (\*STDOUT, \*STDERR);

my $system = KSP::SolarSystem->new();

my @b = $system->bodies();
foreach my $b1 (@b) {
	foreach my $b2 (@b) {
		$b1 == $b2 and next;
		print $b1->name, " -> ", $b2->name, "\n";
		my $course = $b1->goTo($b2);
		print $course, "\n\n";
		ok($course);
	}
}

