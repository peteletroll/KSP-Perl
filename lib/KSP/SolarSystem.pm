package KSP::SolarSystem;

use strict;
use warnings;

use KSP;
use KSP::Body;

use Carp;

use JSON;

use KSP::TinyStruct qw(json systemG);

sub BUILD {
	my ($self, $name) = @_;
	defined $name or $name = "SolarSystemDump";
	my $json = "$KSP::KSP_DIR/$name.json";
	open JSONDATA, "<:utf8", $json
		or die "can't open $json: $!";
	local $/ = undef;
	my $cnt = <JSONDATA>;
	close JSONDATA or die "can't close $json: $!";
	$self->set_json(decode_json($cnt));
	$self
}

sub secs_per_year {
	my ($self) = @_;
	$self->json->{timeUnits}{Year}
}

sub secs_per_day {
	my ($self) = @_;
	$self->json->{timeUnits}{Day}
}

sub G {
	my ($self) = @_;
	my $G = $self->systemG;
	unless ($G) {
		my ($sum, $count) = (0, 0);
		foreach my $b ($self->bodies) {
			my $G = $b->estimated_G;
			$G and $sum += $G, $count++;
		}
		$G = $count ? $sum / $count : 6.67408e-11;
		$self->set_systemG($G);
	}
	$G
}

sub bodies {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "->bodies() wants list context";
	sort { $a->_sortkey <=> $b->_sortkey } map { KSP::Body->new($_, $self) } values %{$self->json->{bodies}}
}

sub body($$) {
	my ($self, $name) = @_;
	ref $self or Carp::confess "no ref here";
	my $json = $self->json->{bodies}{$name}
		or die "can't find body \"$name\"";
	KSP::Body->new($json, $self)
}

sub root {
	my ($self) = @_;
	$self->body($self->json->{rootBody})
}

sub body_names {
	my ($self) = @_;
	ref $self eq __PACKAGE__ or Carp::confess __PACKAGE__, " needed here";
	wantarray or croak __PACKAGE__, "->body_names() wants list context";
	keys %{$self->json->{bodies}}
}

sub import_bodies {
	my ($self) = @_;
	my $tgt = (caller(0))[0];
	defined $tgt or return;
	# warn "BODIES INTO $tgt\n";
	my $ret = 0;
	foreach ($self->body_names()) {
		/^\w+$/ or die "bad name \"$_\"";
		my $name = $_;
		$ret++;
		no strict "refs";
		*{"${tgt}::${name}"} = sub { $self->body($name) };
	}
	$ret
}

1;

