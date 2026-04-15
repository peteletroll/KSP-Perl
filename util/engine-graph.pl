#!/usr/bin/perl

use strict;
use warnings;

use KSP;
use KSP::Util qw(Resource);

use Data::Dump qw(dump);

sub escgp($) {
	local ($_) = @_;
	utf8::is_utf8($_) and utf8::decode($_);
	s{([^\w-])}{ sprintf("\\%03o", ord($1)) }ge;
	"\"$_\""

}

my @engines = grep { $_->engine } Resource(qr/oxi/i)->consumers;
print "\$graph << END\n";
foreach my $e (@engines) {
	my $lbl = $e->nickname || $e->name;
	my $isp = 0 + $e->engine->maxIsp;
	my $thr = 0 + $e->engine->maxThrust;
	print "$thr $isp ", escgp($lbl), "\n";
}
print "END\n";

print <<'END';
set logscale x
set grid
plot $graph with labels, $graph with points
END

