package KSP::SolarSystem;

use strict;
use warnings;

use KSP;
use KSP::Body;

use Carp;

use JSON;

use KSP::TinyStruct qw(json systemG);

sub BUILD {
	my ($self, $name) = @_;
	defined $name or $name = "SolarSystemDump";
	my $json = "$KSP::KSP_DIR/$name.json";
	open JSONDATA, "<:utf8", $json
		or confess "can't open $json: $!";
	local $/ = undef;
	my $cnt = <JSONDATA>;
	close JSONDATA or die "can't close $json: $!";
	$self->set_json(decode_json($cnt));
	$self
}

use overload
	'""' => \&desc;

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
		foreach my $b ($self->bodies(1)) {
			my $G = $b->estimated_G;
			$G and $sum += $G, $count++;
		}
		$G = $count ? $sum / $count : 6.67408e-11;
		$self->set_systemG($G);
	}
	$G
}

sub bodies {
	my ($self, $unsorted) = @_;
	wantarray or croak __PACKAGE__, "->bodies() wants list context";
	my @ret = map { KSP::Body->new($_, $self) } values %{$self->json->{bodies}};
	$unsorted ? @ret : sort { $a->_sortkey <=> $b->_sortkey } @ret
}

sub body($$) {
	my ($self, $name) = @_;
	ref $self or Carp::confess "no ref here";
	my $json = $self->json->{bodies}{$name}
		or die "can't find body \"$name\"";
	KSP::Body->new($json, $self)
}

sub root {
	my ($self) = @_;
	$self->body($self->json->{rootBody})
}

sub body_names {
	my ($self) = @_;
	ref $self eq __PACKAGE__ or Carp::confess __PACKAGE__, " needed here";
	wantarray or croak __PACKAGE__, "->body_names() wants list context";
	keys %{$self->json->{bodies}}
}

sub import_bodies {
	my ($self) = @_;
	my $tgt = (caller(0))[0];
	defined $tgt or return;
	# warn "BODIES INTO $tgt\n";
	my $ret = 0;
	foreach ($self->body_names()) {
		/^\w+$/ or die "bad name \"$_\"";
		my $name = $_;
		$ret++;
		no strict "refs";
		my $ret = undef;
		*{"${tgt}::${name}"} = sub { $ret ||= $self->body($name) };
	}
	$ret
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

sub _unpack($) {
	my ($self, $ut) = @_;

	my $y = _mod($ut, $self->secs_per_year);

	my $d = _mod($ut, $self->secs_per_day);

	my $h = _mod($ut, 3600);
	my $m = _mod($ut, 60);
	my $s = $ut;

	($y, $d, $h, $m, $s)
}

sub _pack(@) {
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

sub pretty_interval($) {
	my ($self, $ut) = @_;
	my @t = $self->_unpack($ut);
	# full spec is '%1$dy %2$dd %3$d:%4$02d:%5$06.3f'
	$t[0] ? sprintf '%1$dy %2$dd %3$d:%4$02d', @t :
	$t[1] ? sprintf '%2$dd %3$d:%4$02d:%5$02.0f', @t :
	sprintf '%3$d:%4$02d:%5$06.3f', @t
}

sub desc {
	my ($self) = @_;
	$self->root->tree
}

1;

