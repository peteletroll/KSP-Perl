package KSP::Util;

use utf8;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(U error proxy);

our @U = (
	[ undef, 1e27 ],
	[ "Y", 1e24 ],
	[ "Z", 1e21 ],
	[ "E", 1e18 ],
	[ "P", 1e15 ],
	[ "T", 1e12 ],
	[ "G", 1e9 ],
	[ "M", 1e6 ],
	[ "k", 1e3 ],
	[ "",  1 ],
	[ "m", 1e-3 ],
	[ "μ", 1e-6 ],
);

sub U($;$) {
	my ($x, $d) = @_;
	defined $d or $d = 3;

	my $a = abs($x);
	my $m = undef;
	foreach my $u (@U) {
		if ($a >= $u->[1]) {
			$m = $u->[0];
			defined $m and $x /= $u->[1];
			last;
		}
	}

	if (defined $m) {
		$a = abs($x);
		my $i = 1;
		while ($d > 0 && $a >= $i) {
			$i *= 10;
			$d--;
		}
		return sprintf "%.${d}f%s", $x, $m;
	}

	sprintf "%g", $x
}

sub error($$) {
	my ($x1, $x2) = @_;
	$x1 == $x2 and return 0;
	2 * abs($x1 - $x2) / (abs($x1) + abs($x2))
}

sub proxy($$@) {
	my ($to, $adj, @sub) = @_;
	my $from = (caller(0))[0];
	defined $from or return;
	if (!@sub && UNIVERSAL::can($to, "proxable")) {
		@sub = $to->proxable();
		# warn "PROXABLE ${to} ", join(" ", @sub), "\n";
	}
	foreach my $name (@sub) {
		$name =~ /^\w+$/ or die "bad name \"$name\"";
		no strict "refs";
		my $method = \&{"${to}::${name}"};
		*{"${from}::${name}"} = sub {
			my ($self, @rest) = @_;
			# warn "PROXYED $name $self\n";
			local $_ = $self;
			$method->($adj->(), @rest)
		};
	}
}

1

