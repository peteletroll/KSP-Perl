package KSP::ExperimentId;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::Util qw(getprefix);

use namespace::clean;

use KSP::SolarSystem;
use KSP::Cache;
use KSP::TinyStruct qw(id system +KSP::Cache);

sub BUILD {
	my ($self, $id, $system) = @_;
	$system ||= KSP::SolarSystem->load();
	$self->set_id($id);
	$self->set_system($system);
	$self
}

use overload
	'""' => sub { $_[0]->desc };

sub parsed {
	my ($self) = @_;
	$self->cache("parsed", sub {
		my $tmp = $self->id;
		my $system = $self->system;

		my $type = $tmp =~ s/^(.*?)@// ? $1 : undef;
		(my $body, $tmp) = getprefix($tmp, $system->bodyPrefixMatchers);
		(my $situation, $tmp) = getprefix($tmp, $system->situationPrefixMatchers);
		(my $biome, $tmp) = getprefix($tmp, $system->body($body)->biomePrefixMatchers);

		my $expname = $type;

		if ($tmp) {
			if ($biome && $tmp !~ /^_/) {
				$biome .= $tmp;
				$tmp = "";
			} elsif ($tmp =~ /^_/) {
				$expname .= $tmp;
				$tmp = "";
			}
		}

		my %ret = (
			type => $type,
			name => $expname,
			body => $body,
		);
		$ret{situation} = $situation if $situation;
		$ret{biome} = $biome if $biome;
		$ret{rest} = $tmp if $tmp;
		\%ret;
	})
}

sub experiment {
	my ($self) = @_;
	$self->cache("experiment", sub { KSP::Experiment->get($self->parsed->{type}) })
}

sub body {
	my ($self) = @_;
	$self->cache("body", sub {
		my $body = $self->parsed->{body};
		$body ? $self->system->body($body) : undef
	})

}

sub situation {
	my ($self) = @_;
	$self->parsed->{situation};
}

sub biome {
	my ($self) = @_;
	$self->parsed->{biome};
}

sub desc {
	my ($self) = @_;
	$self->cache("desc", sub { __PACKAGE__ . "[ " . $self->id . " ]" })
}

1;

