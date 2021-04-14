package KSP::Time;

use strict;
use warnings;

use KSP::SolarSystem;

our $SECS_PER_DAY = KSP::SolarSystem->secs_per_day();
our $SECS_PER_YEAR = KSP::SolarSystem->secs_per_year();

sub _floor($) {
	my ($v) = @_;
	my $r = int $v;
	$r <= $v ? $r : $r - 1
}

sub _mod($$) {
	my ($val, $mod) = @_;
	my $ret = _floor($val / $mod);
	$_[0] = $val - $ret * $mod;
	$ret
}

sub _unpack($) {
	my ($ut) = @_;

	my $y = _mod($ut, $SECS_PER_YEAR);

	my $d = _mod($ut, $SECS_PER_DAY);

	my $h = _mod($ut, 3600);
	my $m = _mod($ut, 60);
	my $s = $ut;

	($y, $d, $h, $m, $s)
}

sub _pack(@) {
	my ($y, $d, $h, $m, $s) = @_;

	$y * $SECS_PER_YEAR
		+ ($d || 0) * $SECS_PER_DAY
		+ ($h || 0) * 3600
		+ ($m || 0) * 60
		+ ($s || 0)
}

sub new($;$) {
	my $pkg = shift;
	my $ret = @_ > 1 ? _pack(@_) : $_[0];
	bless \$ret, $pkg
}

sub secs_per_year { $SECS_PER_YEAR }

sub secs_per_day { $SECS_PER_DAY }

sub ut($) {
	${$_[0]}
}

sub pretty_date($) {
	my @t = _unpack(${$_[0]});
	$t[0] >= 0 and $t[0]++;
	$t[1]++;
	sprintf "Year %d, Day %d, %d:%02d:%06.3f", @t
}

sub pretty_interval($) {
	my @t = _unpack(${$_[0]});
	$t[0] ? sprintf "%dy %dd %d:%02d:%06.3f", @t :
	$t[1] ? sprintf "%.0s%dd %d:%02d:%06.3f", @t :
	sprintf "%.0s%.0s%d:%02d:%06.3f", @t
}

1;

