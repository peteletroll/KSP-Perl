package KSP::Part;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;
use KSP::DB;
use KSP::DBNode;
use KSP::Engine;
use KSP::Antenna;
use KSP::Resource;
use KSP::Tech;
use KSP::Util qw(U matcher);

use KSP::TinyStruct qw(+KSP::DBNode);

our $PART;
our @PART = ();

sub _load() {
	$PART and return $PART;

	my %n = ();
	foreach my $n (KSP::DB->root->getnodes("PART")) {
		$n->get("TechHidden", "") =~ /true/i and next;
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
		my $crew = $self->crew;
		my $ret = $self->name . "[ ";
		my $t = $self->title;
		$ret .= "$t; " if defined $t;
		$ret .= "$crew☺; " if $crew;
		$ret .= U(1000 * $wm) . "g / " if $wm > $dm;
		$ret .= U(1000 * $dm) . "g ]";
		$ret
	})
}

sub all {
	_load();
	wantarray ? @PART : scalar @PART

}

sub get {
	my $matcher = matcher($_[-1]);
	_load();
	my @ret = ();

	foreach my $p (@PART) {
		$p->name =~ $matcher || ($p->title || "") =~ $matcher and push @ret, $p;
	}

	wantarray ? @ret : $ret[0]
}

sub title {
	my ($self) = @_;
	scalar $self->node->get("title");
}

sub category {
	my ($self) = @_;
	scalar $self->node->get("category", "none");
}

sub tech {
	my ($self) = @_;
	my $n = $self->node->get("TechRequired") or return undef;
	KSP::Tech->get($n)
}

sub dryMass {
	my ($self) = @_;
	scalar $self->cache("dryMass", sub {
		1000 * $self->node->get("mass", 0)
	});
}

sub crew {
	my ($self) = @_;
	scalar $self->cache("crew", sub {
		int $self->node->get("CrewCapacity", 0)
	});
}

sub modules {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::modules() wants list context";
	$self->cache("modules", sub {
		sort map { $_->get("name") } $self->node->getnodes("MODULE");
	})
}

sub module {
	my ($self, $name) = @_;
	my @ret =
		map { KSP::DBNode->new($name, $_) }
		$self->node->getnodes("MODULE", name => $name);
	wantarray ? @ret : $ret[0]
}

sub engine {
	my ($self, $name) = @_;
	$name = matcher($name);
	my @ret = grep { !defined($name) || $_->id =~ $name }
		$self->allEngines;
	wantarray ? @ret : $ret[0]
}

sub engines {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::engines() wants list context";
	map { $_->id } $self->allEngines
}

sub allEngines {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::allEngines() wants list context";
	$self->cache("allEngines", sub {
		sort { $b->maxThrust <=> $a->maxThrust }
		map { KSP::Engine->new($self->name, $_) }
		$self->node->getnodes("MODULE", name => qr/^(?:ModuleEngines|ModuleRCS)(?:FX)?$/)
	})
}

sub antenna {
	my ($self) = @_;
	KSP::Antenna->new($self)
}

our $RNODE = qr/^(?:RESOURCE|RESOURCE_PROCESS|PROPELLANT)$/;

sub resources {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::resources() wants list context";
	$self->cache("resources", sub {
		my %r = ();
		sort map {
			my $name = $_->get("name");
			$r{$name}++ ? () : ($name)
		} $self->node->find($RNODE);
	})
}

sub resource {
	my ($self, $name) = @_;
	my @ret =
		map { KSP::DBNode->new($name, $_) }
		$self->node->find($RNODE, name => $name);
	wantarray ? @ret : $ret[0]
}

sub resourceAmount {
	my ($self, $resource) = @_;
	ref $resource and croak "no reference allowed for resourceAmount()";
	my $amount = 0;
	foreach ($self->node->getnodes($RNODE, name => $resource)) {
		$amount += $_->get("maxAmount", 0)
	}
	$amount
}

sub resourceMass {
	my ($self, $resource) = @_;
	ref $resource and croak "no reference allowed for resourceMass()";
	$self->resourceAmount($resource) * KSP::Resource->get($resource)->unitMass
}

sub wetMass {
	my ($self) = @_;
	scalar $self->cache("wetMass", sub {
		my $ret = $self->dryMass;
		foreach ($self->resources) {
			$ret += $self->resourceMass($_);
		}
		$ret
	})
}

sub massRatio {
	my ($self) = @_;
	$self->dryMass ? $self->wetMass / $self->dryMass : 1
}

1;

