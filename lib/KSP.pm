package KSP;

use strict;
use warnings;

our $VERSION = '0.01';

use Carp;
use Cwd;
use Memoize;

use KSP::Cache;
use KSP::Body;
use KSP::ConfigNode;
use KSP::Orbit2D;
use KSP::Course;
use KSP::DeltaVGraph;
use KSP::Part;
use KSP::Tech;
use KSP::Util qw(U);
use KSP::StopWatch qw(stopwatch);

our $KSP_DIR;
BEGIN {
	my $thisfile = __PACKAGE__ . ".pm";
	$thisfile =~ s/::/\//g;
	$KSP_DIR = $INC{$thisfile}
		or die __PACKAGE__ . ": can't find KSP.pm directory";
	$KSP_DIR =~ s/\.pm$//;
}

use Exporter qw(import);
our (%EXPORT_TAGS, @EXPORT_OK, @EXPORT);
BEGIN {
	%EXPORT_TAGS = ('all' => [ qw(U stopwatch) ]);
	@EXPORT_OK = (@{$EXPORT_TAGS{'all'}});
	@EXPORT = qw();
}

use KSP::SolarSystem;
our $SYSTEM;
our @BODY_NAMES = ();
BEGIN {
	$SYSTEM = KSP::SolarSystem->load();
	@BODY_NAMES = map { $_->name } $SYSTEM->bodies;
	$EXPORT_TAGS{bodies} = [ @BODY_NAMES ];
	push @EXPORT_OK, @BODY_NAMES;
	push @{$EXPORT_TAGS{all}}, @BODY_NAMES;
}
$SYSTEM->import_bodies();

sub HOME() {
	my $KSPHOME = $ENV{KSPHOME};
	defined $KSPHOME && $KSPHOME ne ""
		or croak "no \$KSPHOME environment variable";
	$KSPHOME = Cwd::realpath($KSPHOME);
	-d $KSPHOME or croak "$KSPHOME is not a directory";
	$KSPHOME
}
memoize("HOME");

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
