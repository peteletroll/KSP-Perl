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
	$self->name . "[ " . U(1000 * $self->unitMass) . "g/u ]"
}

sub all {
	_load();
	wantarray ? @RES : scalar @RES
}

sub get {
	my $matcher = matcher($_[-1]);
	_load();
	my @ret = ();
	foreach my $p (@RES) {
		$p->name =~ $matcher and push @ret, $p;
	}
	wantarray ? @ret : $ret[0]
}

sub unitMass {
	my ($self) = @_;
	scalar $self->cache("unitMass", sub {
		1000 * (scalar($self->node->get("density")) || 0);
	});
}

1;

