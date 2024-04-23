package KSP::SolarSystem;

use strict;
use warnings;

use POSIX qw(floor);

use KSP;
use KSP::Body;
use KSP::Cache;
use KSP::Util qw(filekey);

use Carp;

use JSON;

use KSP::TinyStruct qw(name json grav_const +KSP::Cache);

use overload
	'""' => sub { $_[0]->desc };

our %LOAD = ();
our $loading = 0;

sub load {
	my ($pkg, $json) = @_;
	defined $json or $json = "SolarSystemDump";
	$json =~ /\.\w+$/ or $json = "$json.json";
	$json =~ /\// or $json = "$KSP::KSP_DIR/$json";
	my $key = filekey($json);
	local $loading = 1;
	$LOAD{$key} ||= __PACKAGE__->new($json)
}

sub BUILD {
	my ($self, $json) = @_;

	$loading or confess __PACKAGE__, "->new() without load()";

	my $name = $json;
	$name =~ s/.*\///;
	$name =~ s/\.\w+$//;

	open JSONDATA, "<:utf8", $json
		or confess "can't open $json: $!";
	local $/ = undef;
	my $cnt = <JSONDATA>;
	close JSONDATA or die "can't close $json: $!";

	$self->set_name($name);
	$self->set_json(decode_json($cnt));
	$self->set_grav_const(6.67430e-11);
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

sub G { $_[0]->grav_const }

sub g0 { $_[0]->json->{g0} } # "g0": 9.80665,

sub bodies {
	my ($self, $unsorted) = @_;
	my @lst = keys %{$self->json->{bodies}};
	wantarray or return scalar @lst;
	@lst = map { $self->body($_) } @lst;
	$unsorted and return @lst;
	sort { $a->_sortkey <=> $b->_sortkey } @lst
}

sub situationPrefixMatchers {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::situationPrefixMatchers() wants list context";
	$self->cache("situationPrefixMatchers", sub {
		map { qr/^(\Q$_\E)(.*)/ }
			sort { length $b <=> length $a || $a cmp $b }
			keys %{$self->json->{enums}{ExperimentSituations}}
	})
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
	if ($name =~ /^[-+]?\d+$/) {
		my $found = 0;
		foreach my $b ($self->bodies) {
			my $i = $b->index;
			defined $i && $i == $name or next;
			$name = $b->name;
			$found = 1;
			last;
		}
		$found or croak "can't find body $name";
	}
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
	()
}

sub dvGraph {
	my ($self) = @_;
	scalar $self->cache("dvGraph", sub {
		KSP::DeltaVGraph->new($self->name =~ /^real/i);
	})
}

# Time functions

sub _mod($$) {
	my ($val, $mod) = @_;
	my $ret = floor($val / $mod);
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
		$s = sprintf(($items - @ret > 1 ? '%5.3f' : @ret ? '%02d' : '%d'), $s);
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

