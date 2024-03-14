package KSP::Body;

use utf8;
use strict;
use warnings;

use Carp;

use Math::Vector::Real;

use Math::Trig;

use KSP::Cache;
use KSP::SolarSystem;
use KSP::Orbit2D;
use KSP::Surface;
use KSP::Course;
use KSP::Anomaly;

use KSP::Util qw(U isnumber proxy);
proxy("KSP::Orbit2D" => sub { $_->orbit }, qw(pe ap e a b vmin vmax));
proxy("KSP::Course" => sub { KSP::Course->new($_->lowOrbit) });

use KSP::TinyStruct qw(json system +KSP::Cache);

use overload
	'""' => sub { $_[0]->desc };

sub BUILD {
	my ($self, $json, $system) = @_;
	ref $json eq "HASH" or croak "hash needed here";
	ref $system eq "KSP::SolarSystem" or croak "KSP::SolarSystem needed here";
	$self->set_json($json);
	$self->set_system($system);
	my $roc = $json->{roc};
	if (UNIVERSAL::isa($roc, "HASH")) {
		foreach my $biome (keys %$roc) {
			my $l = $roc->{$biome};
			UNIVERSAL::isa($l, "ARRAY") and $roc->{$biome} = [ sort { $a cmp $b } @$l ];
		}
	}
	$self
}

sub name {
	$_[0]->json->{info}{name}
}

sub isStar {
	!! $_[0]->json->{info}{isStar}
}

sub isHomeWorld {
	!! $_[0]->json->{info}{isHomeWorld}
}

sub hasSurface {
	!! $_[0]->json->{surface}{hasSolidSurface}
}

sub radius {
	U($_[0]->json->{size}{radius}, "m")
}

sub SOI {
	my ($self) = @_;
	scalar $self->cache("SOI", sub {
		my $soi = $self->json->{size}{sphereOfInfluence};
		defined $soi and return U($soi, "m");
		my $parent = $self->parent;
		$parent ? U($self->orbit->a * ($self->mass / $parent->mass) ** (2 / 5), "m") : undef
	})
}

sub mass {
	my ($self) = @_;
	scalar $self->cache("mass", sub {
		my $mass = $self->json->{size}{mass};
		defined $mass and return $mass;
		$self->mu / $self->system->G
	})
}

sub mu {
	my ($self) = @_;
	scalar $self->cache("mu", sub {
		my $g0 = $self->json->{size}{g0};
		my $radius = $self->json->{size}{radius};
		$g0 && $radius and return $g0 * $radius * $radius;

		my $mu = $self->json->{size}{mu};
		defined $mu and return $mu;

		my $mass = $self->json->{size}{mass};
		defined $mass and return $mass * $self->system->G;

		confess "can't compute ", $self->name, " mu";
	})
}

sub parent {
	my ($self) = @_;
	my $o = $self->json->{orbit} or return undef;
	my $p = $o->{referenceBody} or return undef;
	$self->system->body($p)
}

sub children {
	my ($self) = @_;
	my $c = $self->json->{info}{orbitingBodies}
		or return wantarray ? () : 0;
	wantarray ? _sort(map { $self->system->body($_) } @$c) : scalar @$c
}

sub commonAncestor {
	my ($b1, $b2) = @_;
	my %b1anc = ();
	while ($b1) {
		$b1anc{$b1->name} = 1;
		$b1 = $b1->parent;
	}
	while ($b2) {
		$b1anc{$b2->name} and last;
		$b2 = $b2->parent;
	}
	$b2
}

sub pathToRoot {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::pathToRoot() wants list context";
	my @ret = ();
	while ($self) {
		push @ret, $self;
		$self = $self->parent;
	}
	@ret
}

sub hasAncestor {
	my ($self, $other) = @_;
	my $i = $self->parent;
	while ($i) {
		$i == $other and return 1;
		$i = $i->parent;
	}
	0
}

sub nextTo {
	my ($self, $other) = @_;
	$self->hasAncestor($other) and return $self->parent;
	$other->hasAncestor($self)
		or return;
	while ($other) {
		$other->parent == $self and last;
		$other = $other->parent;
	}
	$other
}

sub hohmannTo {
	my ($self, $other, @rest) = @_;
	$self->orbit->hohmannTo($other, @rest)
}

sub hasDescendant {
	my ($self, $other) = @_;
	$other->hasAncestor($self)
}

sub orbitX {
	my ($self) = @_;
	scalar $self->cache("orbitX", sub {
		my $o = $self->json->{orbit} or return;
		# https://en.wikipedia.org/wiki/Orbital_elements#Euler_angle_transformations
		my $i = $o->{inclinationRad};
		my $OMEGA = $o->{longitudeOfAscendingNodeRad};
		my $omega = $o->{argumentOfPeriapsisRad};
		V(
			cos($OMEGA) * cos($omega) - sin($OMEGA) * cos($i) * sin($omega),
			sin($OMEGA) * cos($omega) + cos($OMEGA) * cos($i) * sin($omega),
			sin($i) * sin($omega)
		)
	})
}

sub orbitY {
	my ($self) = @_;
	scalar $self->cache("orbitY", sub {
		my $o = $self->json->{orbit} or return;
		# https://en.wikipedia.org/wiki/Orbital_elements#Euler_angle_transformations
		my $i = $o->{inclinationRad};
		my $OMEGA = $o->{longitudeOfAscendingNodeRad};
		my $omega = $o->{argumentOfPeriapsisRad};
		V(
			-cos($OMEGA) * sin($omega) - sin($OMEGA) * cos($i) * cos($omega),
			-sin($OMEGA) * sin($omega) + cos($OMEGA) * cos($i) * cos($omega),
			sin($i) * cos($omega)
		)
	})
}

sub orbitZ {
	my ($self) = @_;
	scalar $self->cache("orbitZ", sub {
		my $o = $self->json->{orbit} or return;
		# https://en.wikipedia.org/wiki/Orbital_elements#Euler_angle_transformations
		my $i = $o->{inclinationRad};
		my $OMEGA = $o->{longitudeOfAscendingNodeRad};
		my $omega = $o->{argumentOfPeriapsisRad};
		V(
			sin($i) * sin($OMEGA),
			-sin($i) * cos($OMEGA),
			cos($i)
		)
	})
}

sub orbitNormal { goto &orbitZ }

sub volume {
	my ($self) = @_;
	4 / 3 * pi * $self->radius ** 3
}

sub density {
	my ($self) = @_;
	$self->mass / $self->volume
}

sub scienceValues {
	my ($self) = @_;
	scalar $self->cache("scienceValues", sub {
		my $s = $self->json->{science} || { };
		my $r = { };
		foreach my $k (keys %$s) {
			my $v = $s->{$k};
			ref $v and next;
			($self->atmosphereDepth <= 0 && $k =~ /^fly/i) and next;
			(!$self->hasOcean && $k =~ /^splash/i) and next;
			(!$self->hasSolidSurface && $k =~ /^land/i) and next;
			$k =~ s/(Data)?Value$// or next;
			$r->{$k} = $v;
		}
		$r
	})
}

sub spaceThreshold {
	my ($self) = @_;
	U($self->json->{science}{spaceAltitudeThreshold}, "m")
}

sub biomes {
	my ($self) = @_;
	my $b = $self->json->{science} && $self->json->{science}{biomes};
	ref $b eq "ARRAY" or return wantarray ? () : 0;
	wantarray ? sort @$b : scalar @$b
}

sub miniBiomes {
	my ($self) = @_;
	my $b = $self->json->{science} && $self->json->{science}{miniBiomes};
	ref $b eq "ARRAY" or return wantarray ? () : 0;
	wantarray ? sort @$b : scalar @$b
}

sub biomePrefixMatchers {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::bodyPrefixMatchers() wants list context";
	$self->cache("biomePrefixMatchers", sub {
		map { qr/^(\Q$_\E)(.*)/ }
			sort { length $b <=> length $a || $a cmp $b }
			($self->biomes, $self->miniBiomes)
	})
}

sub anomalies {
	my ($self) = @_;
	my @ret = $self->_anomalies_list;
	wantarray ? @ret : scalar @ret
}

sub _anomalies_list {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::_anomalies_list() wants list context";
	$self->cache("anomalies", sub {
		sort { $b->lat <=> $a->lat }
		map { KSP::Anomaly->new($self, $_) }
		@{$self->json->{anomalies}}
	})
}

sub rocInfo {
	my ($self) = @_;
	$self->json->{science} && $self->json->{roc} || { };
}

sub rocInfoInv {
	my ($self) = @_;
	my $i = $self->rocInfo;
	my %ret = map { $_ => [ ] } $self->biomes;
	foreach my $r (sort keys %$i) {
		my $b = $i->{$r};
		if (ref $b eq "ARRAY") {
			push @{$ret{$_}}, $r foreach @$b;
		}
	}
	\%ret
}

sub veq {
	my ($self) = @_;
	U(2 * pi * $self->radius / $self->siderealDay, "m/s")
}

sub g0 {
	goto &g;
}

sub g {
	my ($self, $height) = @_;
	U($self->mu / ($self->radius + ($height || 0)) ** 2, "m/s²")
}

sub dvLiftoff {
	my ($self) = @_;
	my $dvGraph = $self->system->dvGraph or return undef;
	my $name = $self->name;
	U($dvGraph->graph->{$name}->{"$name/LO"}, "m/s")
}

sub dvLanding {
	my ($self) = @_;
	my $dvGraph = $self->system->dvGraph or return undef;
	my $name = $self->name;
	U $dvGraph->graph->{"$name/LO"}->{$name}
}

sub siderealDay {
	my ($self) = @_;
	$self->json->{rotation}{tidallyLocked} ?
		$self->orbit->T :
		$self->json->{rotation}{rotationPeriod}
}

sub solarDayLength {
	$_[0]->json->{rotation}{solarDayLength}
}

sub maxGroundHeight {
	U(($_[0]->json->{size}{maxHeight} || 0), "m")
}

sub hasSolidSurface {
	my ($self) = @_;
	!!$self->json->{surface}{hasSolidSurface}
}

sub hasOcean {
	my ($self) = @_;
	!!$self->json->{surface}{ocean}
}

sub atmosphereDepth {
	my ($self) = @_;
	U(($self->json->{atmosphere} ? ($self->json->{atmosphere}{atmosphereDepth} || 0) : 0), "m")
}

sub lowHeight {
	my ($self) = @_;
	my $safety = 10e3;
	my $a = $self->atmosphereDepth;
	my $g = $self->maxGroundHeight;
	U(($a > $g ? $a : $g) + $safety, "m")
}

sub highHeight {
	my ($self) = @_;
	my $soi = $self->SOI;
	$soi and return U($soi - $self->radius, "m");
	U(1e9 * $self->lowHeight, "m")
}

sub orbit {
	my ($self, @rest) = @_;
	@rest or return scalar $self->cache("bodyOrbit", sub {
		my $p = $self->parent or return undef;
		KSP::Orbit2D->new($p,
			p => $self->json->{orbit}{semiLatusRectum},
			a => $self->json->{orbit}{semiMajorAxis},
			e => $self->json->{orbit}{eccentricity})
	});
	if (!grep { !isnumber($_) } @rest) {
		@rest == 1 and return KSP::Orbit2D->new($self, pe => $rest[0], e => 0);
		@rest == 2 and return KSP::Orbit2D->new($self, pe => $rest[0], ap => $rest[1]);
	}
	KSP::Orbit2D->new($self, @rest)
}

sub surface {
	my ($self) = @_;
	scalar $self->cache("surface", sub {
		KSP::Surface->new($self)
	})
}

sub lowOrbit {
	my ($self) = @_;
	my $h = $self->lowHeight;
	KSP::Orbit2D->new($self, pe => $h, e => 0);
}

sub syncOrbit {
	my ($self) = @_;
	KSP::Orbit2D->new($self, T => $self->siderealDay, e => 0)
}

sub highOrbit {
	my ($self) = @_;
	KSP::Orbit2D->new($self, pe => $self->lowHeight, ap => $self->highHeight)
}

sub intersectOrbit {
	my ($self) = @_;
	scalar $self->cache("intersectOrbit", sub {
		$self->parent or return undef;
		my $soi = $self->SOI;
		$self->parent->orbit(pe => $self->pe - $soi, ap => $self->ap + $soi)
	})
}

sub intersects {
	my ($self, $other) = @_;
	my $io = $self->intersectOrbit or return undef;
	$io->intersects($other)
}

sub tree {
	my ($self, $indent) = @_;
	defined $indent or $indent = "";
	my $ret = "$indent$self";
	$indent .= "\t";
	foreach ($self->children) {
		$ret .= "\n" . $_->tree($indent);
	}
	$ret
}

sub desc {
	my ($self) = @_;
	scalar $self->cache("desc", sub {
		my @d = ();
		push @d, "r " . $self->radius;
		push @d, "g₀ " . $self->g0;
		push @d, "↺ " . $self->system->pretty_interval($self->siderealDay)
			if $self->siderealDay;
		push @d, "SOI " . $self->SOI if $self->SOI;
		$self->name
			. ($self->isHomeWorld ? "⌂" : "")
			. ($self->isStar ? "☼" : "")
			. ($self->hasSolidSurface ? "" : "◌")
			. ($self->atmosphereDepth > 0 ? "☁" : "")
			. ($self->hasOcean ? "≈" : "")
			. "[ " . join("; ", @d) . " ]"
	})
}

sub index {
	$_[0]->json->{info}{index}
}

sub _sort {
	sort { $a->_sortkey <=> $b->_sortkey } @_
}

sub _sortkey {
	my ($self) = @_;
	$self or return 1;
	scalar $self->cache("sortkey", sub {
		my $o = $self->json->{orbit} or return 1;
		($o->{semiMajorAxis} || 0) + _sortkey($self->parent);
	})
}

1;

