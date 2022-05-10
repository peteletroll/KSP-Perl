package KSP::SolarSystem;

use strict;
use warnings;

use KSP;
use KSP::Body;
use KSP::Cache;

use Carp;

use JSON;

use KSP::TinyStruct qw(name json systemG +KSP::Cache);

use overload
	'""' => \&desc;

sub BUILD {
	my ($self, $name) = @_;
	defined $name or $name = "SolarSystemDump";
	$self->set_name($name);
	my $json = "$KSP::KSP_DIR/$name.json";
	open JSONDATA, "<:utf8", $json
		or confess "can't open $json: $!";
	local $/ = undef;
	my $cnt = <JSONDATA>;
	close JSONDATA or die "can't close $json: $!";
	$self->set_json(decode_json($cnt));
	$self
}

sub secs_per_year {
	my ($self) = @_;
	$self->json->{timeUnits}{Year}
}

sub secs_per_day {
	my ($self) = @_;
	$self->json->{timeUnits}{Day}
}

sub G {
	my ($self) = @_;
	my $G = $self->systemG;
	unless ($G) {
		my ($sum, $count) = (0, 0);
		foreach my $b ($self->bodies) {
			my $G = $b->estimated_G;
			$G and $sum += $G, $count++;
		}
		$G = $count ? $sum / $count : 6.67408e-11;
		$self->set_systemG($G);
	}
	$G
}

sub bodies {
	my ($self) = @_;
	my @lst = keys %{$self->json->{bodies}};
	wantarray or return scalar @lst;
	sort { $a->_sortkey <=> $b->_sortkey } map { $self->body($_) } @lst
}

sub bodyPrefixMatchers {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::bodyPrefixMatchers() wants list context";
	$self->cache("bodyPrefixMatchers", sub {
		map { qr/^(\Q$_\E)(.+)/ }
			sort { length $b <=> length $a || $a cmp $b }
			map { $_->name }
			$self->bodies
	})
}

sub body {
	my ($self, $name) = @_;
	ref $self or Carp::confess "no ref here";
	scalar $self->cache("body($name)", sub {
		my $json = $self->json->{bodies}{$name}
			or croak "can't find body \"$name\"";
		KSP::Body->new($json, $self)
	})
}

sub root {
	my ($self) = @_;
	$self->body($self->json->{rootBody})
}

sub import_bodies {
	my ($self) = @_;
	my $tgt = (caller(0))[0];
	defined $tgt or return;
	# warn "BODIES INTO $tgt\n";
	foreach my $body ($self->bodies) {
		my $name = $body->name;
		$name =~ /^\w+$/ or die "bad name \"$name\"";
		no strict "refs";
		*{"${tgt}::$name"} = sub { $body };
	}
}

sub dvGraph {
	my ($self) = @_;
	scalar $self->cache("dvGraph", sub {
		KSP::DeltaVGraph->new($self->name =~ /^real/i);
	})
}

# Time functions

sub _floor($) {
	my ($v) = @_;
	my $r = int $v;
	$r <= $v ? $r : $r - 1
}

sub _mod($$) {
	my ($val, $mod) = @_;
	my $ret = _floor($val / $mod);
	$_[0] = $val - $ret * $mod;
	$ret
}

sub _unpack {
	my ($self, $ut) = @_;

	my $y = _mod($ut, $self->secs_per_year);

	my $d = _mod($ut, $self->secs_per_day);

	my $h = _mod($ut, 3600);
	my $m = _mod($ut, 60);
	my $s = $ut;

	($y, $d, $h, $m, $s)
}

sub _pack {
	my ($self, $y, $d, $h, $m, $s) = @_;

	$y * $self->secs_per_year
		+ ($d || 0) * $self->secs_per_day
		+ ($h || 0) * 3600
		+ ($m || 0) * 60
		+ ($s || 0)
}

sub pretty_date {
	my ($self, $ut) = @_;
	my @t = $self->_unpack($ut);
	$t[0] >= 0 and $t[0]++;
	$t[1]++;
	sprintf "Year %d, Day %d, %d:%02d:%06.3f", @t
}

sub pretty_interval {
	my ($self, $ut, $items) = @_;
	$items ||= 2;

	my $sign = "";
	$ut >= 0 or ($ut, $sign) = (-$ut, "-");

	my ($y, $d, $h, $m, $s) = $self->_unpack($ut);
	my @ret = ();

	if ($y) {
		push @ret, sprintf '%dy', $y;
		@ret < $items or goto end;
	}

	if (@ret || $d) {
		@ret and $ret[-1] .= " ";
		push @ret, sprintf '%dd', $d;
		@ret < $items or goto end;
	}

	if (@ret || $h || $m) {
		@ret and $ret[-1] .= " ";
		push @ret, sprintf '%d:%02d', $h, $m;
		@ret < $items or goto end;
	}

	if (@ret || $s) {
		@ret and $ret[-1] .= ":";
		$s = sprintf(($items - @ret > 1 ? '%5.3f' : '%d'), $s);
		@ret or $s .= "s";
		push @ret, $s;
		@ret < $items or goto end;
	}

	end:
	join("", $sign, @ret)
}

sub desc {
	my ($self) = @_;
	$self->root->tree
}

1;

