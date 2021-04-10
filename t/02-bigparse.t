use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') };

#########################

my $file = "t/quicksave.sfs";
-f $file or exit 0;

exit 0;

my $n;
foreach (1..1) {
	warn "ITER $_\n";
	$n = KSP::ConfigNode->load($file);
}

use Data::Dump qw(dump);
# warn dump($n), "\n";
warn $n->asString();

