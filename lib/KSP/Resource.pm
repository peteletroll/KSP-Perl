package KSP::Resource;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;
use KSP::DB;
use KSP::BoxedNode;
use KSP::Util qw(U);

use KSP::TinyStruct qw(+KSP::BoxedNode);

our $RES;
our @RES = ();

sub _load() {
	$RES and return $RES;

	foreach my $n (KSP::DB->root->find("RESOURCE_DEFINITION")) {
		my $name = $n->get("name");
		defined $name or next;
		push @RES, __PACKAGE__->new($name, $n);
	}

	@RES = sort { $a->unitMass <=> $b->unitMass } @RES;
	$RES = \@RES;
}

sub desc {
	my ($self) = @_;
	$self->name . "[" . U(1000 * $self->unitMass) . "g/unit]"
}

sub all {
	wantarray or croak __PACKAGE__ . "::all() wants list context";
	_load();
	@RES

}

sub get {
	my $matcher = $_[-1];
	_load();
	ref $matcher eq "Regexp" or $matcher = qr/^\Q$matcher\E$/;
	my @ret = ();
	foreach my $p (@RES) {
		$p->name =~ $matcher and push @ret, $p;
	}
	wantarray ? @ret : $ret[0]
}

sub unitMass {
	my ($self) = @_;
	scalar $self->cache("unitMass", sub {
		1000 * (scalar $self->node->get("density") || 0);
	});
}

1;

