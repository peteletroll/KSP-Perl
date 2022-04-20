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
	_encode($_->name()) . " "
		. $_->op() . " "
		. _encode($_->value())
}

our @ATTACH;
BEGIN { @ATTACH = qw(stack SrfAttach allowStack allowSrfAttach allowCollision) }

sub _comment {
	my ($self) = @_;
	my $name = $self->name();
	my $value = $self->value();
	# warn "_COMMENT(", dump($name), ", ", dump($value), ")\n";
	if ($name eq "attachRules") {
		# warn "$name\n";
		defined $value or return undef;
		# warn "$name: ", dump($value), "\n";
		$value =~ s/\s+//g;
		my @f = split /,/, $value;
		my @a = ();
		foreach my $i (0..$#ATTACH) {
			$f[$i] and push @a, $ATTACH[$i];
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

