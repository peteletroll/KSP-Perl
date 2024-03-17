package KSP::Util;

use utf8;
use strict;
use warnings;

use File::stat;

use Exporter qw(import);
our @EXPORT_OK = qw(U Part Tech Resource sortby isnumber stumpff2 stumpff3 error matcher proxy deparse filekey CACHE);

use Carp;
use Scalar::Util qw(dualvar isdual looks_like_number);
use Math::Trig;

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
	[ "n", 1e-9 ],
	[ "p", 1e-12 ],
	[ "f", 1e-15 ],
	[ "a", 1e-18 ],
	[ "z", 1e-21 ],
	[ "y", 1e-24 ],
);

sub U($;$$) {
	my ($x, $d, $unit) = @_;
	defined $x or return;
	ref $x and return $x;
	$x += 0;
	my $x0 = $x;
	if (!defined $unit && !isnumber($d)) {
		($d, $unit) = (undef, $d);
	}
	defined $d or $d = 3;
	defined $unit or $unit = "";

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
		return dualvar($x0, sprintf("%.${d}f%s%s", $x, $m, $unit));
	}

	dualvar($x0, sprintf("%g%s", $x0, $unit))
}

sub Part(;$) {
	require KSP::Part;
	@_ ? KSP::Part->get($_[0]) : KSP::Part->all()
}

sub Tech(;$) {
	require KSP::Tech;
	@_ ? KSP::Tech->get($_[0]) : KSP::Tech->all()
}

sub Resource(;$) {
	require KSP::Resource;
	@_ ? KSP::Resource->get($_[0]) : KSP::Resource->all()
}

sub sortby(&@) {
	my ($k, @l) = @_;
	local $_;
	map { $_->[1] }
	sort {
		my ($ka, $kb) = ($a->[0], $b->[0]);
		defined($ka) or return defined($kb) ? -1 : 0;
		defined($kb) or return 1;
		isnumber($ka) and return isnumber($kb) ? $ka <=> $kb : -1;
		return isnumber($kb) ? 1 : $ka cmp $kb;
	} map { [ $k->(), $_ ] }
	@l
}

sub isnumber($) {
	isdual($_[0]) || looks_like_number($_[0])
}

sub stumpff2($) {
	my ($z) = @_;
	$z > 0 and return (1 - cos(sqrt($z))) / $z;
	$z < 0 and return (cosh(sqrt(-$z)) - 1) / (-$z);
	return 1.0/2;
}

sub stumpff3($) {
	my ($z) = @_;
	$z > 0 and return (sqrt($z) - sin(sqrt($z))) / sqrt($z) ** 3;
	$z < 0 and return (sinh(sqrt(-$z)) - sqrt(-$z)) / sqrt(-$z) ** 3;
	return 1.0/6;
}

sub error($$) {
	my ($x1, $x2) = @_;
	$x1 == $x2 and return 0;
	2 * abs($x1 - $x2) / (abs($x1) + abs($x2))
}

sub matcher($) {
	my ($v) = @_;
	defined $v or return undef;
	my $r = ref $v;
	if (!$r) {
		$v = qr/^\Q$v\E$/;
	} elsif ($r ne "Regexp") {
		croak "got $r, string or Regexp required";
	}
	$v
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

sub deparse($) {
	my ($sub) = @_;
	my $out = undef;
	if (eval { require Data::Dump::Streamer; 1 }) {
		my $dds = Data::Dump::Streamer->new;
		$dds->Freezer(sub { "$_[0]" });
		$dds->Data($sub);
		$out = $dds->Out;
	} else {
		require B::Deparse;
		$out = "sub " . B::Deparse->new->coderef2text($_[0]) . "\n";
	}
	print $out;
	()
}

sub filekey($) {
	my ($file) = @_;
	my $stat = stat($file)
		or return;
	$stat->dev . ":" . $stat->ino
}

our $FileCache;
sub CACHE($$$) {
        my ($name, $expire, $sub) = @_;
        unless (defined $expire) {
                return scalar $sub->();
        }
	unless (defined $FileCache) {
		my $pkg = __PACKAGE__;
		$pkg =~ s/\W+/-/gs;
		require Cache::FileCache;
		$FileCache = new Cache::FileCache({
			namespace => "$pkg-$>",
			auto_purge_interval => "1 hour"
		});
	}
        utf8::encode($name);
        my $ret = $FileCache->get($name);
        if (defined $ret) {
		# warn "CACHED `$name'\n";
		$ret = $ret->[0];
	} else {
		# warn "GENERATING `$name'\n";
                $ret = $sub->();
                $FileCache->set($name, [ $ret ], $expire);
        }
        return $ret;
}

1;

