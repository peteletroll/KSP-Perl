package KSP::Part;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;
use KSP::DB;
use KSP::DBNode;
use KSP::Resource;
use KSP::Util qw(U);

use KSP::TinyStruct qw(+KSP::DBNode);

our $PART;
our @PART = ();

sub _load() {
	$PART and return $PART;

	my %n = ();
	foreach my $n (KSP::DB->root->find("PART")) {
		my $name = $n->get("name");
		defined $name or next;
		my $prev = $n{$name};
		if ($prev) {
			$prev->node->gulp($n);
		} else {
			$n{$name} = __PACKAGE__->new($name, $n);
		}
	}

	@PART = sort { $a->dryMass <=> $b->dryMass || $a->name cmp $b->name } values %n;
	$PART = \@PART;
}

sub desc {
	my ($self) = @_;
	scalar $self->cache("desc", sub {
		my $wm = $self->wetMass;
		my $dm = $self->dryMass;
		my $ret = $self->name . "[";
		$ret .= U(1000 * $wm) . "g / " if $wm > $dm;
		$ret .= U(1000 * $dm) . "g]";
		$ret
	})
}

sub all {
	wantarray or croak __PACKAGE__ . "::all() wants list context";
	_load();
	@PART

}

sub get {
	my $matcher = $_[-1];
	_load();
	ref $matcher eq "Regexp" or $matcher = qr/^\Q$matcher\E$/;
	my @ret = ();

	foreach my $p (@PART) {
		$p->name =~ $matcher and push @ret, $p;
	}

	wantarray ? @ret : $ret[0]
}

sub dryMass {
	my ($self) = @_;
	scalar $self->cache("dryMass", sub {
		1000 * ($self->node->get("mass") || 0)
	});
}

sub modules {
	my ($self) = @_;
	wantarray or croak __PACKAGE__ . "::modules() wants list context";
	$self->cache("resource", sub {
		sort map { $_->get("name") } $self->node->find("MODULE");
	})
}

sub resources {
	my ($self) = @_;
	wantarray or croak __PACKAGE__ . "::resources() wants list context";
	$self->cache("resources", sub {
		sort map { $_->get("name") } $self->node->find("RESOURCE");
	})
}

sub resourceMass {
	my ($self, $resource) = @_;
	my $res = $self->node->find("RESOURCE", name => $resource);
	my $amount = $res ? $res->get("maxAmount") || 0 : 0;
	$amount * KSP::Resource->get($resource)->unitMass
}

sub wetMass {
	my ($self) = @_;
	my $ret = $self->dryMass;
	foreach ($self->resources) {
		$ret += $self->resourceMass($_);
	}
	$ret
}

1;

