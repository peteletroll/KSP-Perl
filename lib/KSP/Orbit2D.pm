package KSP::Orbit2D;

use strict;
use warnings;

use Carp;

use Math::Trig;

use TinyStruct qw(body e p);

sub BUILD {
	@_ == 4 or croak "bad " . __PACKAGE__ . "->new() parameters";
	my ($self, $body, $a, $e) = @_;
	my $p = $a * (1 - $e ** 2);
	$self->set_body($body);
	$self->set_e($e); # eccentricity
	$self->set_p($p); # semilatus rectum
	$self
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

