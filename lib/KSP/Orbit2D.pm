package KSP::Orbit2D;

use strict;
use warnings;

use Math::Trig;

use TinyStruct qw(body a e p);

sub BUILD {
	@_ == 4 or die "bad Orbit2D constructor parameters";
	my ($self, $body, $a, $e) = @_;
	my $p = $a * (1 - $e ** 2);
	$self->set_body($body);
	$self->set_a($a); # major semiaxis
	$self->set_e($e); # eccentricity
	$self->set_p($p); # semilatus rectum
	$self
}

sub T { # orbital period
	my ($self) = @_;
	2 * pi * sqrt($self->a ** 3 / $self->body->mu)
}

sub pe { # periapsis radius
	my ($self) = @_;
	$self->p / (1 + $self->e)
}

sub ap { # apoapsis radius
	my ($self) = @_;
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
	sqrt($self->body->mu * (2 / $r - 1 / $self->a))
}

sub desc {
	my ($self) = @_;
	"[body: " . $self->body->name()
		. ", period: " . KSP::Time->new($self->T)->pretty_interval()
		# . ", period: " . $self->T
		. ", pe: " . $self->hpe()
		. ", ap: " . $self->hap()
		. "]"
}

1;

