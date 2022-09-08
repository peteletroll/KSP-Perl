#!/usr/bin/perl

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

use Math::Trig;

use File::Find;

use JSON;

use lib "lib";
use KSP;
my $stockSystem = KSP::SolarSystem->new();

binmode \*STDOUT, ":utf8";

my %rename = ();
while (@ARGV > 1 && $ARGV[0] =~ /^(\w+)=(\w+)$/) {
	$rename{$1} = $2;
	shift;
}

@ARGV == 1 && -d $ARGV[0] or die "usage: $0 <directory>";
my $DIR = $ARGV[0];

my @bodies = ();
my %bodies = ();
my %delete = map { $_ => 1 } qw(
	ScaledVersion
	PQS
	Mods
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
			$_->parent or return;
			$_->parent->name =~ /kopernicus/i or return;
			my $name = $_->get("name") or return;
			push @bodies, $_;
			$bodies{$name} = $_;
			$_->visit(sub {
				my $n = $_->name or return;
				$delete{$n} || $n =~ /^temperature.*Curve$/
					and $_->delete;
			});
		});
	}
}, $DIR;

# print KSP::ConfigNode->new("bodies", @bodies)->asString, "\n";

my $rootBody = undef;
my %bodiesJson = ();
foreach my $b (@bodies) {
	my $name = $b->get("name") or die "NO NAME: ", $b->asString, "\n";
	$rename{$name} ||= $b->get("cbNameLater") || $name;
	my $j = { };

	my $tmpl = $b->find("Template");
	$tmpl &&= $tmpl->get("name");
	if ($tmpl) {
		my $tbody = $stockSystem->body($tmpl)
			or die "NO TEMPLATE: $tmpl\n";
		my $tjson = $tbody->json;
		# warn "TEMPLATE $name <- $tmpl\n";
		foreach my $i (sort keys %$tjson) {
			my $k = $tjson->{$i};
			ref $k eq "HASH" or next;
			# warn "\tI $i = $k\n";
			foreach my $n (sort keys %$k) {
				my $v = $k->{$n};
				if (JSON::is_bool($v)) {
					# nothing
				} elsif (ref $v) {
					next;
				} elsif (looks_like_number($v)) {
					$v = $v + 0;
				}
				# warn "\t\tN $n = ", to_json($v), "\n";
				$j->{$i}{$n} = $v;
			}
		}
	}

	$j->{info}{name} = $rename{$name};
	$j->{info}{index} = 0 + ($b->get("flightGlobalsIndex") || 0);
	$j->{info}{orbitingBodies} = [ ];
	$b->visit(sub {
		my $n = $_->name;
		my $p = $_->parent ? $_->parent->name : "";
		# warn "NODE $name $p $n\n";
		if ($p eq "Body" && $n eq "Orbit") {
			$j->{orbit}{referenceBody} = $_->get("referenceBody");
			$j->{orbit}{semiMajorAxis} = 0 + $_->get("semiMajorAxis");
			$j->{orbit}{eccentricity} = 0 + $_->get("eccentricity");
			$j->{orbit}{inclinationDeg} = 0 + $_->get("inclination");
			$j->{orbit}{longitudeOfAscendingNodeDeg} = 0 + $_->get("longitudeOfAscendingNode");
			$j->{orbit}{argumentOfPeriapsisDeg} = 0 + $_->get("argumentOfPeriapsis");
			$j->{orbit}{meanAnomalyAtEpochDeg} = 0 + ($_->get("meanAnomalyAtEpochD") || 0);
			foreach (keys %{$j->{orbit}}) {
				/^(.*)Deg$/ and $j->{orbit}{"${1}Rad"} = deg2rad $j->{orbit}{$_};
			}
		} elsif ($p eq "Body" && $n eq "Properties") {
			$_->get("radius") and $j->{size}{radius} = 0 + $_->get("radius");
			$_->get("mass") and $j->{size}{mass} = 0 + $_->get("mass");
			$_->get("gravParameter") and $j->{size}{mu} = 0 + $_->get("gravParameter");
			$_->get("geeASL") and $j->{size}{g0} = 9.81 * $_->get("geeASL");
			$_->get("timewarpAltitudeLimits") and $j->{info}{timeWarpAltitudeLimits} = [
				map { 0 + $_ }
				split(/\s+/, $_->get("timewarpAltitudeLimits"))
			];
			$_->get("rotationPeriod") and $j->{rotation}{rotationPeriod} = 0 + $_->get("rotationPeriod")
				or ($_->get("tidallyLocked") || "") =~ /true/i and $j->{rotation}{tidallyLocked} = JSON::true;
		} elsif ($p eq "Body" && $n eq "Atmosphere") {
			$j->{atmosphere}{atmosphereDepth} = 0 + ($_->get("maxAltitude") || $_->get("altitude") || 0);
			$j->{atmosphere}{atmosphereContainsOxygen} = ($_->get("oxygen") || "") =~ /true/i ?
				JSON::true : JSON::false;
		}
	});
	# warn "BODY ", to_json($j, { pretty => 1 }), "\n";
	$bodiesJson{$rename{$name}} = $j;
}

foreach my $j (values %bodiesJson) {
	if ($j->{orbit}) {
		$j->{orbit}{referenceBody} = $rename{$j->{orbit}{referenceBody}};
	} else {
		$rootBody = $j->{info}{name};
	}
}

foreach my $j (values %bodiesJson) {
	my $p = $j->{orbit}{referenceBody} or next;
	push @{$bodiesJson{$p}{info}{orbitingBodies}}, $j->{info}{name};
}

foreach my $j (values %bodiesJson) {
	my $c = $j->{info}{orbitingBodies};
	$c and @$c = sort @$c;
}

my $system = {
	timeUnits => {
		Year => 365.24219 * 24 * 3600,
		Day => 24 * 3600,
		Hour => 3600,
		Minute => 60
	},
	rootBody => $rootBody,
	bodies => \%bodiesJson
};

print to_json($system, { indent => 1, space_after => 1, canonical => 1 });

