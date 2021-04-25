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

sub desc {
	my ($self) = @_;
	my @d = ();
	for (my $i = 0; $i < @$self; $i++) {
		my $s = $self->[$i];
		push @d, sprintf("%3d: ", $i) . _step($s);
	}
	push @d, sprintf "     tot Δv%9sm/s", U($self->dv);
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

sub goTo {
	my ($self, $dst) = @_;
	my $cur = $self->current;
	# warn "CUR $cur\n";
	$dst = _asorbit($dst, 1);
	$self->_go_samebody($cur, $dst)
		or $self->_go_child($cur, $dst)
		or $self->_go_ancestor($cur, $dst)
		or $self->_go_descendant($cur, $dst)
		or $self->_go_sibling($cur, $dst)
		or croak "can't go from $cur to $dst";
	$self
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
	my $in = $dst->body->orbit(pe => $dst->pe, v_soi => $vin);
	$self->_add_soi($in);

	$self->_add_burn($in, $dst, $in->pe);

	1
}

sub _go_descendant {
	my ($self, $cur, $dst) = @_;
	$cur->body->hasDescendant($dst->body)
		or return;

	warn "TO DESCENDANT $cur -> $dst\n";
	my @b = ();
	for (my $b = $dst->body; $b && $b != $cur->body; $b = $b->parent) {
		push @b, $b;
	}
	push @b, $cur->body;
	@b = reverse @b;
	warn "CHAIN ", join(" ", map { "[" . $_->name . "]" } @b), "\n";

	my ($tr, $htr1, $htr2) = $cur->hohmannTo($b[1]->orbit);
	warn "TR ", U($htr1), "m ", U($htr2), "m $tr\n";

	return;

	my @tr = ($tr);
	my $out = $tr;
	for (my $i = @b - 2; $i >= 0; $i--) {
		# my ($b1, $b2) = @b[$i, $i + 1];
		my $b1 = $b[$i];
		my $b2 = $out->body;
		# warn "\nSTEP ", $b1->name, " -> ", $b2->name, ", $out\n";
		my $hout = $b1->orbit->ap;
		my $vout = $out->v_from_vis_viva($hout) - $b1->orbit->v_from_vis_viva($hout);
		my $b1pe = $i > 0 ? $b[$i - 1]->orbit->pe : $cur->pe;
		# warn "OUT ", U($vout), "m/s AT ", U($hout), "m FROM ", U($b1pe), "\n";

		$out = $b1->orbit(pe => $b1pe, v_soi => $vout);
		# warn "OUT $out\n";
		push @tr, $out;
	}

	# warn "\n";
	# warn "SEQ $_\n" foreach @tr;

	$self->_add_burn($cur, $tr[-1], $cur->pe);
	for (my $i = @tr - 2; $i >= 0; $i--) {
		$self->_add_soi($tr[$i]);
	}

	$self->_add_burn($tr[0], $dst, $htr2);

	1
}

sub _go_ancestor {
	my ($self, $cur, $dst) = @_;
	$cur->body->hasAncestor($dst->body)
		or return;

	# warn "TO ANCESTOR $cur -> $dst\n";
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
		# my ($b1, $b2) = @b[$i, $i + 1];
		my $b1 = $b[$i];
		my $b2 = $out->body;
		# warn "\nSTEP ", $b1->name, " -> ", $b2->name, ", $out\n";
		my $hout = $b1->orbit->ap;
		my $vout = $out->v_from_vis_viva($hout) - $b1->orbit->v_from_vis_viva($hout);
		my $b1pe = $i > 0 ? $b[$i - 1]->orbit->pe : $cur->pe;
		# warn "OUT ", U($vout), "m/s AT ", U($hout), "m FROM ", U($b1pe), "\n";

		$out = $b1->orbit(pe => $b1pe, v_soi => $vout);
		# warn "OUT $out\n";
		push @tr, $out;
	}

	# warn "\n";
	# warn "SEQ $_\n" foreach @tr;

	$self->_add_burn($cur, $tr[-1], $cur->pe);
	for (my $i = @tr - 2; $i >= 0; $i--) {
		$self->_add_soi($tr[$i]);
	}

	$self->_add_burn($tr[0], $dst, $htr2);

	1
}

sub _go_sibling {
	my ($self, $cur, $dst) = @_;
	$cur->body->parent == $dst->body->parent
		or return;

	my ($tr, $htr1, $htr2) = $cur->body->hohmannTo($dst->body);
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
	my $vincl = $tr->vmax;
	my $dvincl = 2 * sin($incl / 2) * $vincl;
	$self->_add(do => "incl", dv => $dvincl, then => $tr);

	$self->_add_soi($in);

	$self->_add_burn($in, $dst, $dst->pe);

	1
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

