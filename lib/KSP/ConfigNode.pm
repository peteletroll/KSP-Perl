package KSP::ConfigNode;

use strict;
use warnings;

use Carp;

use KSP::TinyStruct qw(src name parent _values _nodes);

use KSP::TinyParser;

use KSP::ConfigValue;

use KSP::Util qw(U isnumber matcher);

use Scalar::Util qw(weaken isweak refaddr);

use overload
	bool => sub { $_[0] },
	'==' => sub { refaddr($_[0]) == (refaddr($_[1]) || 0) },
	'!=' => sub { refaddr($_[0]) != (refaddr($_[1]) || 0) },
	'""' => sub { $_[0]->asString(1) };

our $FIXENCODING = 0;

our $PUTCOMMENTS = 1;

sub BUILD($$) {
	my ($self, $name, @content) = @_;
	$self->set_name($name);
	$_->addTo($self) foreach @content;
	$self
}

sub addTo {
	my ($self, $node) = @_;
	my $l = $node->_nodes() || $node->set__nodes([ ]);
	push @$l, $self;
	my $ws = $node;
	$self->set_parent($node);
	weaken($self->parent());
	isweak($self->parent()) or die "not weak parent";
	$self
}

sub gulp {
	my $self = shift;
	# warn "GULP INTO " . $self->name . "\n";
	foreach my $node (@_) {
		ref $node or next;
		$_->addTo($self) foreach $node->values, $node->nodes;
	}
	$self
}

sub load {
	my ($pkg, $file) = @_;

	my $mayrecode = 0;
	my $IN = undef;
	if ($file eq "-") {
		$IN = \*STDIN;
	} elsif ($file =~ /\.gz$/) {
		require IO::Uncompress::Gunzip;
		$IN = IO::Uncompress::Gunzip->new($file, -transparent => 0)
			or die "IO::Uncompress::Gunzip failed: $IO::Uncompress::Gunzip::GunzipError\n";;
	} else {
		open $IN, "<:bytes", $file
			or croak "can't open $file: $!";
		$mayrecode = 1;
	}

	local $/ = undef;
	my $cnt = <$IN>;
	close $IN or croak "can't close $file: $!";

	unless (utf8::is_utf8($cnt) || utf8::decode($cnt)) {
		warn "warning: $file is not UTF-8, reading as latin-1\n";
		utf8::upgrade($cnt);
		if ($FIXENCODING && $mayrecode) {
			warn "warning: recoding $file to UTF-8\n";
			if (open FILE, ">:utf8", $file) {
				print FILE $cnt;
				close FILE or croak "can't close $file: $!";
			}
		}
	}

	local $KSP::TinyParser::CONTEXT = $file;
	my $ret = $pkg->parse_string($cnt);
	$ret
}

sub get {
	my ($self, $name, $default) = @_;
	my @ret = map { $_->value } _elt($self->_values(), $name);
	defined $default && !@ret and push @ret, $default;
	wantarray ? @ret : $ret[0]
}

sub del {
	my ($self, $name) = @_;
	$self->set__values([
		grep { $_->name ne $name } $self->values()
	]);
	$self
}

sub values {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::values() wants list context";
	my $v = $self->_values;
	$v ? @$v : ()
}

sub nodes {
	my ($self) = @_;
	wantarray or croak __PACKAGE__, "::nodes() wants list context";
	my $n = $self->_nodes;
	$n ? @$n : ()
}

sub stat {
	my ($self) = @_;
	my ($nodes, $values) = (0, 0);
	$self->visit(sub {
		$nodes++;
		my $v = $_->_values;
		$v and $values += scalar @$v;
	});
	+{ nodes => $nodes, values => $values }
}

sub set {
	my ($self, $name, @values) = @_;
	my $v = $self->_values;
	@$v = grep { $_->name ne $name } @$v if $v;
	foreach $v (@values) {
		KSP::ConfigValue->new("=", $name, $v)->addTo($self);
	}
	$self
}

sub visit {
	my ($self, $sub) = @_;
	local $_ = $self;
	$sub->();
	my $n = $self->_nodes or return;
	$_->visit($sub) foreach @$n;
}

sub getnodes {
	my ($self, $name, $valname, $value) = @_;
	$_ = matcher($_) foreach $name, $valname, $value;
	my @ret = ();
	foreach ($self->nodes) {
		if ($name) {
			defined $_->name && $_->name =~ $name
				or next;
		}
		if ($valname) {
			my $found = undef;
			foreach my $v ($_->values) {
				$v->name =~ $valname or next;
				$value and ($v->value =~ $value or next);
				$found = $v;
				last;
			}
			$found or next;
		}
		push @ret, $_;
	}
	wantarray ? @ret : $ret[0]
}

sub find {
	my ($self, $name, $valname, $value) = @_;
	$_ = matcher($_) foreach $name, $valname, $value;
	my @ret = ();
	$self->visit(sub {
		if ($name) {
			$_->name =~ $name or return;
		}
		if ($valname || $value) {
			my $found = undef;
			foreach my $v ($_->values) {
				$valname and ($v->name =~ $valname or next);
				$value and ($v->value =~ $value or next);
				$found = $v;
				last;
			}
			$found or return;
		}
		push @ret, $_;
	});
	wantarray ? @ret : $ret[0]
}

sub delete {
	my ($self) = @_;
	my $parent = $self->parent;
	$_ = undef foreach @$self;
	if ($parent && $parent->_nodes) {
		$parent->set__nodes([
			grep { $_ != $self }
			@{$parent->_nodes}
		]);
	}
}

sub save {
	my ($self, $file, $comments) = @_;
	open FILE, ">:utf8", $file
		or croak "can't open $file: $!";
	local $KSP::ConfigNode::PUTCOMMENTS = $comments;
	print FILE $self, "\n"
		or croak "can't write to $file: $!";
	close FILE
		or croak "can't close $file: $!";
	1
}

sub parse_string {
	my ($pkg, $str) = @_;
	_parser()->parse(start => $str)
}

our $_parser;
our $COMMENT = qr{//[^\n]*};
our $CR_OPT = qr/(?:\s+|$COMMENT)*/s;
our $LSTRING = qr{$CR_OPT(
	(?:
		:(?:\/\/)?
		|
		[^\n=\{\}\+\-\*\/:]+
		|
		\/(?![\/=])
		|
		[\+\-\*\!\^](?!=) # this must be coherent with "assign" regexp
	)*
)}x;

sub _parser() {
	$_parser ||= KSP::TinyParser->new(

		_ => qr{(?:[ \t\r\x{feff}]+|$COMMENT)+},

		start => SEQ(
			\"stmts",
			$CR_OPT,
			FIRST(EOS, ERR("end of file expected")),
			EV{
				KSP::ConfigNode->new("root", @{$_[2][0]})
			},
		),

		stmts => REP(\"stmt"),

		stmt => SEQ(
			$LSTRING,
			FIRST(
				\"assign",
				\"group",
			),
			EV{
				my ($n, $v) = ($_[2][0], $_[2][1]);
				$n =~ s/\s+$//;
				$v->set_name(_decode($n));
				$v
			},
		),

		group => SEQ(
			qr/$CR_OPT\{/,
			\"stmts",
			FIRST(qr/$CR_OPT\}/, ERR("} expected")),
			EV{ KSP::ConfigNode->new(undef, @{$_[2][1]}) }
		),

		assign => SEQ(
			qr{([\+\-\*\/\!\^]?=)}, # this must be coherent with $LSTRING regexp
			qr{(
				(?:
					[^\n\{\}\/]+
					|
					\/(?!\/)
				)*
			)}x,
			EV{
				my $v = $_[2][1];
				$v =~ s/\s+$//;
				$v = _decode($v);
				isnumber($v) and $v = $v + 0;
				KSP::ConfigValue->new($_[2][0], undef, $v)
			}
		),
	)
}

sub _decode($) {
	local $_ = $_[0];
	s/\^\^|\x{a8}\x{a8}/\n/gs;
	s/\\u([0-9A-Fa-f]{4})/ chr(hex($1)) /geis;
	$_
}

sub isEmpty($) {
	my ($self) = @_;
	my @cnt = ($self->nodes, $self->values);
	!@cnt
}

sub asString($;$) {
	my ($self, $rootflag) = @_;
	my $ret = "";
	open OUT, ">:utf8", \$ret or die;
	$self->print(\*OUT, $rootflag);
	close OUT or die;
	utf8::decode($ret);
	$ret
}

sub print($$;$) {
	my ($self, $stream, $rootflag) = @_;
	my $start = $self;
	if ($rootflag) {
		my $root = KSP::ConfigNode->new("printroot");
		$root->set__nodes([ $self ]); # don't mess with parent
		$start = $root;
	}
	$stream ||= \*STDOUT;
	my $prev = select $stream;
	$start->_print("", "");
	select $prev;
	$self
}

sub _print($$$) {
	my ($self, $indent, $prefix) = @_;

	my $isfirst = 0;
	foreach ($self->values) {
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

		$isfirst++ and print "\n";
		print "$indent$s$c";
	}

	my $newprefix = $prefix;
	length $newprefix and $newprefix .= ":";
	foreach ($self->nodes) {
		my $c = $_->_comment();
		if (defined $c && $c =~ /\S/) {
			$c =~ s/^/$indent\t\/\/ /gm;
			$c = "$c\n\n";
		} else {
			$c = "";
		}
		my $n = _encode($_->name());
		my $p = $n . $_->_nodename();
		$isfirst++ and print "\n";
		print "$indent$n";
		print " // $newprefix$p" if $PUTCOMMENTS;
		print "\n", $indent, "{\n$c";
		$_->_print("$indent\t", "$newprefix$p");
		print "\n" unless $_->isEmpty;
		print $indent, "}";
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

	print $prefix, $_->asString, "\n" foreach $self->values;

	foreach ($self->nodes) {
		my $n = _encode($_->name());
		my $p = $n . $_->_nodename();
		print "$prefix$p\n";
		$_->_list("$prefix$p:", "");
	}
}

sub _getnode($$) {
	my ($self, $name) = @_;
	_elt($self->_nodes(), $name);
}

sub _getvalue($$) {
	my ($self, $name) = @_;
	_elt($self->_values(), $name)
}

sub _elt($$) {
	my ($list, $name) = @_;
	$list or return;
	$name = matcher($name);
	my @ret = $name ?
		(grep {
			# warn "CHECK $name ", $_->name(), "\n";
			($_->name() || "") =~ $name
		} @$list) :
		@$list;
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
	$PUTCOMMENTS or return undef;
	my $name = $self->name();
	# warn "_COMMENT(", dump($name), ", ", dump($value), ")\n";
	if ($name eq "VESSEL" && $self->_val("type", "") eq "Debris") {
		my $sit = lc $self->_val("sit", "unknown");
		my @parts = $self->_getnode("PART");
		my $dryMass = 0;
		my $wetMass = 0;
		foreach my $p (@parts) {
			$p = KSP::Part->new("PART", $p);
			$dryMass += $p->dryMass;
			$wetMass += $p->wetMass;
		}
		sprintf "$sit debris %d parts %sg / %sg", scalar(@parts),
			U(1000 * $wetMass), U(1000 * $dryMass);
	} elsif ($name eq "MODULE") {
		my $modname = $self->_val("name", "");
		if ($modname eq "ModuleDataTransmitter") {
			my $ps = $self->_val("packetSize", 0);
			if ($ps > 0) {
				my $pc = $self->_val("packetResourceCost", 0);
				my $r = $self->_val("antennaPower", 0);
				sprintf "%1.3f E/Mip, %sm", $pc / $ps, U $r
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
			$key = join ", ", map { $k->_val($_, "UNK") } qw(trait state);
			$stat{$key}++;
			$key = join ", ", map { $k->_val($_, "UNK") } qw(trait state gender);
			$stat{$key}++;
		}
		join "\n", "Active kerbals:",
			map { sprintf "%3d: %s", $stat{$_}, $_ } sort keys %stat
	} elsif ($name eq "PART") {
		my $p = $self->parent();
		if ($p && $p->name() eq "VESSEL") {
			# warn "PART in VESSEL\n";
			my @p = $p->_getnode("PART");
			my $n = @p;
			for (my $i = 0; $i < $n; $i++) {
				$p[$i] == $self or next;
				return "vessel index: $i/$n";
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

