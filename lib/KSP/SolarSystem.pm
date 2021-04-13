package KSP::SolarSystem;

use strict;
use warnings;

use KSP;

use Carp;

use JSON;

our $SolarSystemDump;

sub _load_system {
	$SolarSystemDump and return;
	my $json = "$KSP::KSP_DIR/SolarSystemDump.json";
	# warn "_LOAD_BODIES $json\n";
	open JSON, "<:utf8", $json
		or die "can't open $json: $!";
	local $/ = undef;
	my $cnt = <JSON>;
	close JSON or die "can't close $json: $!";
	$SolarSystemDump = decode_json($cnt);
	bless $_, "KSP::Body" foreach values %{$SolarSystemDump->{bodies}};
}

sub secs_per_year($) {
	_load_system();
	$SolarSystemDump->{timeUnits}{Year}
}

sub secs_per_day($) {
	_load_system();
	$SolarSystemDump->{timeUnits}{Day}
}

sub bodies($) {
	wantarray or croak __PACKAGE__, "->all() wants list context";
	_load_system();
	values %{$SolarSystemDump->{bodies}}
}

sub body($$) {
	my ($pkg, $name) = @_;
	_load_system();
	my $ret = $SolarSystemDump->{bodies}{$name}
		or croak "can't find body \"$name\"";
	$ret
}

sub root($) {
	_load_system();
	__PACKAGE__->body($SolarSystemDump->{rootBody})
}

1;

