package KSP::Tech;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;
use KSP::DB;
use KSP::DBNode;
use KSP::Util qw(U matcher);

use KSP::TinyStruct qw(+KSP::DBNode);

our $TECH;
our @TECH = ();

sub _load() {
	$TECH and return $TECH;
	my %n = ();
	foreach my $t (KSP::DB->root->getnodes("TechTree")) {
		foreach my $n ($t->getnodes("RDNode")) {
			my $name = $n->get("id");
			defined $name or next;
			my $prev = $n{$name};
			if ($prev) {
				$prev->node->gulp($n);
			} else {
				$n{$name} = __PACKAGE__->new($name, $n);
			}
		}
	}

	@TECH = sort { $a->cost <=> $b->cost || $a->name cmp $b->name } values %n;
	$TECH = \@TECH;
}

sub title {
	my ($self) = @_;
	scalar $self->node->get("title");
}

sub cost {
	my ($self) = @_;
	scalar $self->node->get("cost") || 0;
}

sub desc {
	my ($self) = @_;
	scalar $self->cache("desc", sub {
		my $ret = $self->name . "[ ";
		$ret .= $self->cost . "\x{269b}";
		$ret .= " ]";
		$ret
	})
}

sub all {
	_load();
	wantarray ? @TECH : scalar @TECH

}

sub get {
	my $matcher = matcher($_[-1]);
	_load();
	my @ret = ();

	foreach my $p (@TECH) {
		$p->name =~ $matcher || ($p->title || "") =~ $matcher and push @ret, $p;
	}

	wantarray ? @ret : $ret[0]
}

sub parts {
	my ($self) = @_;
	$self->cache("parts", sub {
		grep { $_->tech == $self } KSP::Part->all
	})
}

sub parents {
	my ($self) = @_;
	$self->cache("parents", sub {
		map { __PACKAGE__->get($_->get("parentID")) } $self->node->getnodes("Parent")
	})
}

sub anyToUnlock {
	my ($self) = @_;
	($self->node->get("anyToUnlock") || "") =~ /true/i
}

1;

