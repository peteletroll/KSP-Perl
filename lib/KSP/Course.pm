package KSP::Course;

use utf8;
use strict;
use warnings;

use Carp;

use Math::Trig;

use KSP::Util qw(U error);

use overload
	'""' => \&desc;

sub proxable { qw(
	burnTo burnCirc
	burnIncl burnInclDeg
	enterTo leaveTo
	goPe goAp goTo
) }

sub new {
	my ($pkg, $start) = @_;
	ref $start && $start->isa("KSP::Orbit2D")
		or confess "KSP::Orbit2D needed";
	my $new = bless [ ], $pkg;
	$new->_add(do => "start", then => $start)
}

sub length { scalar @{$_[0]} }

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
	push @d, sprintf "      tot Δv%9sm/s, next burn at %sm\n",
		U($self->dv),
		U($self->nextBurnHeight);
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

	sprintf "%-9s %9s %8s %3s %s",
		$type, $dv, $h, $prep, $s->{then}
}

sub goPe {
	my ($self, $pe) = @_;
	$pe = 1 if @_ < 2;
	$self->_go_height($pe ? $self->current->pe : $self->current->ap);
	$self
}

sub goAp {
	my ($self, $ap) = @_;
	$ap = 1 if @_ < 2;
	$self->_go_height($ap ? $self->current->ap : $self->current->pe);
	$self
}

sub burnTo {
	my ($self, $hdst) = @_;
	my $cur = $self->current;
	ref $hdst and croak "scalar needed for burnTo()";
	my $hcur = $self->nextBurnHeight;
	my $tr = $cur->body->orbit(pe => $hcur, ap => $hdst);
	$self->_add_burn($cur, $tr, $hcur)->_go_height($hdst > 0 ? $hdst : $hcur)
}

sub burnCirc {
	my ($self) = @_;
	my $cur = $self->current;
	my $h = $self->nextBurnHeight;
	$self->goTo($cur->body->orbit(pe => $h, ap => $h));
}

sub burnInclDeg {
	my ($self, $incl, $h) = @_;
	$self->burnIncl(deg2rad($incl), $h)
}

sub burnIncl {
	my ($self, $incl, $h) = @_;
	my $cur = $self->current;
	defined $h or $h = $cur->pe;
	my $vincl = $cur->v_from_vis_viva($h);
	my $dvincl = 2 * sin($incl / 2) * $vincl;
	my $deg = rad2deg($incl);
	$deg = sprintf(($deg < 1 ? "%0.2f°" : $deg < 10 ? "%0.1f°" : "%.0f°"), $deg);
	$deg =~ s/^0\././;
	$self->_add(do => "incl $deg", dv => $dvincl, h => $h, then => $cur)

}

sub enterTo {
	my ($self, $bdst, $hdst) = @_;
	UNIVERSAL::isa($bdst, "KSP::Body")
		or croak "body needed for enterTo()";
	my $cur = $self->current;
	$bdst->hasAncestor($cur->body)
		or croak "can't enter from ", $cur->body->name, " to ", $bdst->name;
	ref $hdst and croak "scalar needed for enterTo()";
	$hdst ||= $bdst->lowHeight;
	while ($cur->body != $bdst) {
		# warn "CUR $cur\n";
		my $b1 = $cur->body;
		my $b2 = $cur->body->nextTo($bdst);
		# warn "STEP ", $b1->name, " -> ", $b2->name, "\n";

		my $hb1 = $b2->orbit->commonApsis($cur);
		defined $hb1 or croak "apses mismatched for enter";

		my $vb2 = $cur->v_from_vis_viva($hb1) - $b2->orbit->v_from_vis_viva($hb1);
		# warn "VDST ", U($vb2), "m/s AT ", U($hb1), "m\n";
		$cur = $b2->orbit(v_soi => $vb2, pe => $b2 == $bdst ? $hdst : $b2->nextTo($bdst)->pe);
		$self->_add(do => "enter", then => $cur, h => $hb1);
	}
	# warn "CUR $cur\n";
	$self
}

sub leaveTo {
	my ($self, $dst, @rest) = @_;
	my $cur = $self->current;
	$cur->body->hasAncestor($dst->body)
		or croak "can't leave from ", $cur->body->name, " to ", $dst->body->name;

	my ($tr, $htr1, $htr2) = $dst->body->nextTo($cur->body)->orbit->hohmannTo($dst, @rest);

	my $inv = KSP::Course->new($tr)->enterTo($cur->body, $self->nextBurnHeight);
	# warn "<INV>\n$inv</INV>\n";
	$self->goTo($inv->current);
	for (my $i = $inv->length - 1; $i > 0; $i--) {
		$self->_add(do => "leave", then => $inv->[$i - 1]{then}, h => $inv->[$i]{h})
			if $inv->[$i]{do} eq "enter";
	}
	$self->goTo($dst)
}

sub goTo {
	my ($self, $dst, @rest) = @_;
	my $cur = $self->current;
	# warn "CUR $cur\n";
	$dst = _asorbit($dst, 1);
	$self->_go_samebody($dst)
		or $self->_go_ancestor($cur, $dst, @rest)
		or $self->_go_descendant($cur, $dst, @rest)
		or $self->_go_hohmann($cur, $dst, @rest)
		or croak "don't know how to go from $cur to $dst";
	$self
}

sub _go_height {
	my ($self, $hdst) = @_;
	$self->current->checkHeight($hdst);
	$self->[-1]{hburn} = 0 + $hdst;
	$self
}

sub _go_samebody {
	my ($self, $dst) = @_;
	my $cur = $self->current;
	$cur->body == $dst->body
		or return;

	my $common = $cur->commonApsis($dst);
	if ($common) {
		my $other = $dst->otherApsis($common);
		# warn "SAMEBODY COMMON ", U($common), "m -> ", U($other), "m\n";
		$self->_go_height($common)->_add_burn($cur, $dst, $self->nextBurnHeight);
		return 1
	}

	my $hh = $cur->body->highHeight;
	my $ap1 = $dst->e < 1 && $dst->ap < $hh ? $dst->ap :
		$cur->e < 1 && $cur->ap < $hh ? $cur->ap :
		$hh;

	$self->burnTo($ap1)->burnTo($dst->pe)->burnTo($dst->ap(1));

	1
}

sub _go_descendant {
	my ($self, $cur, $dst, @rest) = @_;
	$cur->body->hasDescendant($dst->body)
		or return;

	my ($tr, $htr1, $htr2) = $cur->hohmannTo($cur->body->nextTo($dst->body));
	# warn "TR ", U($htr1), "m ", U($htr2), "m $tr\n";

	$self->_add_burn($cur, $tr, $htr1)
		->enterTo($dst->body, $dst->pe)
		->goTo($dst);

	1
}

sub _go_ancestor {
	my ($self, $cur, $dst, @rest) = @_;
	$cur->body->hasAncestor($dst->body)
		or return;

	$self->leaveTo($dst);

	1
}

sub _go_hohmann {
	my ($self, $cur, $dst, @rest) = @_;
	$cur->body != $dst->body
		or return;

	my ($trb1, $trb2) = _hohmann_pair($cur->body, $dst->body);
	$trb1 && $trb2
		or return;
	my ($tr, $htr1, $htr2) = $trb1->orbit->hohmannTo($trb2->orbit);
	# warn "HOHMANN ", $trb1->name, " ", U($htr1), "m -> ", $trb2->name, " ", U($htr2), "m, $tr\n";

	$self->leaveTo($tr);

	my $incl = atan2($trb1->orbitNormal, $trb2->orbitNormal);
	my $hincl = $tr->pe;
	$self->burnIncl($incl, $hincl);

	$self->enterTo($dst->body, $dst->pe)->goTo($dst);

	1
}

sub _hohmann_pair {
	my ($body1, $body2) = @_;
	$body1 != $body2 or return;
	foreach my $b1 ($body1->pathToRoot) {
		$b1->parent or return ();
		foreach my $b2 ($body2->pathToRoot) {
			$b1->parent == $b2->parent and return ($b1, $b2);
		}
	}
	return;
}

sub _add_burn {
	my ($self, $from, $to, $h) = @_;
	my $dv = $to->v_from_vis_viva($h) - $from->v_from_vis_viva($h);
	# warn "BURN ", U($dv), "m/s AT ", U($h), "m TO $to\n";
	abs($dv) > 1e-10 and $self->_add(do => "burn", dv => $dv, h => $h, then => $to);
	$self
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

