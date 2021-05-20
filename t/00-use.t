# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl KSP.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('KSP') or BAIL_OUT("can't load") };

#########################

use KSP qw(:all);

print "1\n";
Kerbin;
print "2\n";
Kerbin->lowOrbit()->desc();
print "3\n";

