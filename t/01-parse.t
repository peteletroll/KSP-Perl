use strict;
use warnings;

use Test::More tests => 2;
BEGIN { use_ok('KSP') };

#########################

my $n = KSP::ConfigNode->parse_string(q{
	a {
		name = a
		b = c
		d {
			name = d
			e = f
		}
	}
});
ok($n);

exit 0;

use Data::Dump qw(dump);
warn dump($n), "\n";
warn $n->asString();

