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

sub current { $_[0]->[-1]->{then} }

sub at {
	my ($self, $at) = @_;
	$at >= -@$self && $at < @$self
		or croak "at($at) out of range";
	$self->[$at]->{then}
}

sub dv {
	my ($self) = @_;
	my $dv = 0;
	$dv += abs($_->{dv} || 0) foreach @$self;
	$dv
}

sub nextBurnHeight {
	my ($self, $hdefault) = @_;
	my $cur = $self->current;
	$hdefault and $self->checkHeight($hdefault);
	$self->[-1]{hburn} || $hdefault || $cur->pe
}

sub desc {
	my ($self) = @_;
	my @d = ();
	for (my $i = 0; $i < @$self; $i++) {
		my $s = $self->[$i];
		push @d, sprintf("%3d: ", $i) . _step($s);
	}
	push @d, sprintf "     tot Δv%9sm/s%s",
		U($self->dv),
		($self->[-1]{hburn} ? sprintf("%8sm", U($self->nextBurnHeight)) : "");
	join "\n", @d
}

sub _step($) {
	my ($s) = @_;

	my $type = $s->{do};
	my $prep = $type =~ /start/ ? "at" : "to";

	my $dv = "";
	if ($s->{dv}) {
		$prep = "to";
		if ($type =~ /incl/) {
			$dv = "⟂" . U(abs($s->{dv}));
		} else {
			$dv = U($s->{dv});
			$dv =~ /^[\+\-]/ or $dv = "+$dv";
		}
		$dv .= "m/s";
	}

	my $h = $s->{h} ? U($s->{h}) . "m" : "";

	sprintf "%-8s %9s %8s %3s %s",
		$type, $dv, $h, $prep, $s->{then}
}

sub goAp {
	my ($self) = @_;
	$self->[-1]{hburn} = $self->current->ap;
	$self
}

sub goTo {
	my ($self, $dst, $toAp) = @_;
	my $cur = $self->current;
	# warn "CUR $cur\n";
	$dst = _asorbit($dst, 1);
	$self->_go_samebody($cur, $dst)
		or $self->_go_ancestor($cur, $dst, $toAp)
		or $self->_go_descendant($cur, $dst, $toAp)
		or $self->_go_hohmann($cur, $dst, $toAp)
		or $self->_go_sibling($cur, $dst, $toAp)
		or croak "can't go from $cur to $dst";
	$self
}

sub _go_samebody {
	my ($self, $cur, $dst, $toAp) = @_;
	$cur->body == $dst->body
		or return;

	if (abs($dst->pe - $cur->pe) / ($dst->pe + $cur->pe) < 1e-5) {
		$self->_add_burn($cur, $dst, $cur->pe);
		return 1
	}

	my $ap1 = $dst->e < 1 ? $dst->ap :
		$cur->e < 1 ? $cur->ap :
		$cur->body->highHeight;

	my $h1 = $self->nextBurnHeight;
	my $tr1 = $cur->body->orbit(pe => $h1, ap => $ap1);
	$self->_add_burn($cur, $tr1, $h1);

	my $h2 = $ap1;
	my $tr2 = $cur->body->orbit(pe => $dst->pe, ap => $ap1);
	$self->_add_burn($tr1, $tr2, $h2);

	$self->_add_burn($tr2, $dst, $dst->pe);

	1
}

sub _go_descendant {
	my ($self, $cur, $dst, $toAp) = @_;
	$cur->body->hasDescendant($dst->body)
		or return;

	# warn "TO DESCENDANT $cur -> $dst\n";
	my @b = ();
	for (my $b = $dst->body; $b && $b != $cur->body; $b = $b->parent) {
		push @b, $b;
	}
	push @b, $cur->body;
	@b = reverse @b;
	# warn "CHAIN ", join(" ", map { "[" . $_->name . "]" } @b), "\n";

	my ($tr, $htr1, $htr2) = $cur->hohmannTo($b[1]->orbit);
	# warn "TR ", U($htr1), "m ", U($htr2), "m $tr\n";

	my @tr = ($tr);
	my $in = $tr;
	for (my $i = 1; $i < @b; $i++) {
		my $b1 = $in->body;
		my $b2 = $b[$i];
		# warn "\nSTEP ", $b1->name, " -> ", $b2->name, ", $in\n";
		my $hin = $b2->orbit->ap;
		my $vin = $in->v_from_vis_viva($hin) - $b2->orbit->v_from_vis_viva($hin);
		my $b2pe = $i < $#b ? $b[$i + 1]->orbit->pe : $dst->pe;
		# warn "IN ", U($vin), "m/s AT ", U($hin), "m TO ", U($b2pe), "\n";

		$in = $b2->orbit(pe => $b2pe, v_soi => $vin);
		# warn "IN $in\n";
		push @tr, $in;
	}

	# warn "\n";
	# warn "SEQ $_\n" foreach @tr;

	$self->_add_burn($cur, $tr[0], $htr1);

	for (my $i = 1; $i < @b; $i++) {
		$self->_add_soi($tr[$i]);
	}

	$self->_add_burn($tr[-1], $dst, $dst->pe);

	1
}

sub _go_ancestor {
	my ($self, $cur, $dst, $toAp) = @_;
	$cur->body->hasAncestor($dst->body)
		or return;

	my @b = ();
	for (my $b = $cur->body; $b && $b != $dst->body; $b = $b->parent) {
		push @b, $b;
	}
	push @b, $dst->body;
	# warn "CHAIN ", join(" ", map { "[" . $_->name . "]" } @b), "\n";

	my ($tr, $htr1, $htr2) = $b[-2]->orbit->hohmannTo($dst);
	# warn "TR ", U($htr1), "m ", U($htr2), "m $tr\n";

	my @tr = ($tr);
	my $out = $tr;
	for (my $i = @b - 2; $i >= 0; $i--) {
		my $b1 = $b[$i];
		my $b2 = $out->body;
		# warn "\nSTEP ", $b1->name, " -> ", $b2->name, ", $out\n";
		my $hout = $b1->orbit->ap;
		my $vout = $out->v_from_vis_viva($hout) - $b1->orbit->v_from_vis_viva($hout);
		my $b1pe = $i > 0 ? $b[$i - 1]->orbit->pe : $self->nextBurnHeight;
		# warn "OUT ", U($vout), "m/s AT ", U($hout), "m FROM ", U($b1pe), "\n";

		$out = $b1->orbit(pe => $b1pe, v_soi => $vout);
		# warn "OUT $out\n";
		push @tr, $out;
	}

	# warn "\n";
	# warn "SEQ $_\n" foreach @tr;

	$self->_add_burn($cur, $tr[-1], $self->nextBurnHeight);

	for (my $i = @tr - 2; $i >= 0; $i--) {
		$self->_add_soi($tr[$i]);
	}

	$self->_add_burn($tr[0], $dst, $htr2);

	1
}

sub _go_hohmann {
	my ($self, $cur, $dst, $toAp) = @_;
	$cur->body != $dst->body
		or return;
	my ($trb1, $trb2) = _hohmann_pair($cur->body, $dst->body);
	$trb1 && $trb2
		or return;
	my ($tr, $htr1, $htr2) = $trb1->orbit->hohmannTo($trb2->orbit);
	warn "TO HOHMANN ", $trb1->name, " ", U($htr1), "m -> ", $trb2->name, " ", U($htr2), "m, $tr\n";
	return
}

sub _go_sibling {
	my ($self, $cur, $dst, $toAp) = @_;
	$cur->body->parent == $dst->body->parent
		or return;

	my ($tr, $htr1, $htr2) = $cur->body->orbit->hohmannTo($dst->body->orbit);
	# warn "TO SIBLING $htr1 $htr2 $tr\n";

	my $out = $cur->body->orbit(pe => $cur->pe,
		v_soi => $tr->v_from_vis_viva($htr1) - $cur->body->orbit->v_from_vis_viva($htr1));
	# warn "OUT $out\n";

	my $in = $dst->body->orbit(pe => $dst->pe,
		v_soi => $tr->v_from_vis_viva($htr2) - $dst->body->orbit->v_from_vis_viva($htr2));
	# warn "IN $in\n";

	$self->_add_burn($cur, $out, $cur->pe);

	$self->_add_soi($tr);

	my $incl = $cur->body->orbitNormal->angle($dst->body->orbitNormal);
	my $hincl = $tr->pe;
	my $vincl = $tr->v_from_vis_viva($hincl);
	my $dvincl = 2 * sin($incl / 2) * $vincl;
	$self->_add(do => "incl", dv => $dvincl, then => $tr);

	$self->_add_soi($in);

	$self->_add_burn($in, $dst, $dst->pe);

	1
}

sub _hohmann_pair {
	my ($self, $other) = @_;
	foreach my $b1 ($self->pathToRoot) {
		$b1->parent or return ();
		foreach my $b2 ($other->pathToRoot) {
			$b1->parent == $b2->parent and return ($b1, $b2);
		}
	}
	return ();
}

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
		and $o = $o->lowOrbit;
	ref $o && $o->isa("KSP::Orbit2D")
		or ($die ? croak "KSP::Orbit2D or KSP::Body needed here" : ($o = undef));
	$o
}

1;

