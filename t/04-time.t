use strict;
use warnings;

use Test::More tests => 6;
BEGIN { use_ok('KSP') };

#########################

is(KSP::Time->secs_per_day(), 6 * 60 * 60);
is(KSP::Time->secs_per_year(), 426 * KSP::Time->secs_per_day());
is(KSP::Time->new(0)->pretty_date(), "Year 1, Day 1, 0:00:00.000");
is(KSP::Time->new(1)->pretty_date(), "Year 1, Day 1, 0:00:01.000");
is(KSP::Time->new(-1)->pretty_date(), "Year -1, Day 426, 5:59:59.000");

