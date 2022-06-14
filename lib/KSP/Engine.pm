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

sub type {
	my ($self) = @_;
	scalar $self->node->get("EngineType", "UNK")
}

sub id {
	my ($self) = @_;
	scalar $self->node->get("engineID", "Engine")
}

sub maxThrust {
	my ($self) = @_;
	scalar $self->cache("maxThrust", sub {
		1000 * $self->node->get("maxThrust", 0)
	})
}

sub maxIsp {
	my ($self) = @_;
	scalar $self->cache("maxIsp", sub {
		my $curve = $self->node->getnodes("atmosphereCurve")
			or return 0;
		my $isp = 0;
		foreach ($curve->get("key")) {
			my @k = split;
			my $k = 0 + $k[1];
			$isp > $k or $isp = $k;
		}
		$isp
	})
}

sub propellants {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::propellants() wants list context";
	$self->cache("propellants", sub {
		sort map { $_->get("name") }
			$self->node->getnodes("PROPELLANT")
	})
}

sub propellant {
	my ($self, $name) = @_;
	my @ret =
		map { KSP::DBNode->new($name, $_) }
		$self->node->getnodes("PROPELLANT", name => $name);
	wantarray ? @ret : $ret[0]
}

sub desc {
	my ($self) = @_;
	$self->cache("desc", sub {
		$self->id . "[ "
		. $self->type . "@"
		. $self->name . "; "
		. U($self->maxIsp) . "m/s; "
		. U($self->maxThrust) . "N"
		. " ]"
	})
}

1;

