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
	$self->_go_samebody($cur, $dst)
		or $self->_go_child($cur, $dst)
		or $self->_go_parent($cur, $dst)
		or croak "can't go from $cur to $dst";
	$self
}

sub desc {
	my ($self) = @_;
	my @d = ();
	my $dvtot = 0;
	foreach (@$self) {
		my $d = $_->{do};
		my $p = "at";
		my $dv = $_->{dv};
		if ($dv) {
			$d .= " " . ($dv > 0 ? "+" : "") . U($dv) . "m/s";
			$p = "to";
			$dvtot += abs($dv);
		}
		$_->{h} and $d .= " at " . U($_->{h}) . "m";
		$d .= " $p " . $_->{then};
		push @d, $d;
	}
	push @d, "total Δv " . U($dvtot) . "m/s";
	join "\n", @d
}

sub _go_samebody {
	my ($self, $cur, $dst) = @_;

	$cur->body == $dst->body
		&& $cur->e < 1
		&& $dst->e < 1
		or return;

	my $tr1 = $cur->body->orbit(pe => $dst->pe, ap => $cur->ap);
	my $h1 = $cur->ap;
	$self->_add_burn($cur, $tr1, $h1);

	my $tr2 = $cur->body->orbit(pe => $dst->pe, ap => $dst->ap);
	my $h2 = $dst->pe;
	$self->_add_burn($tr1, $tr2, $h2);

	$self->_add_burn($tr2, $dst, $dst->ap);

	1
}

sub _go_child {
	my ($self, $cur, $dst) = @_;
	$dst->body->parent == $cur->body
		or return;

	my $htr = $cur->pe;
	my $hin = $dst->body->orbit->ap;
	my $tr = $cur->body->orbit(pe => $htr, ap => $hin);
	$self->_add_burn($cur, $tr, $htr);
	# warn "TO CHILD $tr\n";

	my $vin = $tr->v_from_vis_viva($hin) - $dst->body->orbit->v_from_vis_viva($hin);
	my $in = $dst->body->orbit(pe => $dst->pe, v => $vin, r => $dst->body->SOI);
	$self->_add_soi($in);

	$self->_add_burn($in, $dst, $in->pe);

	1
}

sub _go_parent {
	my ($self, $cur, $dst) = @_;
	$dst->body == $cur->body->parent
		or return;

	my $hout = $cur->body->orbit->ap;
	my $tr = $dst->body->orbit(pe => $dst->pe, ap => $hout);
	# warn "TO PARENT $tr\n";

	my $vout = $tr->v_from_vis_viva($hout) - $cur->body->orbit->v_from_vis_viva($hout);
	my $out = $cur->body->orbit(pe => $dst->pe, v => $vout, r => $cur->body->SOI);
	# warn "OUT $out\n";

	$self->_add_burn($cur, $out, $cur->pe);

	$self->_add_soi($out);

	$self->_add_burn($tr, $dst, $dst->pe);

	1
}

sub _cur($) { $_[0]->[-1] }

sub _len($) { scalar @{$_[0]} }

sub _add_burn {
	my ($self, $from, $to, $h) = @_;
	my $dv = $to->v_from_vis_viva($h) - $from->v_from_vis_viva($h);
	# warn "BURN ", U($dv), "m/s AT ", U($h), "m TO $to\n";
	$dv and $self->_add(do => "burn", dv => $dv, h => $h, then => $to);
	$self
}

sub _add_soi {
	my ($self, $to) = @_;
	$self->_add(do => "soi", then => $to)
}

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
