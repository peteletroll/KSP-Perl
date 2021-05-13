package KSP::ConfigNode;

use strict;
use warnings;

use Carp;

use KSP::TinyStruct qw(name parent values nodes);

use KSP::TinyParser;

use KSP::ConfigValue;

use Scalar::Util qw(weaken isweak);

our $FIXENCODING = 0;

sub BUILD($$) {
	my ($self, $name, @content) = @_;
	$self->set_name($name);
	$_->addTo($self) foreach @content;
	$self
}

sub addTo($$) {
	my ($self, $node) = @_;
	my $l = $node->nodes() || $node->set_nodes([ ]);
	push @$l, $self;
	my $ws = $node;
	$self->set_parent($node);
	weaken($self->parent());
	isweak($self->parent()) or die "not weak parent";
	$self
}

sub load($$) {
	my ($pkg, $file) = @_;
	my $stdin = 0;
	if ($file eq "-") {
		open FILE, "<&:bytes", \*STDIN
			or croak "can't dup STDIN: $!";
		$stdin = 1;
	} else {
		open FILE, "<:bytes", $file
			or croak "can't open $file: $!";
	}
	local $/ = undef;
	my $cnt = <FILE>;
	close FILE or croak "can't close $file: $!";
	unless (utf8::is_utf8($cnt) || utf8::decode($cnt)) {
		warn "warning: $file is not UTF-8, reading as latin-1\n";
		utf8::upgrade($cnt);
		if ($FIXENCODING && !$stdin) {
			warn "warning: recoding $file to UTF-8\n";
			if (open FILE, ">:utf8", $file) {
				print FILE $cnt;
				close FILE or croak "can't close $file: $!";
			}
		}
	}
	my $ret = $pkg->parse_string($cnt);
	$ret
}

sub parse_string($$) {
	my ($pkg, $str) = @_;
	_parser()->parse(start => $str)
}

our $_parser;
sub _parser() {
	$_parser ||= KSP::TinyParser->new(

		_ => qr{([ \t\r\x{feff}]+|(//)[^\n]*)+},

		cr_opt => REP("\n", 0, 999_999),

		start => SEQ(
			\"stmts",
			\"cr_opt",
			FIRST(EOS, ERR("end of file expected")),
			EV{
				KSP::ConfigNode->new("root", @{$_[2][0]})
			},
		),

		stmts => SEQ(
			REP(SEQ(\"cr_opt", \"stmt")),
			EV{
				$_[2][0]
			},
		),

		stmt => SEQ(
			\"lstring",
			FIRST(
				\"assign",
				\"group",
			),
			EV{
				my ($n, $v) = ($_[2][0], $_[2][1]);
				eval { $v->set_name($n) };
				$v
			},
		),

		group => SEQ(
			\"cr_opt",
			"{",
			\"stmts",
			\"cr_opt",
			FIRST("}", ERR("} expected")),
			EV{ KSP::ConfigNode->new(undef, @{$_[2][2]}) }
		),

		assign => SEQ(
			qr{([\+\-\*\/\!\^]?=)}, # this must be coherent with "lstring" regexp
			\"rstring",
			EV{ KSP::ConfigValue->new($_[2][0], undef, $_[2][1]) },
		),

		lstring => SEQ(
			qr{(
				(?:
					[^\n=\{\}\+\-\*\/]+
					|
					\/(?![\/=])
					|
					[\+\-\*\!\^](?!=) # this must be coherent with "assign" regexp
				)*
			)}x,
			EV{
				my $s = $_[2][0];
				$s =~ s/\s+$//;
				_decode($s)
			}
		),
		rstring => SEQ(
			qr{(
				(?:
					[^\n\{\}\/]+
					|
					\/(?!\/)
				)*
			)}x,
			EV{
				my $s = $_[2][0];
				$s =~ s/\s+$//;
				_decode($s)
			}
		),
	)
}

sub _decode($) {
	local $_ = $_[0];
	if (/[\x{0}-\x{8}\x{a}-\x{1f}]/) {
		my $s = $_;
		$s =~ s{([\x{0}-\x{1f}])}{ sprintf "\\x{%x}", ord($1) }ges;
		warn "BUGGED \"$s\"\n";
	}
	s/\^\^|\x{a8}\x{a8}/\n/gs;
	s/\\u([0-9a-f]{4})/ chr(hex($1)) /geis;
	$_
}

sub asString($) {
	my ($self) = @_;
	my $ret = "";
	open OUT, ">:utf8", \$ret or die;
	my $prev = select OUT;
	$self->_print("", "");
	select $prev;
	close OUT or die;
	$ret
}

sub print($$) {
	my ($self, $stream) = @_;
	$stream ||= \*STDOUT;
	my $prev = select $stream;
	$self->_print("", "");
	select $prev;
	$self
}

sub _print($$$) {
	my ($self, $indent, $prefix) = @_;

	my $v = $self->values();
	if ($v) {
		foreach (@$v) {
			my $s = $_->asString();
			my $c = $_->_comment();
			if (defined $c) {
				if ($c =~ /\n/) {
					my $i = " " x (length($s) + 1);
					# die "value comment can't contain newline";
					$c =~ s/\n/\n$indent$i\/\/ /gm;
				}
				$c = " // $c";
			} else {
				$c = "";
			}
			print "$indent$s$c\n";
		}
	}

	my $n = $self->nodes();
	if ($n) {
		my $newprefix = $prefix;
		length $newprefix and $newprefix .= ":";
		foreach (@$n) {
			my $c = $_->_comment();
			if (defined $c) {
				$c =~ s/^/$indent\t\/\/ /gm;
				$c .= "\n\n";
			} else {
				$c = "";
			}
			my $n = _encode($_->name());
			my $p = $n . $_->_nodename();
			print "$indent$n // $newprefix$p\n", $indent, "{\n$c";
			$_->_print("$indent\t", "$newprefix$p");
			print $indent, "}\n";
		}
	}
}

sub list($$) {
	my ($self, $stream) = @_;
	$stream ||= \*STDOUT;
	my $prev = select $stream;
	$self->_list("");
	select $prev;
	$self
}

sub _list($$) {
	my ($self, $prefix) = @_;

	my $v = $self->values();
	if ($v) {
		foreach (@$v) {
			print $prefix, $_->asString, "\n";
		}
	}

	my $n = $self->nodes();
	if ($n) {
		foreach (@$n) {
			my $n = _encode($_->name());
			my $p = $n . $_->_nodename();
			print "$prefix$p\n";
			$_->_list("$prefix$p:", "");
		}
	}
}

sub _getnode($$) {
	my ($self, $name) = @_;
	_elt($self->nodes(), $name);
}

sub _getvalue($$) {
	my ($self, $name) = @_;
	_elt($self->values(), $name)
}

sub _elt($$) {
	my ($list, $name) = @_;
	$list or return;
	my @ret = grep {
		# warn "CHECK $name ", $_->name(), "\n";
		($_->name() || "") eq $name
	} @$list;
	# warn "FOUND ", scalar(@ret), "\n";
	wantarray ? @ret : $ret[0]
}

sub _nodename($) {
	my ($self) = @_;
	foreach my $f (qw(name id title part type Name Type)) {
		# my $c = $self->{$f};
		my $c = $self->_getvalue($f);
		defined $c and return "[$f" . $c->op() . _encode($c->value) . "]";
	}
	""
}

sub _val($$$) {
	@_ == 3 or croak "bad _val() parameters";
	my ($self, $name, $default) = @_;
	my $v = $self->_getvalue($name);
	$v ? $v->value() : $default
}

sub _comment($$) {
	my ($self) = @_;
	my $name = $self->name();
	# warn "_COMMENT(", dump($name), ", ", dump($value), ")\n";
	if ($name eq "VESSEL" && $self->_val("type", "") eq "Debris") {
		my $sit = lc $self->_val("sit", "unknown");
		my @parts = $self->_getnode("PART");
		my $mass = 0;
		foreach my $p (@parts) {
			my $m = $p->_getvalue("mass");
			$m and $mass += $m->value();
		}
		sprintf "$sit debris %d parts %1.3ft", scalar(@parts), $mass
	} elsif ($name eq "MODULE") {
		my $modname = $self->_val("name", "");
		if ($modname eq "ModuleDataTransmitter") {
			my $ps = $self->_val("packetSize", 0);
			if ($ps > 0) {
				my $pc = $self->_val("packetResourceCost", 0);
				my $r = $self->_val("antennaPower", 0);
				sprintf "%1.3f E/Mip, %1.1e m", $pc / $ps, $r
			} else {
				undef
			}
		} else {
			undef
		}
	} elsif ($name eq "ROSTER") {
		my @k = $self->_getnode("KERBAL");
		my %stat = ();
		foreach my $k (@k) {
			$k->_val("type", "") eq "Crew" or next;
			my $key = join ", ", map { $k->_val($_, "UNK") } qw(trait);
			$stat{$key}++;
			$key = join ", ", map { $k->_val($_, "UNK") } qw(trait gender);
			$stat{$key}++;
		}
		join "\n", "Active kerbals:",
			map { sprintf "%3d: %s", $stat{$_}, $_ } sort keys %stat
	} elsif ($name eq "PART") {
		my $p = $self->parent();
		if ($p && $p->name() eq "VESSEL") {
			# warn "PART in VESSEL\n";
			my @p = $p->_getnode("PART");
			for (my $i = 0; $i < @p; $i++) {
				$p[$i] == $self or next;
				return "vessel index: $i";
			}
		}
	} elsif ($name eq "TechTree") {
		my @n = $self->_getnode("RDNode");
		my $t = 0;
		foreach my $n (@n) {
			my $c = $n->_getvalue("cost");
			$c and $t += $c->value();
		}
		return sprintf("%d nodes, %d science points", scalar(@n), $t);
	} else {
		undef
	}
}

sub _encode($) {
	local $_ = $_[0];
	ref $_ and confess "unhandled ref $_";
	s/\n/\^\^/gs;
	s/^([{}])/ _uescape($1) /ges;
	s/^(\s)/ _uescape($1) /ges;
	s/(\s)$/ _uescape($1) /ges;
	$_
}

sub _uescape($) {
	local ($_) = @_;
	s/(.)/ sprintf "\\u%04x", ord($1) /ges;
	$_
}

1;

