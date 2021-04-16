package KSP;

use strict;
use warnings;

our $VERSION = '0.01';

our $KSP_DIR;
BEGIN {
	my $thisfile = __PACKAGE__ . ".pm";
	$KSP_DIR = $INC{$thisfile}
		or die __PACKAGE__ . ": can't find KSP.pm directory";
	$KSP_DIR =~ s/\.pm$//;
}

require Exporter;
our (@ISA, %EXPORT_TAGS, @EXPORT_OK, @EXPORT);
BEGIN {
	@ISA = qw(Exporter);
	%EXPORT_TAGS = ('all' => [ qw(U) ]);
	@EXPORT_OK = (@{$EXPORT_TAGS{'all'}});
	@EXPORT = qw();
}

use KSP::SolarSystem;
our @BODY_NAMES = ();
BEGIN {
	@BODY_NAMES = KSP::SolarSystem->body_names();
	$EXPORT_TAGS{bodies} = [ @BODY_NAMES ];
	push @EXPORT_OK, @BODY_NAMES;
	push @{$EXPORT_TAGS{all}}, @BODY_NAMES;
}
KSP::SolarSystem->import_bodies();

use KSP::Body;
use KSP::ConfigNode;
use KSP::Time;
use KSP::Orbit2D;
use KSP::Course;

sub U($;$) { goto &KSP::Orbit2D::U }

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
