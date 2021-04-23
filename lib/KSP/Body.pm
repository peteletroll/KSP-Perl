package KSP::Body;

use strict;
use warnings;

use FastVector;

use KSP qw(U);
use KSP::SolarSystem;
use KSP::Orbit2D;

use Carp;

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
		$M += $b->{size}{mass};
		$mu += $b->{size}{mu};
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
	$_[0]{name}
}

sub radius {
	$_[0]{size}{radius}
}

sub SOI {
	$_[0]{size}{sphereOfInfluence}
}

sub mu {
	$_[0]{size}{mu}
}

sub parent {
	my $o = $_[0]->{orbit} or return undef;
	my $p = $o->{referenceBody} or return undef;
	__PACKAGE__->get($p)
}

sub children {
	wantarray or croak __PACKAGE__ . "::children() wants list context";
	my $c = $_[0]->{orbitingBodies} or return ();
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

sub hasDescendant {
	my ($self, $other) = @_;
	$other->has_ancestor($self);
}

sub orbitPeriod {
	$_[0]{orbit}{period}
}

sub orbitNormal {
	my $n = $_[0]->{orbit}{normal}
		or return undef;
	V(@$n)
}

sub rotationPeriod {
	$_[0]{rotation}{rotationPeriod}
}

sub solarDayLength {
	$_[0]{rotation}{solarDayLength}
}

sub lowHeight {
	my ($self) = @_;
	$self->{atmosphere} ?
		$self->{size}{atmosphereDepth} + 10e3 :
		($self->{size}{maxHeight} || 10e3)
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
	$self->{_orbit_} ||= KSP::Orbit2D->new($p,
		p => $self->{orbit}{semiLatusRectum},
		e => $self->{orbit}{eccentricity})
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

sub hohmannPair {
	my ($self, $other) = @_;
	foreach my $b1 ($self->pathToRoot) {
		$b1->parent or return ();
		foreach my $b2 ($other->pathToRoot) {
			$b1->parent == $b2->parent and return ($b1, $b2);
		}
	}
	return ();
}

sub hohmannTo {
	my ($self, $other) = @_;
	# warn "HOHMANN ", __PACKAGE__, "\n";
	# warn "\tSELF $self\n\tOTHER $other\n";
	$self == $other and croak "same body";
	$self->parent && $other->parent or croak "no parent";
	$self->parent == $other->parent or croak "different parents";
	$self->orbit->hohmannTo($other->orbit)
}

sub goTo {
	my ($self, $dest) = @_;
	$self->lowOrbit->goTo($dest)
}

sub desc {
	my ($self) = @_;
	my @d = ();
	push @d, "r " . U($self->radius) . "m";
	push @d, "soi " . U($self->SOI) . "m" if $self->SOI;
	push @d, "rot " . KSP::Time->new($self->rotationPeriod)->pretty_interval;
	$self->name . "[ " . join("; ", @d) . " ]"
}

sub _sort {
	sort { $a->_sortkey <=> $b->_sortkey } @_
}

sub _sortkey {
	my ($self) = @_;
	$self->{_sortkey} ||= do {
		my $a = 1;
		for (my $o = $self->orbit; $o; $o = $o->body->orbit) {
			$a += $o->a;
		}
		# warn "SORT\t", $self->name, "\t$a\n";
		$a
	}
}

1;

