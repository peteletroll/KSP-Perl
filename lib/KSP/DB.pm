package KSP::DB;

use utf8;
use strict;
use warnings;

use Carp;

use File::Find;

use KSP::ConfigNode;

our $DB;

sub root {
	$DB and return $DB;

	my $KSPHOME = $ENV{KSPHOME};
	defined $KSPHOME or croak "no \$KSPHOME environment variable";
	-d $KSPHOME or croak "$KSPHOME is not a directory";

	my $db = KSP::ConfigNode->new(__PACKAGE__);
	find({
		no_chdir => 1,
		follow => 1,
		wanted => sub {
			-d $_ && /\/zDeprecated\/?$/ and $File::Find::prune = 1;
			-f $_ && (/\.cfg$/i)
				or return;
			my $cfg = KSP::ConfigNode->load($_);
			$db->gulp($cfg);
		}
	}, $KSPHOME);

	$DB = $db
}

1;

