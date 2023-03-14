package KSP::TinyParser;

use 5.008000;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(
	REX EOS
	SEQ FIRST REP AHEAD
	RULE EV
	EXTRACT
	ERR
);

our $VERSION = '0.01';

use Carp;

sub _fix(@);
sub _tag($;$);

our $TRACE = 0;
our $LEVEL = 0;

sub new {
	my $pkg = shift;
	my $ret = (@_ == 1 && ref $_[0] eq "HASH") ? { %{$_[0]} } : { @_ };

	my $spc = delete($ret->{_}) || qr{\s+};
	ref $spc eq "Regexp" or croak "space definition must be regexp";

	($ret->{$_}) = _fix($ret->{$_}) foreach keys %$ret;

	$ret->{_} = qr{\G$spc};

	bless $ret, $pkg
}

sub REX($) {
	my $re = shift;

	my $sre = "$re";
	$sre =~ s/^\(\?\^:(.*)\)$/$1/;
	$sre =~ s/\s+/ /gs;

	$re = qr{\G$re};

	my $compiled = qq{
		sub {
			\$_[1] =~ m(\$_[0]->{_})ogc;
			\$_[1] =~ m($re)gc
				or return undef;
			defined \$1 ? \$1 : "MATCH"
		}
	};

	my $sub = eval $compiled
		or die "FATAL: $re: $@\n";
	_tag "REX[$sre]", $sub
}

sub SEQ(@) {
	if (@_ == 0) {
		sub { "EMPTY SEQ" }
	} else {
		my ($first, @seq) = _fix @_;
		if (@seq) {
			_tag sub {
				my $back = pos $_[1];
				my $st = [ ];

				defined (my $ret = $first->($_[0], $_[1], $st))
					or return undef;
				foreach my $matcher (@seq) {
					ref($ret) eq "ARRAY" and $ret == $st and $ret = [ @$ret ];
					push @$st, $ret;

					$ret = $matcher->($_[0], $_[1], $st);
					unless (defined $ret) {
						pos $_[1] = $back;
						last;
					}
				}
				$ret
			}
		} else {
			$first
		}
	}
}

sub FIRST(@) {
	my @alt = _fix @_;
	_tag sub {
		foreach my $matcher (@alt) {
			my $ret = $matcher->($_[0], $_[1]);
			defined $ret and return $ret;
		}
		undef
	}
}

sub REP($;$$) {
	my ($matcher, $min, $max) = @_;
	($matcher) = _fix $matcher;
	if (defined $min) {
		if (defined $max) {
			croak "bad limits" if $max < $min;
		} else {
			$max = $min;
		}
	} else {
		$min = 0;
		$max = 999_999_999;
	}
	_tag sub {
		my $back = pos $_[1];
		my @ret = ();
		while (@ret < $max) {
			my $ret = $matcher->($_[0], $_[1]);
			last unless defined $ret;
			push @ret, $ret;
		}
		if (@ret < $min) {
			pos $_[1] = $back;
			return undef;
		}
		\@ret;
	}
}

sub RULE($) {
	my $rule = shift;
	my $m = undef;
	_tag "RULE[$rule]", sub {
		$m ||= $_[0]{$rule}
			or croak "undefined rule '$rule'";
		$m->($_[0], $_[1])
	}
}

sub EV(&) { $_[0] }

sub EOS() {
	_tag sub {
		$_[1] =~ m/$_[0]->{_}/gc;
		$_[1] =~ /\G\Z/ ? "EOS" : undef
	}
}

sub AHEAD($) {
	my ($matcher) = _fix @_;
	_tag sub {
		my $back = pos $_[1];
		my $ret = $matcher->($_[0], $_[1]);
		pos $_[1] = $back;
		$ret
	}
}

sub EXTRACT($@) {
	require Text::Balanced;
	my ($name, @extra) = @_;
	my $extractor = $Text::Balanced::{"extract_$name"}
		or die "no Text::Balanced::extract_$name()";
	$extractor = \&$extractor;
	my $matcher = sub {
		$_[1] =~ m/$_[0]->{_}/gc;
		my ($ret) = $extractor->($_[1], @extra);
		# warn "EXTRACTED '$ret'\n" if defined $ret;
		$ret
	};
	_tag "EXTRACT[$name]", $matcher
}

sub ERR($) {
	my ($msg) = @_;
	_tag sub {
		my $line = _line($_[1]);
		warn "line $line: $msg ", _status($_[1]), "\n";
		undef
	}
}

sub _fix(@) {
	map {
		my $r = ref $_;
		if (!$r) {
			REX(qr{\Q$_\E})
		} elsif ($r eq "Regexp") {
			REX(qr{$_})
		} elsif ($r eq "SCALAR") {
			RULE($$_);
		} elsif ($r =~ /@{[ "^" . __PACKAGE__ . "::" ]}/o) {
			$_
		} elsif ($r eq "CODE") {
			$_
		} else {
			$r = $_;
			sub { $r }
		}
	} @_
}

sub _line($) {
	my $pos = pos $_[0] || 0;
	my $st = substr($_[0], 0, $pos);
	my $line = ($st =~ tr/\n/\n/) + 1;
	$line
}

sub _status($) {
	my $pos = pos $_[0] || 0;
	my $st = substr($_[0], $pos, 30);
	$st =~ s/\s*\n/ /;
	$st =~ s/\s+/ /gs;
	sprintf ' at "%s" [%d/%d]',
		$st, $pos, length($_[0])
}

sub _tostr($) {
	"$_[0]"
}

sub _tag($;$) {
	my ($tag, $sub) = @_;
	unless (defined $sub) {
		$sub = $tag;
		$tag = (caller(1))[3];
		$tag =~ s/.*:://;
	}

	bless $sub, __PACKAGE__ . "::$tag";

	{
		my $i = 0;
		$i++ while caller($i) eq __PACKAGE__;
		my ($file, $line) = (caller($i))[1, 2];
		$file =~ s/.*\///;
		# $tag = "$tag\@$file:$line";
	}

	if ($TRACE) {
		my $inner = $sub;
		my $trace_return = $TRACE > 1;
		$sub = sub {
			my $l = $LEVEL;
			local $LEVEL = $l + 1;
			my $indent = "[T] " . (": " x $l);
			warn $indent, "$tag try", _status($_[1]), "\n";
			my $ret = $inner->(@_);
			if (defined $ret) {
				warn $indent, "$tag success\n";
				if ($trace_return) {
					my $d = tostr($ret);
					$d =~ s/^/$indent= /gm;
					warn $d;
				}
			} else {
				warn $indent, "$tag fail\n";
			}
			$ret
		};
	}
	$sub
}

sub parse {
	my $self = shift;

	my $startrule = shift;
	my $start = $self->{$startrule}
		or croak "no rule '$startrule'";

	study $_[0];

	pos($_[0]) = 0 unless defined pos($_[0]);

	$start->($self, $_[0])
}

1;

