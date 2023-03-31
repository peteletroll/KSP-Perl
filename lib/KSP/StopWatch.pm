package KSP::StopWatch;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(stopwatch);

our $HIRES;
BEGIN {
	$HIRES = 0;
	if (eval { require Time::HiRes }) {
		Time::HiRes->import(qw( time ));
		$HIRES = 1;
	} else {
		$HIRES = 0;
	}
}

use overload
	bool => sub { $_[0] },
	'0+' => \&read,
	'""' => sub {
		my ($t) = @_;
		__PACKAGE__ . "("
		. $t->read
		. ($$t > 0 ? ", running" : "")
		. ")"
	};

# the object is a reference to a real
# the object has two states:
#   * running: the real is the start time (always > 0)
#   * stopped: the real is the elapsed time, negated (always <= 0)

sub new {
	bless \(my $c = 0)
}

*stopwatch = \&new;

sub start {
	my $t = $_[0];
	$$t <= 0 and $$t = $$t + time;
	$t
}

sub stop {
	my $t = $_[0];
	$$t > 0 and $$t = $$t - time;
	$t
}

sub read {
	my $t = $_[0];
	$$t <= 0 ? -$$t : time - $$t
}

sub reset {
	my $t = $_[0];
	$$t = 0;
	$t
}

1;

