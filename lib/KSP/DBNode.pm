package KSP::DBNode;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;

use KSP::TinyStruct qw(name node +KSP::Cache);

use overload
	'""' => sub { $_[0]->desc };

sub BUILD {
	my ($self, $name, $node) = @_;
	UNIVERSAL::isa($node, "KSP::ConfigNode")
		or croak "KSP::ConfigNode required";
	$self->set_name($name);
	$self->set_node($node);
	$self->localize;
	$self
}

sub localize {
	my ($self, $loc) = @_;
	my $tab = KSP::DB->locTable($loc);
	$self->node->visit(sub {
		foreach ($_->values) {
			my $t = $_->value;
			my $lt = $tab->{$t};
			$_->set_value($lt) if defined $lt;
		}
	});
}

sub desc {
	my ($self) = @_;
	$self->node->asString(1)
}

1;

