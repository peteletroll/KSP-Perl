package KSP::Course;

use utf8;
use strict;
use warnings;

use Carp;

use KSP qw(U);

use overload
	'""' => \&desc;

sub new {
	my ($pkg, $start) = @_;
	my $new = bless [ ], $pkg;
	$new->_add(do => "start", then => $start)
}

sub current { $_[0]->_cur->{then} }

sub goTo {
	my ($self, $dst) = @_;
	my $cur = $self->current();
	# warn "CUR $cur\n";
	$dst = _asorbit($dst, 1);
	if ($cur->body == $dst->body) {
		# warn "SAME BODY\n";
		$self->_go_samebody($cur, $dst);
	} else {
		croak "can't go from $cur to $dst";
	}
	$self
}

sub desc {
	my ($self) = @_;
	my @d = ();
	my $dv = 0;
	foreach (@$self) {
		my $d = $_->{do};
		my $p = "at";
		$_->{dv} and $d .= " " . U($_->{dv}) . "m/s", $p = "to", $dv += abs($_->{dv});
		$_->{h} and $d .= " at " . U($_->{h}) . "m";
		$d .= " $p " . $_->{then};
		push @d, $d;
	}
	push @d, "total Δv " . U($dv) . "m/s";
	join "\n", @d
}

sub _go_samebody {
	my ($self, $cur, $dst) = @_;
	$self->_go_ap($self->current, $dst->ap);
	$self->_go_pe($self->current, $dst->pe);
}

sub _go_ap {
	my ($self, $cur, $ap) = @_;
	my $swap = $ap < $cur->pe ? 1 : 0;
	my $dst = $swap ?
		$cur->body->orbit(pe => $cur->pe, ap => $ap) :
		$cur->body->orbit(pe => $cur->pe, ap => $ap);
	my $h = $cur->pe;
	my $dv = $dst->v_from_vis_viva($h) - $cur->v_from_vis_viva($h);
	warn "BURNPE $swap ", U($dv), "m/s AT ", U($h), "m TO $dst\n";
	$dv and $self->_add(do => "burn", dv => $dv, h => $h, then => $dst);
}

sub _go_pe {
	my ($self, $cur, $pe) = @_;
	my $swap = $pe > $cur->ap ? 1 : 0;
	my $dst = $swap ?
		$cur->body->orbit(pe => $pe, ap => $cur->ap) :
		$cur->body->orbit(pe => $pe, ap => $cur->ap);
	my $h = $cur->ap;
	my $dv = $dst->v_from_vis_viva($h) - $cur->v_from_vis_viva($h);
	warn "BURNAP $swap ", U($dv), "m/s AT ", U($h), "m TO $dst\n";
	$dv and $self->_add(do => "burn", dv => $dv, h => $h, then => $dst);
}

sub _cur($) { $_[0]->[-1] }

sub _len($) { scalar @{$_[0]} }

sub _add($%) {
	my ($self, %data) = @_;
	$data{do} or croak "\"do\" needed";
	$data{then} = _asorbit($data{then})
		or croak "KSP::Orbit2D needed as \"then\"";
	push @$self, \%data;
	$self
}

sub _asorbit($;$) {
	my ($o, $die) = @_;
	ref $o && $o->isa("KSP::Body")
		and $o = $o->lowOrbit();
	ref $o && $o->isa("KSP::Orbit2D")
		or ($die ? croak "KSP::Orbit2D or KSP::Body needed here" : ($o = undef));
	$o
}

1;

