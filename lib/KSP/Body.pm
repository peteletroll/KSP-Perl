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
use KSP::Course;
use KSP::Anomaly;

use KSP::Util qw(U proxy);
proxy("KSP::Orbit2D" => sub { $_->orbit }, qw(pe ap e a b));
proxy("KSP::Course" => sub { KSP::Course->new($_->lowOrbit) });

use KSP::TinyStruct qw(json system +KSP::Cache);

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

use overload
	fallback => 1,
	'==' => sub { $_[0]->name eq ($_[1] ? $_[1]->name : "") },
	'!=' => sub { $_[0]->name ne ($_[1] ? $_[1]->name : "") },
	'""' => \&desc;

sub name {
	$_[0]->json->{info}{name}
}

sub radius {
	$_[0]->json->{size}{radius}
}

sub SOI {
	my ($self) = @_;
	$self->json->{size}{sphereOfInfluence} ||= do {
		my $parent = $self->parent;
		$parent ? $self->orbit->a * ($self->mass / $parent->mass) ** (2 / 5) : undef
	}
}

sub mass {
	my ($self) = @_;
	my $mass = $self->json->{size}{mass};
	defined $mass and return $mass;
	my $mu = $self->json->{size}{mu};
	defined $mu or confess "can't compute ", $self->name, " mass";
	$self->json->{size}{mass} = $mu / $self->system->G
}

sub mu {
	my ($self) = @_;
	my $mu = $self->json->{size}{mu};
	defined $mu and return $mu;
	my $mass = $self->json->{size}{mass};
	defined $mass or confess "can't compute ", $self->name, " mu";
	$self->json->{size}{mu} = $mass * $self->system->G;
}

sub estimated_G {
	my ($self) = @_;
	my $mu = $self->json->{size}{mu};
	my $mass = $self->json->{size}{mass};
	$mu && $mass ? $mu / $mass : undef
}

sub parent {
	my ($self) = @_;
	my $o = $self->json->{orbit} or return undef;
	my $p = $o->{referenceBody} or return undef;
	$self->system->body($p)
}

sub children {
	my ($self) = @_;
	wantarray or croak __PACKAGE__ . "::children() wants list context";
	my $c = $self->json->{info}{orbitingBodies} or return ();
	_sort(map { $self->system->body($_) } @$c)
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
	wantarray or croak "pathToRoot() wants list context";
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

sub orbitNormal {
	my ($self) = @_;
	my $o = $self->json->{orbit} or return;
	# https://en.wikipedia.org/wiki/Orbital_elements#Euler_angle_transformations
	my $incl = $o->{inclinationRad};
	my $longOfAN = $o->{longitudeOfAscendingNodeRad};
	my $argOfPE = $o->{argumentOfPeriapsisRad};
	V(
		sin($incl) * sin($longOfAN),
		-sin($incl) * cos($longOfAN),
		cos($incl)
	)
}

sub density {
	my ($self) = @_;
	my $volume = 4 / 3 * pi * $self->radius ** 3;
	$self->mass / $volume
}

sub biomes {
	my ($self) = @_;
	my $b = $self->json->{science} && $self->json->{science}{biomes};
	ref $b eq "ARRAY" ? sort @$b : ()
}

sub miniBiomes {
	my ($self) = @_;
	my $b = $self->json->{science} && $self->json->{science}{miniBiomes};
	ref $b eq "ARRAY" ? sort @$b : ()
}

sub biomeSuffixMatchers {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "->bodySuffixMatchers() wants list context";
	$self->cache("biomeSuffixMatchers", sub {
		map { qr/(.+)(\Q$_\E)$/ }
			sort { length $b <=> length $a || $a cmp $b }
			($self->biomes, $self->miniBiomes)
	})
}

sub anomalies {
	my ($self) = @_;
	wantarray or croak __PACKAGE__ . "::anomalies() wants list context";
	sort { $b->lat <=> $a->lat }
		map { KSP::Anomaly->new($self, $_) }
		@{$self->json->{anomalies}}
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
	2 * pi * $self->radius / $self->rotationPeriod
}

sub g0 {
	goto &g;
}

sub g {
	my ($self, $height) = @_;
	$self->mu / ($self->radius + ($height || 0)) ** 2
}

sub dvLiftoff {
	my ($self) = @_;
	my $dvGraph = $self->system->dvGraph or return undef;
	my $name = $self->name;
	$dvGraph->graph->{$name}->{"$name/LO"}
}

sub dvLanding {
	my ($self) = @_;
	my $dvGraph = $self->system->dvGraph or return undef;
	my $name = $self->name;
	$dvGraph->graph->{"$name/LO"}->{$name}
}

sub rotationPeriod {
	my ($self) = @_;
	$self->json->{rotation}{tidallyLocked} ?
		$self->orbit->T :
		$self->json->{rotation}{rotationPeriod}
}

sub solarDayLength {
	$_[0]->json->{rotation}{solarDayLength}
}

sub maxGroundHeight {
	my ($self) = @_;
	$self->json->{size}{maxHeight} || 0
}

sub lowHeight {
	my ($self) = @_;
	my $safety = 10e3;
	$self->json->{atmosphere} ?
		($self->json->{atmosphere}{atmosphereDepth} || $safety) + $safety :
		($self->json->{size}{maxHeight} || $safety) + $safety;
}

sub highHeight {
	my ($self) = @_;
	my $soi = $self->SOI;
	$soi and return $soi - $self->radius;
	1e9 * $self->lowHeight
}

sub orbit {
	my ($self, @rest) = @_;
	@rest == 1 and return KSP::Orbit2D->new($self, pe => $rest[0], e => 0);
	@rest and return KSP::Orbit2D->new($self, @rest);
	scalar $self->cache("bodyOrbit", sub {
		my $p = $self->parent or return undef;
		KSP::Orbit2D->new($p,
			p => $self->json->{orbit}{semiLatusRectum},
			a => $self->json->{orbit}{semiMajorAxis},
			e => $self->json->{orbit}{eccentricity})
	})
}

sub lowOrbit {
	my ($self) = @_;
	my $h = $self->lowHeight;
	KSP::Orbit2D->new($self, pe => $h, e => 0);
}

sub syncOrbit {
	my ($self) = @_;
	KSP::Orbit2D->new($self, T => $self->rotationPeriod, e => 0)
}

sub highOrbit {
	my ($self) = @_;
	KSP::Orbit2D->new($self, pe => $self->lowHeight, ap => $self->highHeight)
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
	my @d = ();
	push @d, "r " . U($self->radius) . "m";
	push @d, "g₀ " . U($self->g0) . "m/s²";
	push @d, "soi " . U($self->SOI) . "m" if $self->SOI;
	push @d, "rot " . $self->system->pretty_interval($self->rotationPeriod)
		if $self->rotationPeriod;
	$self->name . "[ " . join("; ", @d) . " ]"
}

sub _sort {
	sort { $a->_sortkey <=> $b->_sortkey } @_
}

sub _sortkey {
	my ($self) = @_;
	scalar $self->cache("sortkey", sub {
		my $o = $self->orbit;
		$o ? $o->a + $o->body->_sortkey : 1
	})
}

1;

