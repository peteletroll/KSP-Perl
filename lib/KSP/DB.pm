package KSP::DB;

use utf8;
use strict;
use warnings;

use Carp qw(croak cluck);

use File::Find;
use File::Spec;
use File::stat;
use Cwd;

use KSP::Util qw(U CACHE);
use KSP::StopWatch qw(stopwatch);

use KSP::ConfigNode;

use Memoize;
memoize("stat", NORMALIZER => sub { "$_[0]" });

sub files() {
	my $KSPHOME = $ENV{KSPHOME};
	defined $KSPHOME or croak "no \$KSPHOME environment variable";
	$KSPHOME = Cwd::realpath($KSPHOME);
	-d $KSPHOME or croak "$KSPHOME is not a directory";
	my @lst = ();
	find({
		no_chdir => 0,
		follow => 0,
		wanted => sub {
			my $s = stat($_) or return;
			-d $s && $_ eq "zDeprecated" and $File::Find::prune = 1;
			-f $s && (/\.cfg$/i)
				or return;
			push @lst, $File::Find::name;
		}
	}, $KSPHOME);
	sort @lst
}
memoize("files", NORMALIZER => sub { "" });

sub root {
	# cluck "loading " . __PACKAGE__;

	my $bytes = 0;
	my $stopwatch = stopwatch->start;

	my $root = KSP::ConfigNode->new(__PACKAGE__);
	foreach (files()) {
		my $s = stat($_) or return;
		$bytes += -s $s;
		my $key = join ":", "file",
			File::Spec->canonpath($_),
			$s->size, $s->mtime;
		# warn "KEY $key\n";
		my $cfg = CACHE($key, "1 hour", sub {
			my $cfg = KSP::ConfigNode->load($_);
			my $src = $_;
			$cfg->visit(sub { $_->set_src($src) });
			$cfg
		});
		$root->gulp($cfg);
	}

	my $time = $stopwatch->stop->read;
	-t STDIN && -t STDOUT && -t STDERR and warn sprintf "# %s loaded %sB in %ss, %sB/s\n",
		__PACKAGE__,
		U($bytes),
		U($time),
		($time ? U($bytes / $time) : "∞");

	$root
}
memoize("root", NORMALIZER => sub { "" });

sub fullLocTable() {
	my $ret = { };
	foreach (root->getnodes("Localization")) {
		foreach ($_->nodes) {
			my $loc = $_->name or next;
			$ret->{$loc}->{$_->name} = $_->value foreach $_->values;
		}
	}
	$ret
}
memoize("fullLocTable", NORMALIZER => sub { "" });

sub locTable {
	my $loc = $_[1] || "en-us";
	my $ret = fullLocTable->{$loc} || { };
	wantarray ? %$ret : $ret
}

1;

