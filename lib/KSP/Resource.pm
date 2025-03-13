package KSP::Resource;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;
use KSP::DB;
use KSP::DBNode;
use KSP::Util qw(U matcher);

use KSP::TinyStruct qw(+KSP::DBNode);

our $RES;
our @RES = ();

sub _load() {
	$RES and return $RES;

	foreach my $n (KSP::DB->root->getnodes("RESOURCE_DEFINITION")) {
		my $name = $n->get("name");
		defined $name or next;
		push @RES, __PACKAGE__->new($name, $n);
	}

	@RES = sort { $a->unitMass <=> $b->unitMass } @RES;
	$RES = \@RES;
}

sub desc {
	my ($self) = @_;
	$self->name . "[ " . U(1000 * $self->unitMass) . "g/u; " . $self->flowMode . " ]"
}

sub all {
	_load();
	wantarray ? @RES : scalar @RES
}

sub get {
	my $matcher = matcher($_[-1]);
	defined $matcher or confess "undefined matcher";
	_load();
	my @ret = ();
	foreach my $p (@RES) {
		$p->name =~ $matcher and push @ret, $p;
	}
	wantarray ? @ret : $ret[0]
}

sub flowMode {
	my ($self) = @_;
	$self->node->get("flowMode", "UNK")
}

sub unitMass {
	my ($self) = @_;
	scalar $self->cache("unitMass", sub {
		1000 * $self->node->get("density", 0)
	});
}

sub _resfilter($$) {
	my ($self, $class) = @_;
	$self->cache("resfilter-$class", sub {
		grep {
			my $r = $_->resourceInfo($class);
			$r and scalar grep { $_->{resource} == $self } @$r
		} KSP::Part->all
	})
}

sub producers {
	my ($self) = @_;
	$self->_resfilter("PRODUCE")
}

sub containers {
	my ($self) = @_;
	$self->_resfilter("STORE")
}

sub consumers {
	my ($self) = @_;
	$self->_resfilter("CONSUME")
}

1;

