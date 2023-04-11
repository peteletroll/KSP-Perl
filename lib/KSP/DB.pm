package KSP::DB;

use utf8;
use strict;
use warnings;

use Carp qw(croak cluck);

use File::Find;
use File::Spec;
use Cwd;

use KSP::Util qw(U);
use KSP::StopWatch qw(stopwatch);

use KSP::ConfigNode;

our $DB;

sub root {
	$DB and return $DB;

	# cluck "loading " . __PACKAGE__;

	my $KSPHOME = $ENV{KSPHOME};
	defined $KSPHOME or croak "no \$KSPHOME environment variable";
	$KSPHOME = Cwd::realpath($KSPHOME);
	$KSPHOME =~ s{(\/*|\/+\.)$}{/.};
	-d $KSPHOME or croak "$KSPHOME is not a directory";

	my $bytes = 0;
	my $stopwatch = stopwatch->start;

	my $db = KSP::ConfigNode->new(__PACKAGE__);
	find({
		no_chdir => 0,
		follow => 0,
		wanted => sub {
			-d $_ && $_ eq "zDeprecated" and $File::Find::prune = 1;
			-f $_ && (/\.cfg$/i)
				or return;
			$bytes += -s $_;
			my $cfg = KSP::ConfigNode->load($_);
			my $src = File::Spec->abs2rel($_, $KSPHOME);
			$cfg->visit(sub { $_->set_src($src) });
			$db->gulp($cfg);
		}
	}, "$KSPHOME/.");

	my $time = $stopwatch->stop->read;
	-t STDIN && -t STDOUT && -t STDERR and warn sprintf "# %s loaded %sB in %ss, %sB/s\n",
		__PACKAGE__,
		U($bytes),
		U($time),
		($time ? U($bytes / $time) : "∞");

	$DB = $db
}

our $LOC;

sub locTable {
	unless ($LOC) {
		$LOC = { };
		foreach (root->getnodes("Localization")) {
			foreach ($_->nodes) {
				my $loc = $_->name or next;
				foreach ($_->values) {
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

