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
		$combinable = $module->get("antennaCombinable", "") =~ /true/i;
		$exponent = $module->get("antennaCombinableExponent");
	}
	$self->set_type($type);
	$self->set_range(U($range, "m"));
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
	U(sqrt($self->range * $other->range), "m")
}

sub combine {
	@_ && !ref $_[0] and shift @_;
	my @a = sort { $b->range <=> $a->range } grep {
		UNIVERSAL::isa($_, __PACKAGE__) or croak __PACKAGE__, " needed";
		$_->combinable
	} @_;

	my ($expnum, $rangesum) = (0, 0);
	foreach (@a) {
		$expnum += $_->range * $_->exponent;
		$rangesum += $_->range;
	}
	$rangesum or return KSP::Antenna->new(0);
	my $exp = $expnum / $rangesum;
	my $range = $a[0]->range * ($rangesum / $a[0]->range) ** $exp;
	KSP::Antenna->new("COMBINED", $range)
}

sub multi {
	my ($self, $n) = @_;
	combine(($self) x $n)
}

sub desc {
	my ($self) = @_;
	$self->cache("desc", sub {
		"Antenna"
			. "[ "
			. $self->range . "; "
			. $self->type
			. ($self->combinable ? "; combinable ^" . $self->exponent : "")
			. " ]"
	})
}

1;

