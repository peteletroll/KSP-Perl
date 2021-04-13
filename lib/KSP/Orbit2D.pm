package KSP::Orbit2D;

use strict;
use warnings;

use Carp;

use Math::Trig;

use TinyStruct qw(body e p);

our %newpar = map { $_ => 1 } qw(p e a pe ap E r v T trace);

our $TRACE = 0;

sub BUILD {
	my ($self, $body, %par) = @_;
	defined $body or croak "missing body";
	ref $body or $body = KSP::Body->get($body);
	$newpar{$_} or croak "unknown orbit parameter $_" foreach keys %par;

	my $trace = delete $par{trace} || $TRACE;
	my $par = \%par;
	my $origpar = _pardesc($par);
	my $r = $body->radius();
	my $mu = $body->mu();

	$trace and warn "START: ", _pardesc($par), "\n";

	if (_defined($par, qw(v r !E))) {
		$par{E} = $par{v} ** 2 / 2 - $mu / $par{r};
		$trace and warn "CMP E: ", _pardesc($par), "\n";
	}

	if (_defined($par, qw(E !a))) {
		if ($par{E}) {
			$par{a} = -$mu / 2 / $par{E};
		} else {
			$par{inv_a} = 0;
		}
		$trace and warn "CMP a: ", _pardesc($par), "\n";
	}

	if (_defined($par, qw(T !a))) {
		$par{a} = ($mu * ($par{T} / 2 / pi) ** 2) ** (1 / 3);
		$trace and warn "CMP a: ", _pardesc($par), "\n";
	}

	if (_defined($par, qw(ap pe !a))) {
		$par{a} = ($par{ap} + $par{pe}) / 2 + $r;
		$trace and warn "CMP a: ", _pardesc($par), "\n";
	}

	if (_defined($par, qw(a !inv_a)) && $par{a}) {
		$par{inv_a} = 1 / $par{a};
		$trace and warn "CMP inv_a: ", _pardesc($par), "\n";
	}

	if (_defined($par, qw(inv_a !a)) && $par{inv_a}) {
		$par{a} = 1 / $par{inv_a};
		$trace and warn "CMP a: ", _pardesc($par), "\n";
	}

	if (_defined($par, qw(a pe !ap))) {
		$par{ap} = 2 * $par{a} - 2 * $r - $par{pe};
		$trace and warn "CMP! ap: ", _pardesc($par), "\n";
	}

	if (_defined($par, qw(a ap !pe))) {
		$par{pe} = 2 * $par{a} - 2 * $r - $par{ap};
		$trace and warn "CMP pe: ", _pardesc($par), "\n";
	}

	if (_defined($par, qw(ap pe !e))) {
		$par{e} = ($par{ap} - $par{pe}) / ($par{ap} + $par{pe} + 2 * $r);
		$trace and warn "CMP e: ", _pardesc($par), "\n";
	}

	_defined($par, qw(!e)) and croak "can't compute e from $origpar";
	my $e = $par{e};

	if (_defined($par, qw(a !p))) {
		$par{p} = $par{a} * (1 - $e * $e);
	}

	_defined($par, qw(!p)) and croak "can't compute p from $origpar";
	my $p = $par{p};

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
	$_[0]->e() < 1 or croak "not allowed for open orbit";
}

sub a { # major semiaxis
	my ($self) = @_;
	$self->_need_ellipse();
	1 / $self->inv_a()
}

sub inv_a { # 1 / major semiaxis
	my ($self) = @_;
	(1 - $self->e() ** 2) / $self->p()
}

sub T { # orbital period
	my ($self) = @_;
	$self->_need_ellipse();
	2 * pi * sqrt($self->a ** 3 / $self->body->mu)
}

sub pe { # periapsis height
	my ($self) = @_;
	$self->p / (1 + $self->e) - $self->body->radius
}

sub ap { # apoapsis height
	my ($self) = @_;
	$self->_need_ellipse();
	$self->p / (1 - $self->e) - $self->body->radius
}

sub v_from_vis_viva {
	my ($self, $h) = @_;
	my $r = $h + $self->body->radius;
	sqrt($self->body->mu * (2 / $r - $self->inv_a))
}

sub vmax {
	my ($self) = @_;
	$self->v_from_vis_viva($self->pe())
}

sub vmin {
	my ($self) = @_;
	$self->e() < 1 ?
		$self->v_from_vis_viva($self->ap()) :
		sqrt(-$self->body->mu() * $self->inv_a())
}

sub desc {
	my ($self) = @_;
	my $open = $self->e() >= 1;
	my @d = ();
	push @d, $self->body->name();
	push @d, sprintf("pe=%g", $self->pe());
	$open or push @d, sprintf("ap=%g", $self->ap());
	push @d, sprintf("vmax=%g", $self->vmax());
	push @d, sprintf("vmin=%g", $self->vmin());
	$open or push @d, "T=" . KSP::Time->new($self->T)->pretty_interval();
	"[" . join(";", @d) . "]"
}

1;

