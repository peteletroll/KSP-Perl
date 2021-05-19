#!/usr/bin/perl

use strict;
use warnings;

use File::Find;

use lib "lib";
use KSP;

my @bodies = ();
my %delete = map { $_ => 1 } qw(
	ScaledVersion
	PQS
	Mods
	Template
	pressureCurve
	AtmosphereFromGround
	Biomes
	ScienceValues
);
find {
	no_chdir => 1,
	wanted => sub {
		/\.cfg$/i && -f $_ or return;
		my $node = KSP::ConfigNode->load($_) or return;
		$node->visit(sub {
			my $n = $_->name or return;
			$n eq "Body" or return;
			push @bodies, $_;
			$_->visit(sub {
				my $n = $_->name or return;
				$delete{$n} || $n =~ /^temperature.*Curve$/
					and $_->delete;
			});
		});
	}
}, "RSSKopernicus";

print KSP::ConfigNode->new("bodies", @bodies)->asString, "\n";

