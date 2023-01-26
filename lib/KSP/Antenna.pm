package KSP::Antenna;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;
use KSP::DBNode;
use KSP::Util qw(U);

use KSP::TinyStruct qw(+KSP::DBNode);

sub type {
	my ($self) = @_;
	scalar $self->cache("type", sub {
		$self->node->get("antennaType", "UNK")
	})
}

sub range {
	my ($self) = @_;
	scalar $self->cache("range", sub {
		$self->node->get("antennaPower", 0)
	})
}

sub exponent {
	my ($self) = @_;
	scalar $self->cache("exponent", sub {
		$self->node->get("antennaCombinableExponent", 0.75)
	})
}

sub combinable {
	my ($self) = @_;
	scalar $self->cache("combinable", sub {
		$self->node->get("antennaCombinable", "") eq "True"
	})
}

sub desc {
	my ($self) = @_;
	$self->cache("desc", sub {
		"Antenna[ "
			. lc $self->type . "; "
			. U($self->range) . "m"
			. ($self->combinable ? "; combinable ^" . $self->exponent : "")
			. " ]"
	})
}

1;

