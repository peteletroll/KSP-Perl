package KSP::Anomaly;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::TinyStruct qw(body json);

sub BUILD {
	my ($self, $body, $json) = @_;
	ref $body eq "KSP::Body" or croak "KSP::Body needed here";
	ref $json eq "HASH" or croak "hash needed here";
	$self->set_body($body);
	$self->set_json($json);
	$self
}

use overload
	'""' => \&desc;

sub name {
	my ($self) = @_;
	$self->json->{name}
}

sub lat {
	my ($self) = @_;
	$self->json->{lat}
}

sub lon {
	my ($self) = @_;
	$self->json->{lon}
}

sub _coord($$$) {
	my ($deg, $plus, $minus) = @_;
	sprintf("%1.2f°", abs($deg))
		. ($deg >= 0 ? $plus : $minus)
}

sub desc {
	my ($self) = @_;
	$self->name . "[ " . $self->body->name . ", "
		. _coord($self->lat, "N", "S") . ", "
		. _coord($self->lon, "E", "W") . " ]"
}

1;

