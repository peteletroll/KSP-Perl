package KSP::Orbit2D;

use utf8;
use strict;
use warnings;

use Carp;

use Math::Trig;

use KSP::TinyStruct qw(body e p);

use KSP::Course;

use KSP::Util qw(U error proxy);
proxy("KSP::Course" => sub { KSP::Course->new($_) });

use overload
	'""' => \&desc;

our %newpar = map { $_ => 1 } qw(p e a pe ap E r h v v_soi v_inf T th_inf trace);

our $TRACE = 0;

sub BUILD {
	my ($self, $body, %par) = @_;
	defined $body or croak "missing body";
	ref $body or Carp::confess "body needed here";
	$newpar{$_} or croak "unknown orbit parameter $_" foreach keys %par;

	my $trace = delete $par{trace} || $TRACE;
	my $par = \%par;
	my $origpar = _pardesc($par);
	my $r = $body->radius;
	my $mu = $body->mu;

	$trace and warn "START: ", _pardesc($par), "\n";

	if (_defined($par, qw(h !r))) {
		$par{r} = $par{h} + $r;
		$trace and warn "\tCMP r:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(v_soi !v !r))) {
		$par{v} = $par{v_soi};
		$par{r} = $body->SOI;
		$trace and warn "\tCMP v:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(v r !E))) {
		$par{E} = $par{v} ** 2 / 2 - $mu / $par{r};
		$trace and warn "\tCMP E:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(e v !a)) && $par{v} && !$par{e}) {
		$par{a} = $mu / $par{v} ** 2;
		$trace and warn "\tCMP a:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(v_inf !a))) {
		$par{a} = -$mu / $par{v_inf} ** 2;
		$trace and warn "\tCMP a:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(E !a))) {
		if ($par{E}) {
			$par{a} = -$mu / 2 / $par{E};
			$par{inv_a} = - 2 * $par{E} / $mu;
		} else {
			$par{inv_a} = 0;
		}
		$trace and warn "\tCMP a:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(T !a))) {
		$par{a} = ($mu * ($par{T} / 2 / pi) ** 2) ** (1 / 3);
		$trace and warn "\tCMP a:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(ap pe))) {
		my $ap = $par{ap};
		my $pe = $par{pe};
		if ($pe < 0 || $ap > 0 && $pe > $ap) {
			$par{pe} = $ap;
			$par{ap} = $pe;
			$trace and warn "\tSWAP:\t", _pardesc($par), "\n";
		}
	}

	if (_defined($par, qw(ap pe !a))) {
		$par{a} = ($par{ap} + $par{pe}) / 2 + $r;
		$trace and warn "\tCMP a:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(a !inv_a)) && $par{a}) {
		$par{inv_a} = 1 / $par{a};
		$trace and warn "\tCMP inv_a:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(inv_a !a)) && $par{inv_a}) {
		$par{a} = 1 / $par{inv_a};
		$trace and warn "\tCMP a:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(a pe !ap))) {
		$par{ap} = 2 * $par{a} - 2 * $r - $par{pe};
		$trace and warn "\tCMP ap:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(a ap !pe))) {
		$par{pe} = 2 * $par{a} - 2 * $r - $par{ap};
		$trace and warn "\tCMP pe:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(ap pe a)) && $par{a} > 0 && $par{ap} < $par{pe}) {
		($par{ap}, $par{pe}) = ($par{pe}, $par{ap});
		$trace and warn "\tSWP ap:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(ap pe !e))) {
		$par{e} = ($par{ap} - $par{pe}) / ($par{ap} + $par{pe} + 2 * $r);
		$trace and warn "\tCMP e:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(E)) && !$par{E}) {
		$par{e} = 1;
		$trace and warn "\tCMP e:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(th_inf !e))) {
		$par{e} = -1 / cos($par{th_inf});
		$trace and warn "\tCMP e:\t", _pardesc($par), "\n";
	}

	_defined($par, qw(!e)) and croak "can't compute e from $origpar";
	my $e = $par{e};
	$e < 0 && $e > -1e-10 and $e = 0;

	if (_defined($par, qw(pe e !p))) {
		$par{p} = ($par{pe} + $r) * (1 + $par{e});
		$trace and warn "\tCMP p:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(ap e !p)) && $par{e} != 1) {
		$par{p} = ($par{ap} + $r) * (1 - $par{e});
		$trace and warn "\tCMP p:\t", _pardesc($par), "\n";
	}

	if (_defined($par, qw(a !p))) {
		$par{p} = $par{a} * (1 - $e * $e);
		$trace and warn "\tCMP p:\t", _pardesc($par), "\n";
	}

	_defined($par, qw(!p)) and croak "can't compute p from $origpar";
	my $p = $par{p};

	$p > 0 && $e >= 0 or confess sprintf "can't create orbit around %s with p=%g, e=%g from %s",
		$body->name, $p, $e, $origpar;

	$self->set_body($body);
	$self->set_e($e); # eccentricity
	$self->set_p($p); # semilatus rectum
	$self
}

sub _defined($@) {
	my ($p, @c) = @_;
	foreach my $c (@c) {
		$c =~ /^(!*)(\w+)$/ or confess "bad _defined() spec";
		(defined $p->{$2} xor $1) or return 0;
	}
	1
}

sub _pardesc($) {
	my ($par) = @_;
	join(", ",
		map { sprintf "%s=%g", $_, $par->{$_} }
		sort grep { defined $par->{$_} }
		keys %$par) || "nothing";
}

sub _need_ellipse {
	$_[0]->e < 1 or croak "not allowed for open orbit";
}

sub a { # major semiaxis
	my ($self, $noerr) = @_;
	$noerr or $self->_need_ellipse;
	1 / $self->inv_a
}

sub inv_a { # 1 / major semiaxis
	my ($self) = @_;
	(1 - $self->e ** 2) / $self->p
}

sub b { # minor semiaxis
	my ($self) = @_;
	$self->_need_ellipse;
	$self->a * (1 - $self->e ** 2)
}

sub th_inf { # true anomaly at infinity
	my ($self) = @_;
	my $e = $self->e;
	$e > 1 ? acos(-1 / $e) : pi
}

sub T { # orbital period
	my ($self) = @_;
	$self->_need_ellipse;
	2 * pi * sqrt($self->a ** 3 / $self->body->mu)
}

sub pe { # periapsis height
	my ($self) = @_;
	$self->p / (1 + $self->e) - $self->body->radius
}

sub ap { # apoapsis height
	my ($self, $noerr) = @_;
	$noerr or $self->_need_ellipse;
	$self->p / (1 - $self->e) - $self->body->radius
}

sub apses {
	my ($self) = @_;
	$self->e < 1 ? ($self->pe, $self->ap) : ($self->pe)
}

sub commonApsis {
	my ($self, $other) = @_;
	$self->body == $other->body or return;
	my $r = $self->body->radius;
	my @pair = ();
	foreach my $v1 ($self->apses) {
		foreach my $v2 ($other->apses) {
			my $e = error($v1 + $r, $v2 + $r);
			# warn "ERROR ", U($v1), " ", U($v2), " $e\n";
			!@pair || $pair[1] > $e
				and @pair = ($v1, $e);
		}
	}
	# warn "ERROR FINAL ", U($pair[0]), " $pair[1]\n";
	$pair[1] < 1e-3 ? $pair[0] : undef
}

sub otherApsis {
	my ($self, $apsis) = @_;
	$self->e > 1 and return $self->pe;
	error($self->pe, $apsis) > error($self->ap, $apsis) ?
		$self->pe : $self->ap;
}

sub checkHeight {
	my ($self, $h, $die) = @_;
	@_ > 2 or $die = 1;
	my $r = $self->body->radius;
	my $tol = 1e-4;
	my $err = undef;
	if (($h + $r) < ($self->pe  + $r) * (1 - $tol)) {
		$err = U($h) . "m is lower than periapsis (" . U($self->pe) . "m)";
	} elsif ($self->e < 1 && ($h + $r) > ($self->ap + $r) * (1 + $tol)) {
		$err = U($h) . "m is higher than apoapsis (" . U($self->ap) . "m)";
	}
	$err && $die and confess $err;
	!$err
}

sub v { # v from h via vis viva equation
	my ($self, $h) = @_;
	$self->checkHeight($h);
	my $r = $h + $self->body->radius;
	my $vsq = $self->body->mu * (2 / $r - $self->inv_a);
	$vsq >= 0 or confess "can't find v at ", U($h), "m for $self";
	sqrt($vsq)
}

sub vmax {
	my ($self) = @_;
	$self->v($self->pe)
}

sub vmin {
	my ($self) = @_;
	$self->e < 1 ?
		$self->v($self->ap) :
		sqrt(-$self->body->mu * $self->inv_a)
}

sub hohmannTo {
	my ($self, $other, $fromAp, $toAp) = @_;

	UNIVERSAL::isa($other, "KSP::Body") and $other = $other->orbit;

	# warn "HOHMANN ", __PACKAGE__, "\n";
	# warn "\tSELF $self\n\tOTHER $other\n";
	$self->body == $other->body
		or croak "different bodies (" . $self->body->name . ", " . $other->body->name . ")";

	my $com = $self->commonApsis($other);
	if (defined $com) {
		# warn "common apsis in hohmannTo()\n";
		my $oth = $other->otherApsis($com);
		my $trans = $other;
		return ($other, $com, $oth);
	}

	my ($inner, $outer, $innerAp, $outerAp, $swap) = $self->a < $other->a ?
		($self, $other, $fromAp, $toAp, 0) :
		($other, $self, $toAp, $fromAp, 1);
	# warn "\tINNER $inner\n\tOUTER $outer\n\tSWAP $swap\n";

	@_ > 2 or ($innerAp, $outerAp) = (0, 1);
	my $innerh = $innerAp && $inner->e < 1 ? $inner->ap : $inner->pe;
	my $outerh = $outerAp && $outer->e < 1 ? $outer->ap : $outer->pe;

	my $trans = $self->body->orbit(pe => $innerh, ap => $outerh);
	wantarray or return $trans;
	$swap ? ($trans, $outerh, $innerh) : ($trans, $innerh, $outerh)
}

sub desc {
	my ($self, $prev) = @_;
	my $open = $self->e >= 1;
	my @d = ();

	my $tol = 1e-3;

	my $hmax = (1 + $tol) * $self->body->highHeight;

	my $tpe = "???";
	my $tap = "???";
	if ($prev && $prev->body == $self->body) {
		error($self->pe, $prev->pe) > $tol
			and $tpe = "???";
		error($self->ap(1), $prev->ap(1)) > $tol
			and $tap = "???";
	}

	my $wpe = ($self->pe > 0 && $self->pe < $hmax) ? "": "???";
	my $wap = ($self->e >= 1 || $self->ap > 0 && $self->ap < $hmax) ? "": "???";

	push @d, sprintf("$tpe %sm$wpe, %sm/s", U($self->pe), U($self->vmax));

	push @d, $open ?
		sprintf("$tap ???$wap, %sm/s, ????? %.0f??", U($self->vmin), 180 / pi * $self->th_inf) :
		sprintf("$tap %sm$wap, %sm/s", U($self->ap), U($self->vmin));

	$open or push @d, $self->body->system->pretty_interval($self->T);

	my $y = $open ? "U" : $self->e > 0.06 ? "O" : "o";
	"$y:" . $self->body->name . "[ " . join("; ", @d) . " ]"
}

1;

