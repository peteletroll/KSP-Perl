package KSP;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ('all' => [ qw(U BODY ORBIT) ]);
our @EXPORT_OK = (@{$EXPORT_TAGS{'all'}});
our @EXPORT = qw();

our $VERSION = '0.01';

our $KSP_DIR;
BEGIN {
	my $thisfile = __PACKAGE__ . ".pm";
	$KSP_DIR = $INC{$thisfile}
		or die __PACKAGE__ . ": can't find KSP.pm directory";
	$KSP_DIR =~ s/\.pm$//;
}

use KSP::Body;
use KSP::ConfigNode;
use KSP::Time;
use KSP::Orbit2D;

sub U($;$) { goto &KSP::Orbit2D::U }

sub BODY($) { KSP::Body->get($_[0]) }

sub ORBIT($) { KSP::Orbit2D->new(@_) }

1;

__END__

=head1 NAME

KSP - Kerbal Space Program Utilities

=head1 SYNOPSIS

  use KSP;

=head1 DESCRIPTION

KSP related utilities

=head2 EXPORT

None by default.

=head1 SEE ALSO

=head1 AUTHOR

Pietro Cagnoni, E<lt>pietro.cagnoni@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Pietro Cagnoni

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.28.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
