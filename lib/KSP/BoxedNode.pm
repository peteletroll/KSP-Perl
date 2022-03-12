package KSP::BoxedNode;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::ConfigNode;

use KSP::TinyStruct qw(name node +KSP::Cache);

use overload
	fallback => 1,
	'==' => sub { $_[0]->name eq ($_[1] ? $_[1]->name : "") },
	'!=' => sub { $_[0]->name ne ($_[1] ? $_[1]->name : "") },
	'""' => "desc";

sub BUILD {
	my ($self, $name, $node) = @_;
	$self->set_name($name);
	$self->set_node($node);
	$self
}

sub desc {
	my ($self) = @_;
	$self->node->asString(1)
}

1;

