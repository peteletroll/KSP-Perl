package KSP::Surface;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::TinyStruct qw(+KSP::Orbit2D);

sub BUILD {
	my ($self, $body, %par) = @_;
	$self->set_body($body);
	$self->set_e(0);
	$self->set_p($body->radius);
	$self
}

sub v { 0 }

sub desc {
	my ($self) = @_;
	$self->body->name . "[ Surface ]"
}

1;

