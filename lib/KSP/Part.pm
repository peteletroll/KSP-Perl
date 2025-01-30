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
use Math::Vector::Real;

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

sub crashTolerance {
	my ($self) = @_;
	scalar $self->cache("crashTolerance", sub {
		$self->node->get("crashTolerance", 9)
	});

}

our @ATTACH = qw(stack SrfAttach allowStack allowSrfAttach allowCollision);
sub attach {
	my ($self) = @_;
	scalar $self->cache("attach", sub {
		my $rules = $self->node->get("attachRules", "");
		$rules =~ s/\s+//g;
		my @f = split /,/, $rules;
		my %a = ();
		foreach my $i (0..$#ATTACH) {
			my $a = $ATTACH[$i];
			$a{$a} = $f[$i] ? 1 : 0;
		}
		\%a
	})
}

sub nodes {
	my ($self) = @_;
	scalar $self->cache("nodes", sub {
		my %n = ();
		foreach my $n ($self->node->values) {
			$n->name =~ /^node_(.+)$/ or next;
			my $name = $1;
			my @v = map { 0 + $_ } split /\s*,\s*/, $n->value;
			@v == 6 and push @v, 1;
			if (@v < 7) {
				warn "bad node $name in $self ", scalar(@v), "\n";
				next;
			}
			exists $n{$name} and warn "repeated node $name in $self\n";
			$n{$name} = {
				size => $v[6],
				pos => V(@v[0..2]),
				dir => V(@v[3..5]),
				(@v > 7 ? (x => [ @v[7..$#v] ]) : ()),
			};
		}
		\%n
	})
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
		map { KSP::DBNode->new($_->get("name"), $_) }
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

our %producerModule = map { ($_ => 1) } qw(
	ModuleAlternator
);

our %resourceInfoTable = (
	PROPELLANT => sub {
		+{
			class => "CONSUME",
			resource => scalar KSP::Resource->get(scalar $_->get("name")),
			ratio => scalar $_->get("ratio"),
		}
	},
	RESOURCE => sub {
		if ((my $a = $_->get("maxAmount", 0)) > 0) {
			+{
				class => "STORE",
				resource => scalar KSP::Resource->get(scalar $_->get("name")),
				units => $a,
			};
		} elsif ((my $r = $_->get("rate", 0)) > 0) {
			my $module = $_->parent;
			my $producer = $module && $module->name eq "MODULE" && $producerModule{$module->get("name")};
			+{
				class => ($producer ? "PRODUCE" : "CONSUME"),
				resource => scalar KSP::Resource->get(scalar $_->get("name")),
				units => $r,
			};
		}
	},
	INPUT_RESOURCE => sub {
		+{
			class => "CONSUME",
			resource => scalar KSP::Resource->get(scalar $_->get("ResourceName")),
			ratio => scalar $_->get("Ratio"),
		}
	},
	OUTPUT_RESOURCE => sub {
		+{
			class => "PRODUCE",
			resource => scalar KSP::Resource->get(scalar $_->get("ResourceName") || scalar $_->get("name")),
			ratio => scalar $_->get("Ratio"),
			rate => scalar $_->get("rate"),
		}
	},
	RESOURCE_PROCESS => sub {
		+{
			class => "CONSUME",
			resource => scalar KSP::Resource->get(scalar $_->get("name")),
			amount => scalar $_->get("amount"),
		}
	},
	MODULE => sub {
		my $partnode = $_->parent;
		$partnode && $partnode->name eq "PART" or return undef;
		my $name = $_->get("name", "");
		if ($name eq "ModuleDeployableSolarPanel") {
			+{
				class => "PRODUCE",
				resource => scalar KSP::Resource->get(scalar $_->get("resourceName")),
				units => scalar $_->get("chargeRate", 0),
			}
		} elsif ($name eq "ModuleResourceIntake") {
			+{
				class => "PRODUCE",
				resource => scalar KSP::Resource->get(scalar $_->get("resourceName")),
			}
		} elsif ($name =~ /^Module\w+(Drill|Harvester)$/) {
			+{
				class => "PRODUCE",
				resource => scalar KSP::Resource->get("Ore"),
			}
		} elsif ($name =~ /^ModuleRCS/ && !$_->getnodes("PROPELLANT")) {
			+{
				class => "CONSUME",
				resource => scalar KSP::Resource->get($_->get("resourceName", "MonoPropellant")),
				ratio => 1,
			}
		}
	},
);

sub resourceInfo {
	my ($self, @class) = @_;
	if (@class) {
		my %class = map { ($_ => 1) } @class;
		return [ grep { $class{$_->{class}} } @{$self->resourceInfo} ];
	}
	scalar $self->cache("resourceInfo", sub {
		my @ret = ();
		# warn "resourceInfo(", scalar($self->name), ")\n";
		foreach my $ri ($self->node->find(qr/./)) {
			my $n = $ri->name;
			my $h = undef;
			if (my $c = $resourceInfoTable{$n}) {
				# warn scalar($self->name), " resource from $n\n";
				local $_ = $ri;
				$h = $c->();
				if ($h) {
					foreach (keys %$h) {
						defined $h->{$_} or delete $h->{$_};
					}
					# $h->{z_node} = $ri;
				}
			}
			$h or next;
			$h->{mass} = $h->{units} * $h->{resource}->unitMass
				if $h->{class} eq "STORE";
			push @ret, $h;
		}
		\@ret
	})
}

sub wetMass {
	my ($self) = @_;
	scalar $self->cache("wetMass", sub {
		my $ret = $self->dryMass;
		foreach (@{$self->resourceInfo("STORE")}) {
			$ret += $_->{mass};
		}
		$ret
	})
}

sub massRatio {
	my ($self) = @_;
	$self->dryMass ? $self->wetMass / $self->dryMass : 1
}

sub maxTemp {
	my ($self) = @_;
	scalar $self->cache("maxTemp", sub {
		$self->node->get("maxTemp", 2000)
	});
}

sub images {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::images() wants list context";
	my $name = $self->name;
	my $images = KSP::DB::part_images()->{$name};
	$images ? @$images : ()
}

1;

