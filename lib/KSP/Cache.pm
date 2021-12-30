package KSP::Cache;

use utf8;
use strict;
use warnings;

use KSP::TinyStruct qw(scalar_cache list_cache);

use overload
	'0+' => sub {
		my ($self) = @_;
		my $ref = ref $self;
		bless $self, "ARRAY";
		my $ret = 0 + $self;
		bless $self, $ref;
		$ret
	};

sub cache {
	my ($self, $key, $sub) = @_;
	if (wantarray) {
		my $c = $self->list_cache || $self->set_list_cache({ });
		if (exists $c->{$key}) {
			return @{$c->{$key}};
		} else {
			$key =~ /!/ and warn "GENERATE LIST $key\n";
			return @{ $c->{$key} = [ $sub->() ] };
		}
	} else {
		my $c = $self->scalar_cache || $self->set_scalar_cache({ });
		if (exists $c->{$key}) {
			return $c->{$key};
		} else {
			$key =~ /!/ and warn "GENERATE SCALAR $key\n";
			return $c->{$key} = $sub->();
		}
	}
}

1;

