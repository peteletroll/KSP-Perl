package KSP::Body;

use strict;
use warnings;

use KSP::SolarSystem;
use KSP::Orbit2D;

use Carp;

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
	KSP::SolarSystem->bodies()
}

sub get($$) {
	my ($pkg, $name) = @_;
	KSP::SolarSystem->body($name)
}

sub root($) {
	KSP::SolarSystem->root()
}

sub name {
	$_[0]{name}
}

sub radius {
	$_[0]{size}{radius}
}

sub SOIRadius {
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
	my $o = $_[0]->{orbit} or return ();
	my $c = $o->{orbitingBodies} or return ();
	map { __PACKAGE__->get($_) } @$c
}

sub common_ancestor {
	my ($b1, $b2) = @_;
	my %b1anc = ();
	while ($b1) {
		$b1anc{$b1->name()} = 1;
		$b1 = $b1->parent();
	}
	while ($b2) {
		$b1anc{$b2->name()} and last;
		$b2 = $b2->parent();
	}
	$b2
}

sub orbitPeriod {
	$_[0]{orbit}{period}
}

sub solarDayLength {
	$_[0]{rotation}{solarDayLength}
}

sub lowHeight {
	my ($self) = @_;
	$self->{atmosphere} ?
		$self->{size}{atmosphereDepth} + 10e3 :
		10e3
}

sub highHeight {
	my ($self) = @_;
	my $h = $self->SOIRadius();
	$h and return $h - $self->radius();
	1000 * $self->lowHeight()
}

sub orbit {
	my ($self) = @_;
	my $p = $self->parent() or return undef;
	my $o = $p->lowOrbit();
	$o->set_p($self->{orbit}{semiLatusRectum});
	$o->set_e($self->{orbit}{eccentricity});
	$o
}

sub lowOrbit {
	my ($self) = @_;
	my $a = $self->lowHeight() + $self->radius();
	KSP::Orbit2D->new($self, a => $a, e => 0)
}

sub highOrbit {
	my ($self) = @_;
	my $r = $self->radius();
	my $rp = $self->lowHeight() + $r;
	my $ra = $self->highHeight() + $r;
	my $a = ($ra + $rp) / 2.0;
	my $e = ($ra - $rp) / ($ra + $rp);
	KSP::Orbit2D->new($self, a => $a, e => $e)
}

1;

