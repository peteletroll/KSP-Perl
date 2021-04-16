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

my $c = KSP::Course->new(Kerbin);
warn "AT ", $c->_cur->{then}, "\n";

