package KSP::DeltaVGraph;

use utf8;
use strict;
use warnings;

use Carp;

use KSP::TinyStruct qw(graph scale);

sub BUILD {
	my ($self, $rssflag) = @_;
	$self->set_graph({ });
	$self->set_scale(1);

	if ($rssflag) {
		# Sol System - http://i.imgur.com/AAGJvD1.png

		$self->add_path("Earth", "Earth/LO" => 9400, "Earth/HO" => 3210);
		$self->add_path("Earth/LO", "Earth/SO" => 3910);

		$self->add_path("Earth/LO", "Moon/SOI" => 3260, "Moon/LO" => 680, "Moon" => 1730);

		$self->add_path("Earth/HO", "Mercury/SOI" => 8650, "Mercury/LO" => 1220, "Mercury" => 3060);

		$self->add_path("Earth/HO", "Venus/SOI" => 640, "Venus/LO" => 2940, "Venus" => 27000);

		$self->add_path("Earth/HO", "Mars/SOI" => 1060, "Mars/LO" => 1440, "Mars" => 3800);
		$self->add_path("Mars/SOI", "Phobos/SOI" => 1280, "Phobos/LO" => 3, "Phobos" => 8);
		$self->add_path("Mars/SOI", "Deimos/SOI" => 990, "Deimos/LO" => 2, "Deimos" => 4);

		$self->add_path("Earth/HO", "Jupiter/SOI" => 3360, "Jupiter/LO" => 17200, "Jupiter" => 45000);
		$self->add_path("Jupiter/SOI", "Io/SOI" => 10320, "Io/LO" => 730, "Io" => 1850);
		$self->add_path("Jupiter/SOI", "Europa/SOI" => 8890, "Europa/LO" => 580, "Europa" => 1480);
		$self->add_path("Jupiter/SOI", "Ganymede/SOI" => 6700, "Ganymede/LO" => 790, "Ganymede" => 1970);
		$self->add_path("Jupiter/SOI", "Callisto/SOI" => 5140, "Callisto/LO" => 70, "Callisto" => 1760);

		$self->add_path("Earth/HO", "Saturn/SOI" => 4500, "Saturn/LO" => 10230, "Saturn" => 30000);
		$self->add_path("Saturn/SOI", "Titan/SOI" => 3060, "Titan/LO" => 660, "Titan" => 7600);

		$self->add_path("Earth/HO", "Uranus/SOI" => 5280, "Uranus/LO" => 6120, "Uranus" => 18000);

		$self->add_path("Earth/HO", "Neptune/SOI" => 5390, "Neptune/LO" => 6750, "Neptune" => 19000);
	} else {
		$self->add_path("Kerbin", "Kerbin/LO" => 3400, "Kerbin/HO" => 950);

		$self->add_path("Kerbin/LO", "Kerbin/SO" => 1115);

		$self->add_path("Kerbin/LO", "Mun/SOI" => 860, "Mun/LO" => 310, "Mun" => 580);

		$self->add_path("Kerbin/LO", "Minmus/INC" => 340, "Minmus/SOI" => 930, "Minmus/LO" => 160, "Minmus" => 180);

		$self->add_path("Kerbin/HO", "Kerbol/HO" => 6000, "Kerbol/LO" => 13700, "Kerbol" => 67000);

		$self->add_path("Kerbin/HO", "Moho/INC" => 2520, "Moho/SOI" => 760, "Moho/LO" => 2410, "Moho" => 870);

		$self->add_path("Kerbin/HO", "Eve/INC" => 430, "Eve/SOI" => 90, "Eve/HO" => 80, "Eve/LO" => 1330, "Eve" => 7200);
		$self->add_path("Eve/HO", "Gilly/SOI" => 60, "Gilly/LO" => 410, "Gilly" => 30);

		$self->add_path("Kerbin/HO", "Duna/INC" => 10, "Duna/SOI" => 130, "Duna/HO" => 250, "Duna/LO" => 360, "Duna" => 1450);
		$self->add_path("Duna/HO", "Ike/SOI" => 30, "Ike/LO" => 180, "Ike" => 390);

		$self->add_path("Kerbin/HO", "Dres/INC" => 1010, "Dres/SOI" => 610, "Dres/LO" => 1290, "Dres" => 430);

		$self->add_path("Kerbin/HO", "Jool/INC" => 270, "Jool/SOI" => 980, "Jool/HO" => 160, "Jool/LO" => 2810, "Jool" => 14000);
		$self->add_path("Jool/HO", "Laythe/SOI" => 930, "Laythe/LO" => 1070, "Laythe" => 2900);
		$self->add_path("Jool/HO", "Vall/SOI" => 620, "Vall/LO" => 910, "Vall" => 860);
		$self->add_path("Jool/HO", "Tylo/SOI" => 400, "Tylo/LO" => 1100, "Tylo" => 2270);
		$self->add_path("Jool/HO", "Bop/INC" => 2440, "Bop/SOI" => 220, "Bop/LO" => 900, "Bop" => 220);
		$self->add_path("Jool/HO", "Pol/INC" => 700, "Pol/SOI" => 160, "Pol/LO" => 820, "Pol" => 130);

		$self->add_path("Kerbin/HO", "Eeloo/INC" => 1330, "Eeloo/SOI" => 1140, "Eeloo/LO" => 1370, "Eeloo" => 620);
	}

	$self->fill_graph();

	$self
}

sub add_path($@) {
	my $self = shift;
	my $node = shift;
	my $graph = $self->graph;
	while (@_) {
		my $nextnode = shift;
		my $deltav = 0 + shift;
		exists $graph->{$node}{$nextnode} and $deltav > 1
			and die __PACKAGE__, ": internal: $node -> $nextnode already specified";
		$graph->{$node}{$nextnode} = $deltav;
		$node = $nextnode;
	}
}

sub add_aerobrake_path {
	my ($self, $node, @nodes) = @_;
	$self->add_path($node, map { ($_ => 1) } @nodes)
}

sub fill_graph() {
	my ($self) = @_;
	my $graph = $self->graph;
	foreach my $body1 (keys %$graph) {
		foreach my $body2 (keys %{$graph->{$body1}}) {
			exists $graph->{$body2}{$body1}
				or $graph->{$body2}{$body1} = $graph->{$body1}{$body2}
		}
	}
}

sub dijkstra_graph($) {
	my ($self, $from) = @_;
	my $graph = $self->graph;
	exists $graph->{$from} or die "$0: unknown node $from\n";
	my %dist = ($from => 0);
	my %prev = ();
	my %set = %$graph;
	while (scalar %set) {
		my @lst = grep { exists $dist{$_} } keys %set;
		@lst or last;
		my $min = pop @lst;
		while (my $n = pop @lst) {
			$dist{$min} <= $dist{$n} or $min = $n;
		}
		my $next = delete $set{$min};
		foreach my $n (keys %$next) {
			my $ndist = $dist{$min} + $next->{$n};
			if (!exists $dist{$n} || $dist{$n} > $ndist) {
				$dist{$n} = $ndist;
				$prev{$n} = $min;
			}
		}
	}

	+{ map { $_ => [ $dist{$_}, $prev{$_} ] } keys %dist }
}

sub path {
	my $self = shift;
	my $graph = $self->graph;
	my $scale = $self->scale;
	if (@_ >= 2) {
		my ($from, @to) = @_;
		my $carry = 0;
		while (@to) {
			my $to = shift @to;
			exists $graph->{$to} or die "$0: unknown node $to\n";
			my $res = dijkstra_graph($from);
			my $at = $to;
			my @path = ();
			while (my $prev = $res->{$at}[1]) {
				my $dist = $res->{$at}[0] - $res->{$prev}[0];
				push @path, sprintf "%7d %7d %12s \x{2192} %s", $dist, $res->{$at}[0] + $carry, $prev, $at;
				$at = $prev;
			}
			print "$_\n" foreach reverse @path;
			$from = $to;
			$carry += ($res->{$to}[0] || 0);
			# print "CARRY $carry\n";
		}
	} elsif (@_ == 1) {
		my ($from) = @_;
		my $res = dijkstra_graph($from);
		# print "dijkstra_graph($from) = ", dump($res), "\n";
		foreach my $to (sort { $res->{$a}[0] <=> $res->{$b}[0] } keys %$res) {
			printf "%7d %12s \x{2192} %s\n", $scale * $res->{$to}[0], $from, $to
				if defined $res->{$to}[1];
		}
	} elsif (@_ == 0) {
		print "$_\n" foreach sort keys %$graph;
	}
}

1;

