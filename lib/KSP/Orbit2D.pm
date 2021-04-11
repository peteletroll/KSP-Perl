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
	$_[0]->e < 1 or croak "not allowed for open orbit";
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

sub pe { # periapsis radius
	my ($self) = @_;
	$self->p / (1 + $self->e)
}

sub ap { # apoapsis radius
	my ($self) = @_;
	$self->_need_ellipse();
	$self->p / (1 - $self->e)
}

sub hpe { # periapsis height
	my ($self) = @_;
	$self->pe - $self->body->radius
}

sub hap { # apoapsis height
	my ($self) = @_;
	$self->ap - $self->body->radius
}

sub v_from_vis_viva {
	my ($self) = @_;
	my $r = $self->body->radius + shift;
	sqrt($self->body->mu * (2 / $r - $self->inv_a))
}

sub desc {
	my ($self) = @_;
	"[body: " . $self->body->name()
		. ", period: " . KSP::Time->new($self->T)->pretty_interval()
		. ", pe: " . $self->hpe()
		. ", ap: " . $self->hap()
		. "]"
}

1;

