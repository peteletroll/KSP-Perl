package KSP::Experiment;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::Util qw(matcher);

use namespace::clean;

use KSP::ConfigNode;
use KSP::DB;
use KSP::DBNode;

use KSP::TinyStruct qw(+KSP::DBNode);

our $EXP;
our @EXP = ();

our %SIT = (
	SrfLanded => 1,
	SrfSplashed => 2,
	FlyingLow => 4,
	FlyingHigh => 8,
	InSpaceLow => 16,
	InSpaceHigh => 32,
);

our @SIT = sort { $SIT{$a} <=> $SIT{$b} } keys %SIT;

sub _load() {
	$EXP and return $EXP;
	my %n = ();
	foreach my $n (KSP::DB->root->getnodes("EXPERIMENT_DEFINITION")) {
		my $id = $n->get("id");
		defined $id or next;
		my $prev = $n{$id};
		if ($prev) {
			$prev->node->gulp($n);
		} else {
			$n{$id} = __PACKAGE__->new($id, $n);
		}
	}

	@EXP = sort { $a->scienceCap <=> $b->scienceCap || $a->name cmp $b->name } values %n;
	$EXP = \@EXP;
}

sub title {
	my ($self) = @_;
	scalar $self->node->get("title");
}

sub situations {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::situations() wants list context";
	$self->cache("situations", sub {
		my $mask = $self->node->get("situationMask", 0);
		my @ret = ();
		foreach my $sit (@SIT) {
			push @ret, $sit if $mask & $SIT{$sit};
		}
		@ret
	});
}

sub bodySituations {
	my ($self, $body) = @_;
	wantarray or croak __PACKAGE__, "::bodySituations() wants list context";
	$self->cache("bodySituations:" . $body->name, sub {
		my $rb = $self->rocBodyName;
		return () if $rb && $rb ne $body->name;
		my $v = $body->scienceValues;
		grep { $v->{$_} } $self->situations
	})
}

sub biomeMatters {
	my ($self, $sit) = @_;
	defined $sit or croak "situation required";
	$self->cache("biomeMatters:$sit", sub {
		my $mask = $self->node->get("biomeMask", 0);
		!!($mask & $SIT{$sit})
	})
}

sub scienceCap {
	my ($self) = @_;
	$self->cache("scienceCap", sub {
		scalar $self->node->get("scienceCap") || 0
	})
}

sub desc {
	my ($self) = @_;
	scalar $self->cache("desc", sub {
		my $ret = $self->name . "[ ";
		$ret .= $self->title . "; ";
		$ret .= $self->scienceCap . "⚛";
		$ret .= " ]";
		$ret
	})
}

sub all {
	_load();
	wantarray ? @EXP : scalar @EXP
}

sub get {
	my $matcher = matcher($_[-1]);
	_load();
	my @ret = ();

	foreach my $p (@EXP) {
		$p->name =~ $matcher || ($p->title || "") =~ $matcher and push @ret, $p;
	}

	wantarray ? @ret : $ret[0]
}

sub rocBodyName {
	my ($self) = @_;
	$self->name =~ /^ROCScience_([A-Z][a-z]+)/ or return undef;
	$1
}

1;

