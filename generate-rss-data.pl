#!/usr/bin/perl

use strict;
use warnings;

use Math::Trig;

use File::Find;

use JSON;

use lib "lib";
use KSP;

binmode \*STDOUT, ":utf8";

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
			$_->name eq "Body" or return;
			$_->get("name") or return;
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

my @bodiesJson = ();
foreach my $b (@bodies) {
	my $name = $b->get("name") or die "NO NAME: ", $b->asString, "\n";
	my $j = { };
	$j->{info}{name} = $name;
	$b->visit(sub {
		my $n = $_->name;
		if ($n eq "Orbit") {
			$j->{orbit}{referenceBody} = $_->get("referenceBody");
			$j->{orbit}{semiMajorAxis} = 0 + $_->get("semiMajorAxis");
			$j->{orbit}{eccentricity} = 0 + $_->get("eccentricity");
			$j->{orbit}{inclinationDeg} = 0 + $_->get("inclination");
			$j->{orbit}{longitudeOfAscendingNodeDeg} = 0 + $_->get("longitudeOfAscendingNode");
			$j->{orbit}{argumentOfPeriapsisDeg} = 0 + $_->get("argumentOfPeriapsis");
			$j->{orbit}{meanAnomalyAtEpochDeg} = 0 + $_->get("meanAnomalyAtEpochD");
			foreach (keys %{$j->{orbit}}) {
				/^(.*)Deg$/ and $j->{orbit}{"${1}Rad"} = deg2rad $j->{orbit}{$_};
			}
		} elsif ($n eq "Properties") {
		}
	});
	warn "BODY ", to_json($j, { pretty => 1 }), "\n";
	push @bodiesJson, $j;
}

my $system = {
	timeUnits => {
		Year => 365.24219 * 24 * 3600,
		Day => 24 * 3600,
		Hour => 3600,
		Minute => 60
	},
	bodies => \@bodiesJson
};

print to_json($system, { indent => 1, space_after => 1, canonical => 1 });

