package KSP::Orbit2D;

use strict;
use warnings;

use Carp;

use Math::Trig;

use TinyStruct qw(body e p);

our %newpar = map { $_ => 1 } qw(p e a pe ap);

sub BUILD {
	my ($self, $body, %par) = @_;
	$newpar{$_} or confess "unknown orbit parameter $_" foreach keys %par;

	my $par = \%par;
	my $r = $body->radius();

	_defined($par, qw(ap pe !a))
		and $par{a} = ($par{ap} + $par{pe}) / 2.0 + $r;

	_defined($par, qw(ap pe !e))
		and $par{e} = ($par{ap} - $par{pe}) / ($par{ap} + $par{pe} + 2 * $r);

	_defined($par, qw(!e)) and confess "can't compute e";
	my $e = $par{e};

	_defined($par, qw(a !p))
		and $par{p} = $par{a} * (1 - $e * $e);

	_defined($par, qw(!p)) and confess "can't compute p";
	my $p = $par{p};

	$self->set_body($body);
	$self->set_e($e); # eccentricity
	$self->set_p($p); # semilatus rectum
	$self
}

sub _defined($@) {
	my ($p, @c) = @_;
	foreach my $c (@c) {
		$c =~ /^(!*)(\w+)$/ or confess "bad _defined() spec";
		(defined $p->{$2} xor $1) or return 0;
	}
	1
}

sub _need_ellipse {
	$_[0]->e() < 1 or confess "not allowed for open orbit";
}

sub a { # major semiaxis
	my ($self) = @_;
	$self->_need_ellipse();
	1 / $self->inv_a()
}

sub inv_a { # 1 / major semiaxis
	my ($self) = @_;
	(1 - $self->e() ** 2) / $self->p()
}

sub T { # orbital period
	my ($self) = @_;
	$self->_need_ellipse();
	2 * pi * sqrt($self->a ** 3 / $self->body->mu)
}

sub pe { # periapsis height
	my ($self) = @_;
	$self->p / (1 + $self->e) - $self->body->radius
}

sub ap { # apoapsis height
	my ($self) = @_;
	$self->_need_ellipse();
	$self->p / (1 - $self->e) - $self->body->radius
}

sub v_from_vis_viva {
	my ($self, $h) = @_;
	my $r = $h + $self->body->radius;
	# $r or confess "division by zero";
	sqrt($self->body->mu * (2 / $r - $self->inv_a))
}

sub vmax {
	my ($self) = @_;
	$self->v_from_vis_viva($self->pe())
}

sub vmin {
	my ($self) = @_;
	$self->e() < 1 ?
		$self->v_from_vis_viva($self->ap()) :
		sqrt(-$self->body->mu() * $self->inv_a())
}

sub desc {
	my ($self) = @_;
	my $open = $self->e() >= 1;
	my @d = ();
	push @d, $self->body->name();
	push @d, sprintf("pe=%g", $self->pe());
	$open or push @d, sprintf("ap=%g", $self->ap());
	push @d, sprintf("vmax=%g", $self->vmax());
	push @d, sprintf("vmin=%g", $self->vmin());
	$open or push @d, KSP::Time->new($self->T)->pretty_interval();
	"[" . join(";", @d) . "]"
}

1;

