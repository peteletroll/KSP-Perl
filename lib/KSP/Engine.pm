package KSP::Engine;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;
use KSP::DB;
use KSP::DBNode;
use KSP::Util qw(U);

use KSP::TinyStruct qw(+KSP::DBNode);

sub id {
	my ($self) = @_;
	$self->node->get("engineID", "Engine")
}

sub maxThrust {
	my ($self) = @_;
	scalar $self->cache("maxThrust", sub {
		1000 * $self->node->get("maxThrust", 0)
	})
}

sub desc {
	my ($self) = @_;
	$self->cache("desc", sub {
		$self->id . "[ "
		. $self->name . "; "
		. U($self->maxIsp) . "m/s; "
		. U($self->maxThrust) . "N"
		. " ]"
	})
}

1;

