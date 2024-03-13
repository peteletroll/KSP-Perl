use strict;
use warnings;

use Test::More tests => 6;
BEGIN { use_ok('KSP') };

#########################

my $system = KSP::SolarSystem->load();

is($system->secs_per_day(), 6 * 60 * 60);
is($system->secs_per_year(), 426 * $system->secs_per_day());
is($system->pretty_date(0), "Year 1, Day 1, 0:00:00.000");
is($system->pretty_date(1), "Year 1, Day 1, 0:00:01.000");
is($system->pretty_date(-1), "Year -1, Day 426, 5:59:59.000");

