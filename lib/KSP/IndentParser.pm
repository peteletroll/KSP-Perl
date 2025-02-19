package KSP::IndentParser;

use strict;
use warnings;

use Carp;

our $TAB = 8;

sub new {
	@_ == 1 or croak "bad parameters";
	bless {
		st => undef,
	}, $_[0]
}

sub _get_indent($) {
	$_[0] =~ s/\s+$//s;
	return undef if $_[0] eq "";
	$_[0] =~ /\n/ and croak "can't contain newlines";
	my $ind = 0;
	while ($_[0] =~ /\G(?:( +)|(\t))/gc) {
		if ($1) {
			$ind += length $1;
		} elsif ($2) {
			$ind = $ind + $TAB - ($ind % $TAB);
		} else {
			croak "fatal";
		}
	}
	$_[0] = substr($_, pos($_[0]) || 0);
	$ind
}

sub _add {
	my ($self, $newind, $newline) = @_;
	my $st = ($self->{st} ||= [ { ind => $newind, body => [ ] } ]);
	my $curind = $st->[-1]{ind};
	if ($newind > $curind) {
		my $new = { ind => $newind, body => [ ] };
		push @{$st->[-1]{body}}, $new->{body};
		push @$st, $new;
	} elsif ($newind < $curind) {
		pop @$st while @$st > 1 && $newind < $st->[-1]{ind};
		$newind == $st->[-1]{ind} or die "$0: bad dedent $curind→$newind at `$_'\n";
	}
	push @{$st->[-1]{body}}, $_;
	$self
}

sub add {
	my $self = shift;
	foreach (@_) {
		defined or next;
		my $ind = _get_indent($_);
		defined $ind or next;
		defined $self->{ind} or $self->{ind} = $ind;
		$self->_add($ind, $_);
	}
	$self
}

sub body {
	my ($self) = @_;
	my $b = $self->{st};
	$b and $b = $b->[0];
	$b and $b = $b->{body};
	$b ||= [ ];
	wantarray ? @$b : $b
}

1;

