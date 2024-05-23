use strict;
use warnings;

use Test::More tests => 2;
BEGIN { use_ok('KSP') };

#########################

my $n = KSP::ConfigNode->parse_string(q{
	// comment
	a {
		name = a // comment
		b = c
		d { // comment
			name = d
			e = f
			http://something = url test
		}
	}
});
ok($n);

# use Data::Dump qw(dump);
# print dump($n), "\n";
print $n->asString();

