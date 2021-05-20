package KSP::Body;

use utf8;
use strict;
use warnings;

use Carp;

use Math::Vector::Real;

use Math::Trig;

use KSP::SolarSystem;
use KSP::Orbit2D;
use KSP::Course;

use KSP::Util qw(U proxy);
proxy("KSP::Orbit2D" => sub { $_->orbit }, qw(pe ap e));
proxy("KSP::Course" => sub { KSP::Course->new($_->lowOrbit) });

use KSP::TinyStruct qw(json);

sub BUILD {
	my ($self, $json) = @_;
	$self->set_json($json);
	$self
}

use overload
	fallback => 1,
	'==' => sub { $_[0]->name eq ($_[1] ? $_[1]->name : "") },
	'!=' => sub { $_[0]->name ne ($_[1] ? $_[1]->name : "") },
	'""' => \&desc;

our $G;
sub G {
	defined $G and return $G;
	my ($M, $mu) = (0, 0);
	foreach my $b (all()) {
		$M += $b->json->{size}{mass};
		$mu += $b->json->{size}{mu};
	}
	$G = $mu / $M
}

sub all($) {
	wantarray or croak __PACKAGE__, "->all() wants list context";
	_sort(KSP::SolarSystem->bodies)
}

sub get($$) {
	my ($pkg, $name) = @_;
	KSP::SolarSystem->body($name)
}

sub root($) {
	KSP::SolarSystem->root
}

sub name {
	$_[0]->json->{info}{name}
}

sub radius {
	$_[0]->json->{size}{radius}
}

sub SOI {
	$_[0]->json->{size}{sphereOfInfluence}
}

sub mu {
	$_[0]->json->{size}{mu}
}

sub parent {
	my $o = $_[0]->json->{orbit} or return undef;
	my $p = $o->{referenceBody} or return undef;
	__PACKAGE__->get($p)
}

sub children {
	wantarray or croak __PACKAGE__ . "::children() wants list context";
	my $c = $_[0]->json->{info}{orbitingBodies} or return ();
	_sort(map { __PACKAGE__->get($_) } @$c)
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

sub normalDiag {
	my ($self) = @_;
	my $n1 = $self->orbitNormal;
	my $n2 = $self->orbitNormal2;
	# warn "N1 $n1\n";
	# warn "N2 $n2\n";
	# warn "N2-N1 ", ($n2 - $n1), "\n";
	my $n1xy = V($n1->[0], $n1->[1]);
	my $n2xy = V($n2->[0], $n2->[1]);
	# warn "N1XY $n1xy\n";
	# warn "N2XY $n2xy\n";
	warn "ATANXY ", rad2deg(atan2($n1xy, $n2xy)), "\n";
}

sub rotationPeriod {
	$_[0]->json->{rotation}{rotationPeriod}
}

sub solarDayLength {
	$_[0]->json->{rotation}{solarDayLength}
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
	1e6 * $self->lowHeight
}

sub orbit {
	my ($self, @rest) = @_;
	@rest and return KSP::Orbit2D->new($self, @rest);
	my $p = $self->parent or return undef;
	$self->json->{_orbit_} ||= KSP::Orbit2D->new($p,
		p => $self->json->{orbit}{semiLatusRectum},
		e => $self->json->{orbit}{eccentricity})
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

sub desc {
	my ($self) = @_;
	my @d = ();
	push @d, "r " . U($self->radius) . "m";
	push @d, "g₀ " . U($self->mu / $self->radius ** 2) . "m/s²";
	push @d, "soi " . U($self->SOI) . "m" if $self->SOI;
	push @d, "rot " . KSP::Time->new($self->rotationPeriod)->pretty_interval;
	$self->name . "[ " . join("; ", @d) . " ]"
}

sub _sort {
	sort { $a->_sortkey <=> $b->_sortkey } @_
}

sub _sortkey {
	my ($self) = @_;
	$self->json->{_sortkey_} ||= do {
		my $a = 1;
		for (my $o = $self->orbit; $o; $o = $o->body->orbit) {
			$a += $o->a;
		}
		# warn "SORT\t", $self->name, "\t$a\n";
		$a
	}
}

1;

