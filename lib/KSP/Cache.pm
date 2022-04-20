package KSP::Cache;

use utf8;
use strict;
use warnings;

use KSP::TinyStruct qw(scalar_cache list_cache);

use Scalar::Util qw(refaddr);

use overload
	'==' => sub { refaddr($_[0]) == (refaddr($_[1]) || 0) },
	'!=' => sub { refaddr($_[0]) != (refaddr($_[1]) || 0) },
	'0+' => sub { refaddr($_[0]) || 0 };

sub cache {
	my ($self, $key, $sub) = @_;
	if (wantarray) {
		my $c = $self->list_cache || $self->set_list_cache({ });
		if (exists $c->{$key}) {
			return @{$c->{$key}};
		} else {
			if ($key =~ /!/) {
				my $ptr = sprintf "%x", 1 * $self;
				warn "GENERATE LIST [$ptr] $key\n";
			}
			return @{ $c->{$key} = [ $sub->() ] };
		}
	} else {
		my $c = $self->scalar_cache || $self->set_scalar_cache({ });
		if (exists $c->{$key}) {
			return $c->{$key};
		} else {
			if ($key =~ /!/) {
				my $ptr = sprintf "%x", 1 * $self;
				warn "GENERATE SCALAR [$ptr] $key\n";
			}
			return $c->{$key} = $sub->();
		}
	}
}

sub cached {
	my ($self) = @_;
	{
		LIST => $self->list_cache,
		SCALAR => $self->scalar_cache
	}
}

1;

