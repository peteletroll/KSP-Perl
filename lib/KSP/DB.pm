package KSP::DB;

use utf8;
use strict;
use warnings;

use Carp qw(croak cluck);

use File::Find;
use File::stat;
use Cwd;

use KSP::Util qw(U CACHE);
use KSP::StopWatch qw(stopwatch);

use KSP::ConfigNode;

use Memoize;
memoize("stat", NORMALIZER => sub { "$_[0]" });

sub files_key {
	join "\n",
		map {
			my $s = stat($_) or return ();
			join ":", "file", $_, $s->size, $s->mtime
		} @_;
}

sub files() {
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
	}, KSP::HOME());
	sort @lst
}
memoize("files", NORMALIZER => sub { "" });

sub mmcache {
	my $file = KSP::HOME() . "/GameData/ModuleManager.ConfigCache";
	my $s = stat($file) or return { };
	CACHE(files_key($file), "1 day", sub {
		my $time = stopwatch->start;
		my %ret = ();
		my $cfg = KSP::ConfigNode->load($file);
		$cfg->visit(sub { $_->set_src($file) });
		my @mm = $cfg->getnodes("UrlConfig");
		foreach my $mm (@mm) {
			my $f = $mm->get("parentUrl");
			$mm->del("parentUrl");
			$f =~ s/^\//..\//;
			$f = KSP::HOME() . "/GameData/$f";
			$f = Cwd::realpath($f) || $f;
			($ret{$f} ||= KSP::ConfigNode->new(__PACKAGE__ . "::MM"))
				->gulp($mm);
		}
		$time = $time->read;

		-t STDIN && -t STDOUT && -t STDERR and warn sprintf "# %s scanned %d file, %sB in %ss, %sB/s\n",
			__PACKAGE__,
			1, U($s->size),
			U($time), ($time ? U($s->size / $time) : "∞");

		\%ret
	})
}
memoize("mmcache", NORMALIZER => sub { "" });

sub root {
	my $use_mm = $ENV{KSP_NO_MM} ? "" : "MM:";
	my $files_key = $use_mm . files_key files;
	CACHE($files_key, "1 day", sub {
		my $mm = $use_mm ? mmcache() : { };

		my $time = stopwatch->start;
		my ($files, $bytes) = (0, 0);
		my $root = KSP::ConfigNode->new(__PACKAGE__);
		foreach (files()) {
			my $s = stat($_) or next;
			my $cfg = undef;
			if (exists $mm->{$_}) {
				# warn "MM OVERRIDES $_\n";
				$cfg = $mm->{$_};
			} else {
				$cfg = KSP::ConfigNode->load($_);
				my $src = $_;
				$cfg->visit(sub { $_->set_src($src) });
			}
			# warn "KEY $key\n";
			$root->gulp($cfg);
			$files++;
			$bytes += $s->size;
		}
		$time = $time->read;

		-t STDIN && -t STDOUT && -t STDERR and warn sprintf "# %s scanned %d files, %sB in %ss, %sB/s\n",
			__PACKAGE__,
			$files, U($bytes),
			U($time), ($time ? U($bytes / $time) : "∞");

		$root
	})
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

