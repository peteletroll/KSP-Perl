package KSP::Course;

use utf8;
use strict;
use warnings;

use Carp;

use POSIX qw(ceil);

use Math::Trig;

use KSP::Util qw(U error);

use KSP::TinyStruct qw(step);

use Text::Table;

use overload
	'""' => sub { $_[0]->desc };

sub proxable { qw(
	burn burnTo burnCirc
	burnIncl burnInclDeg
	enterTo leaveTo
	goPe goAp goTo
	goCommNet
) }

sub BUILD {
	my ($self, $start) = @_;
	$self->set_step([ ]);
	UNIVERSAL::isa($start, "KSP::Orbit2D")
		or confess "KSP::Orbit2D needed";
	$self->_add(do => "start", then => $start)
}

sub length { scalar @{$_[0]->step} }

sub current { $_[0]->step->[-1]->{then} }

sub at {
	my ($self, $at) = @_;
	my $l = $self->length;
	$at >= -$l && $at < $l
		or croak "at($at) out of range";
	$self->step->[$at]->{then}
}

sub dv {
	my ($self, $at) = @_;
	my $l = $self->length;
	defined $at or $at = $l - 1;
	$at < 0 and $at = $l + $at;
	$at >= 0 or $at = 0;
	$at < $l or $at = $l - 1;
	my $dv = 0;
	for (my $i = 0; $i <= $at; $i++) {
		$dv += abs($self->step->[$i]->{dv} || 0);
	}
	U($dv, "m/s")
}

sub nextBurnHeight {
	my ($self, $hdefault) = @_;
	my $cur = $self->current;
	$hdefault and $self->checkHeight($hdefault);
	U(($self->step->[-1]{hburn} || $hdefault || $cur->pe), "m")
}

sub desc {
	my ($self) = @_;
	my $al = { align => "left" };
	my $ar = { align => "right" };
	my $sp = \"  ";
	my $table = Text::Table->new($ar, $al, $sp, $ar, $sp, $ar, $sp, $al, $al);
	for (my $i = 0; $i < $self->length; $i++) {
		$table->add($self->_row($i));
	}
	$table->add(
		"",
		"tot Δv",
		$self->dv,
		$self->nextBurnHeight . " ");
	$table
}

sub _row {
	my ($self, $i) = @_;
	my $c = $self->step->[$i];
	my $p = ($i > 0 && $self->step->[$i - 1]);

	my $type = $c->{do};
	my $prep = $type =~ /start/ ? "at" : "to";

	my $cur = $c->{then};
	my $ref = $type =~ /leave/ ? $cur : ($p && $p->{then});

	my $dv = "";
	if ($c->{dv}) {
		$prep = "to";
		if ($type =~ /incl/) {
			$dv = "⟂" . U(abs($c->{dv}), "m/s");
		} else {
			$dv = U($c->{dv}, "m/s");
			$dv =~ /^[\+\-]/ or $dv = "+$dv";
		}
	}

	my $h = $c->{h};
	my $hflag = " ";
	if (defined $h && $ref) {
		if (error($h, $ref->pe) < 1e-3) {
			$hflag = "↓";
		} elsif (error($h, $ref->ap(1)) < 1e-3) {
			$hflag = "↑";
		}
	}
	$h = defined $h ? U($h, "m") : "";

	("$i:", $type, $dv, "$h$hflag", $prep, $cur->desc($p && $p->{then}))
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

sub burn {
	my ($self, $dv) = @_;
	my $cur = $self->current;
	my $hcur = $self->nextBurnHeight;
	my $dst = $cur->body->orbit(pe => $hcur, h => $hcur, v => $cur->v($hcur) + $dv);
	$self->_add_burn($cur, $dst, $hcur)
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
	defined $h or $h = $self->nextBurnHeight;
	my $vincl = $cur->v($h);
	my $dvincl = 2 * sin($incl / 2) * $vincl;
	$dvincl > 1e-10 or return $self;
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
	defined $hdst or $hdst = $bdst->lowHeight;
	while ($cur->body != $bdst) {
		# warn "CUR $cur\n";
		my $b1 = $cur->body;
		my $b2 = $cur->body->nextTo($bdst);
		# warn "STEP ", $b1->name, " -> ", $b2->name, "\n";

		my $hb1 = $b2->orbit->commonApsis($cur);
		defined $hb1 or croak "apses mismatched for enter";

		my $vb2 = $cur->v($hb1) - $b2->orbit->v($hb1);
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
		$self->_add(do => "leave", then => $inv->step->[$i - 1]{then}, h => $inv->step->[$i]{h})
			if $inv->step->[$i]{do} eq "enter";
	}
	$self->goTo($dst)
}

sub goTo {
	my ($self, $dst, @rest) = @_;
	my $cur = $self->current;
	# warn "CUR $cur\n";
	$dst = _asorbit($dst, 1);
	$self->_go_samebody($dst, @rest)
		or $self->_go_ancestor($cur, $dst, @rest)
		or $self->_go_descendant($cur, $dst, @rest)
		or $self->_go_hohmann($cur, $dst, @rest)
		or croak "don't know how to go from $cur to $dst";
	$self
}

sub goCommNet {
	my ($self, $N, $M) = @_;
	my $body = $self->current->body;
	defined $N && $N >= 3 or $N = 3;
	defined $M or $M = "3h";
	if ($M =~ /^(.+)([smhdy])$/) {
		$M = $2 eq "s" ? $1 :
			$2 eq "m" ? 60 * $1 :
			$2 eq "h" ? 60 * 60 * $1 :
			$2 eq "d" ? $body->system->secs_per_day * $1 :
			$2 eq "y" ? $body->system->secs_per_year * $1 :
			$M;
	}

	my $r = $body->radius;
	my $hmin = ($body->lowHeight + $r) / cos(pi / $N) - $r;
	my $omin = $body->orbit($hmin);
	my $T = $M * ceil($omin->T / $M);

	my ($of, $ot);
	for (;; $T += $M) {
		$of = $body->orbit(e => 0, T => $T);
		# print "trying of = $of\n";
		my $h = $of->pe;
		$h > $hmin or next;
		$ot = $body->orbit(ap => $h, T => (($N - 1) / $N) * $T);
		# print "trying ot = $ot\n";
		$ot->pe >= $body->lowHeight or next;
		last;
	}

	$self->burnTo($of->ap)->goAp->burnTo($ot->pe)->goAp->burnCirc;
}

sub _go_height {
	my ($self, $hdst) = @_;
	$self->current->checkHeight($hdst);
	$self->step->[-1]{hburn} = 0 + $hdst;
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

	my $bh = $self->nextBurnHeight;
	if (error($bh, $ap1) < 1e-4) {
		$self->_add_burn($cur, $dst, $dst->pe);
	} else {
		my $tr = $cur->body->orbit(pe => $bh, ap => $ap1);
		# warn "SAMEBODY ap1 = ", U($ap1), "m, tr = $tr\n";
		$self->_add_burn($cur, $tr, $self->nextBurnHeight);
		$self->_add_burn($tr, $dst, $dst->pe);
	}

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
	my ($tr, $htr1, $htr2) = $trb1->orbit->hohmannTo($trb2->orbit, @rest);
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
	my $dv = $to->v($h) - $from->v($h);
	# warn "BURN ", U($dv), "m/s AT ", U($h), "m TO $to\n";
	abs($dv) > 1e-10 and $self->_add(do => "burn", dv => $dv, h => $h, then => $to);
	$self
}

sub _add($%) {
	my ($self, %data) = @_;
	$data{do} or croak "\"do\" needed";
	$data{then} = _asorbit($data{then})
		or croak "KSP::Orbit2D needed as \"then\"";
	push @{$self->step}, \%data;
	$self
}

sub _asorbit($;$) {
	my ($o, $die) = @_;
	UNIVERSAL::isa($o, "KSP::Body")
		and $o = $o->lowOrbit;
	UNIVERSAL::isa($o, "KSP::Orbit2D")
		or ($die ? croak "KSP::Orbit2D or KSP::Body needed here" : ($o = undef));
	$o
}

1;

