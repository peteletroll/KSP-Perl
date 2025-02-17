package KSP::ConfigValue;

use strict;
use warnings;

use KSP::TinyStruct qw(op name value);

use overload
	bool => sub { $_[0] },
	'""' => \&asString;

sub addTo {
	my ($self, $node) = @_;
	my $l = $node->_values() || $node->set__values([ ]);
	push @$l, $self;
	$self
}

sub asString {
	my ($self) = @_;
	_encode($self->name()) . " "
		. $self->op() . " "
		. _encode($self->value())
}

sub _comment {
	$KSP::ConfigNode::PUTCOMMENTS or return undef;
	my ($self) = @_;
	my $name = $self->name();
	my $value = $self->value();
	# warn "_COMMENT(", dump($name), ", ", dump($value), ")\n";
	my $ATTACH = \@KSP::Part::ATTACH;
	if ($name eq "attachRules") {
		# warn "$name\n";
		defined $value or return undef;
		# warn "$name: ", dump($value), "\n";
		$value =~ s/\s+//g;
		my @f = split /,/, $value;
		my @a = ();
		foreach my $i (0..$#$ATTACH) {
			my $a = $ATTACH->[$i];
			push @a, ($f[$i] ? $a : "no $a");
		}
		join(", ", @a)
	} elsif ($name =~ /UT$/ && $value =~ /^-?\d/) {
		# KSP::Time->new($value)->pretty_date()
	} else {
		undef
	}
}

sub _encode {
	goto \&KSP::ConfigNode::_encode;
}

1;

