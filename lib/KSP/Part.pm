package KSP::Part;

use utf8;
use strict;
use warnings;

use Carp;

use File::Find ();

use KSP::ConfigNode;
use KSP::DB;
use KSP::Util qw(U);

use KSP::TinyStruct qw(name node +KSP::Cache);

use overload
	fallback => 1,
	'==' => sub { $_[0]->name eq ($_[1] ? $_[1]->name : "") },
	'!=' => sub { $_[0]->name ne ($_[1] ? $_[1]->name : "") },
	'""' => \&desc;

sub BUILD {
	my ($self, $name, $node) = @_;
	$self->set_name($name);
	$self->set_node($node);
	$self
}

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
	$self->name . "[" . U(1000 * $self->dryMass) . "g]"
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

sub resources {
	my ($self) = @_;
	wantarray or croak __PACKAGE__ . "::resources() wants list context";
	$self->cache("resources", sub {
		sort map { $_->get("name") } $self->node->find("RESOURCE");
	})
}

sub resource {
	my ($self, $resource) = @_;
	my $res = $self->node->find("RESOURCE", name => $resource);
	$res ? $res->get("maxAmount") : 0
}

1;

