package KSP::SolarSystem;

use strict;
use warnings;

use KSP;
use KSP::Body;

use Carp;

use JSON;

use KSP::TinyStruct qw(json);

our $SolarSystemDump;

sub BUILD {
	my ($self, $name) = @_;

	my $json = "$KSP::KSP_DIR/$name.json";
	open JSONDATA, "<:utf8", $json
		or die "can't open $json: $!";
	local $/ = undef;
	my $cnt = <JSONDATA>;
	close JSONDATA or die "can't close $json: $!";
	$self->set_json(decode_json($cnt));
	$self
}

sub _load_system {
	$SolarSystemDump ||= KSP::SolarSystem->new("SolarSystemDump");
}

sub secs_per_year {
	_load_system();
	$SolarSystemDump->json->{timeUnits}{Year}
}

sub secs_per_day {
	_load_system();
	$SolarSystemDump->json->{timeUnits}{Day}
}

sub bodies {
	wantarray or croak __PACKAGE__, "->bodies() wants list context";
	_load_system();
	map { KSP::Body->new($_, $SolarSystemDump) } values %{$SolarSystemDump->json->{bodies}}
}

sub body($$) {
	my ($pkg, $name) = @_;
	_load_system();
	my $json = $SolarSystemDump->json->{bodies}{$name}
		or die "can't find body \"$name\"";
	KSP::Body->new($json, $SolarSystemDump);
}

sub root {
	_load_system();
	__PACKAGE__->body($SolarSystemDump->json->{rootBody})
}

sub body_names {
	wantarray or croak __PACKAGE__, "->body_names() wants list context";
	_load_system();
	keys %{$SolarSystemDump->json->{bodies}}
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

