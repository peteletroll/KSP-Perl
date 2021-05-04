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

sub secs_per_year {
	_load_system();
	$SolarSystemDump->{timeUnits}{Year}
}

sub secs_per_day {
	_load_system();
	$SolarSystemDump->{timeUnits}{Day}
}

sub bodies {
	wantarray or croak __PACKAGE__, "->all() wants list context";
	_load_system();
	values %{$SolarSystemDump->{bodies}}
}

sub body($$) {
	my ($pkg, $name) = @_;
	_load_system();
	my $ret = $SolarSystemDump->{bodies}{$name}
		or die "can't find body \"$name\"";
	$ret
}

sub root {
	_load_system();
	__PACKAGE__->body($SolarSystemDump->{rootBody})
}

sub body_names {
	map { $_->{name} } bodies()
}

sub import_bodies {
	my $tgt = (caller(0))[0];
	defined $tgt or return;
	# warn "BODIES INTO $tgt\n";
	foreach (body_names()) {
		/^\w+$/ or die "bad name \"$_\"";
		my $name = $_;
		no strict "refs";
		*{"${tgt}::${name}"} = sub { KSP::SolarSystem->body($name) };
	}
}

1;

