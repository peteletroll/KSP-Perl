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

our $LOC;

sub locTable {
	unless ($LOC) {
		$LOC = { };
		foreach (root->find("Localization")) {
			my $n = $_->nodes or next;
			foreach (@$n) {
				my $loc = $_->name or next;
				my $v = $_->values or next;
				foreach (@$v) {
					$LOC->{$loc}->{$_->name} = $_->value;
				}
			}
		}
	}
	my $loc = $_[1] || "en-us";
	my $ret = $LOC->{$loc} || { };
	wantarray ? %$ret : $ret
}

1;

