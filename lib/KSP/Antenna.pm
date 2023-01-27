package KSP::Antenna;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;
use KSP::DBNode;
use KSP::Util qw(U);

use KSP::TinyStruct qw(part type range combinable exponent +KSP::DBNode);

sub BUILD {
	my ($self, $type, $range, $combinable, $exponent) = @_;
	if (@_ == 2 && UNIVERSAL::isa($_[1], "KSP::Part")) {
		my $part = $type;
		my $module = $part->node->getnodes("MODULE", name => "ModuleDataTransmitter")
			or return undef;
		$self->set_part($part);
		$self->set_node($module);
		$type = $module->get("antennaType", "UNK") . "@" . $part->name;
		$range = $module->get("antennaPower", 0);
		$combinable = $module->get("antennaCombinable");
		$exponent = $module->get("antennaCombinableExponent");
	}
	$self->set_type($type);
	$self->set_range($range);
	$self->set_combinable(!!$combinable);
	$self->set_exponent($exponent || 0.75);
	$self
}

our @DSN_range = (2e9, 50e9, 250e9);

sub DSN {
	my ($pkg, $level) = @_;
	defined $level or $level = $#DSN_range;
	$level = int $level;
	$level >= 0 or $level = 0;
	$level <= $#DSN_range or $level = $#DSN_range;
	$pkg->new("DSN level $level", $DSN_range[$level])
}

sub rangeTo {
	my ($self, $other) = @_;
	sqrt($self->range * $other->range)
}

sub desc {
	my ($self) = @_;
	$self->cache("desc", sub {
		"Antenna"
			. "[ "
			. U($self->range) . "m; "
			. $self->type
			. ($self->combinable ? "; combinable ^" . $self->exponent : "")
			. " ]"
	})
}

1;

