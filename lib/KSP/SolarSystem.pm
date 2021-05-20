package KSP::SolarSystem;

use strict;
use warnings;

use KSP;
use KSP::Body;

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
}

sub secs_per_year {
	_load_system();
	$SolarSystemDump->{timeUnits}{Year}
}

sub secs_per_day {
	_load_system();
	$SolarSystemDump->{timeUnits}{Day}
}

sub bodies {
	wantarray or croak __PACKAGE__, "->bodies() wants list context";
	_load_system();
	map { KSP::Body->new($_) } values %{$SolarSystemDump->{bodies}}
}

sub body($$) {
	my ($pkg, $name) = @_;
	_load_system();
	my $json = $SolarSystemDump->{bodies}{$name}
		or die "can't find body \"$name\"";
	KSP::Body->new($json);
}

sub root {
	_load_system();
	__PACKAGE__->body($SolarSystemDump->{rootBody})
}

sub body_names {
	_load_system();
	keys %{$SolarSystemDump->{bodies}}
}

sub import_bodies {
	my $tgt = (caller(0))[0];
	defined $tgt or return;
	# warn "BODIES INTO $tgt\n";
	my $ret = 0;
	foreach (body_names()) {
		/^\w+$/ or die "bad name \"$_\"";
		my $name = $_;
		$ret++;
		no strict "refs";
		*{"${tgt}::${name}"} = sub { KSP::SolarSystem->body($name) };
	}
	$ret
}

1;

