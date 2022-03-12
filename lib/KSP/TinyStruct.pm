package KSP::TinyStruct;

use strict;
use warnings;

use Carp;

our $VERSION = '0.01';

use vars qw($print $picky $XS $BASE $FIELDS $FLD);

sub run($);

BEGIN {
	require Exporter;
	use vars qw(@ISA @EXPORT_OK);
	@ISA = qw(Exporter);
	@EXPORT_OK = qw(defstruct);

	$print = 0;
	$picky = 0;

	$FLD = '[a-z_][a-z0-9_]*';

	$XS = eval { require Class::XSAccessor::Array };

	$FIELDS = "_" . uc __PACKAGE__ . "_FIELDS";
	$FIELDS =~ s/[_\W]+/_/gs;

	$BASE = __PACKAGE__ . "::Base";

	no strict 'refs';
	@{"${BASE}::ISA"} = qw(Exporter);
	*{"${BASE}::$FIELDS"} = sub { ( ) };
}

sub import {
	my $pkg = shift;
	if (@_) {
		defstruct((caller(0))[0], @_);
	} else {
		$pkg->export_to_level(1, $pkg, qw(defstruct));
	}
}

sub checkfield($) {
	$_[0] =~ /^$FLD$/io
		and $_[0] ne uc $_[0]
		or croak "bad field name '$_[0]'";
}

sub checkclass($) {
	$_[0] =~ /^$FLD(?:::$FLD)*$/io
		or croak "bad class name '$_[0]'";
}

sub definition {
	my $struct = shift;
	checkclass $struct;
	my @fields = ();
	my @superfields = ();
	my @isa = ();
	foreach (@_) {
		if (/^(\W)(.*)/) {
			if ($1 eq "+") {
				my $super = $2 || $BASE;
				checkclass($super);
				my @f = ();
				{
					no strict 'refs';
					my $m = "${super}::${FIELDS}";
					my $f = \&$m
						or croak "can't inherit from $super: no function $m";
					@f = $f->();
				}
				croak "$super is not a role" if @f && @superfields;
				push @superfields, @f;
				push @isa, $super;
			} else {
				croak "bad definition";
			}
		} else {
			checkfield($_);
			push @fields, $_;
		}
	}

	@isa or push @isa, $BASE;

	my @allfields = (@superfields, @fields);
	my $allfields = @allfields;
	{
		my %f = ();
		foreach (@allfields) {
			$f{$_}++ and croak "duplicated field '$_'";
		}
	}

	my $ret = "package $struct;\n\n";

	$ret .= "use strict;\n";
	$ret .= "use warnings;\n";
	$ret .= "use Carp;\n" if $picky;

	$ret .= "\n";
	$ret .= "use vars qw(\@EXPORT \@EXPORT_OK \%EXPORT_TAGS);\n";
	$ret .= "\@${struct}::ISA = qw(" . join(" ", @isa) . ");\n";

	$ret .= "\n";
	$ret .= "sub $FIELDS() { qw(\n"
		. join("", map { "  $_\n" } @allfields)
		. ") }\n";

	if (@allfields) {
		$ret .= "\n";
		my $idx = 0;
		foreach my $field (@allfields) {
			$ret .= "sub \U$field\E() { $idx }\n";
			$idx++;
		}
	}

	$ret .= "\n";
	$ret .= "sub new {\n";
	$ret .= "  " . __PACKAGE__ . "::install_and_run_constructor(\@_)\n";
	$ret .= "}\n";

	$ret .= "\n";
	$ret .= "sub _new_simple {\n";
	$ret .= "  shift;\n";
	$ret .= "  \@_ <= $allfields or croak \"$struct->new() needs at most $allfields parameters\";\n"
		if $picky;
	$ret .= "  bless [ \@_ ]\n";
	$ret .= "}\n";

	$ret .= "\n";
	$ret .= "sub _new_with_BUILD {\n";
	$ret .= "  shift;\n";
	$ret .= "  (bless [ ])->BUILD(\@_)\n";
	$ret .= "}\n";

	$ret .= "\n";
	$ret .= "sub clone {\n";
	$ret .= "  \@_ == 1 or croak \"$struct->clone() needs no parameters\";\n"
		if $picky;
	$ret .= "  bless [ \@{\$_[0]} ]\n";
	$ret .= "}\n";

	if ($XS && !$picky) {
		if (@allfields) {
			$ret .= "\n";
			$ret .= "use Class::XSAccessor::Array\n";
			$ret .= "  getters => {\n";
			foreach my $field (@allfields) {
				$ret .= "    $field => \U$field\E,\n";
			}
			$ret .= "  },\n";
			$ret .= "  setters => {\n";
			foreach my $field (@fields) {
				$ret .= "    set_$field => \U$field\E,\n";
			}
			$ret .= "  };\n";
		}
	} else {
		my $idx = 0;
		foreach my $field (@allfields) {
			my $id = uc $field;

			$ret .= "\n";
			$ret .= "sub $field {\n";
			$ret .= "  \@_ == 1 or croak \"$struct->$field() needs no parameters\";\n"
				if $picky;
			$ret .= "  \$_[0][$id]\n";
			$ret .= "}\n";
			$ret .= "sub set_$field {\n";
			$ret .= "  \@_ == 2 or croak \"$struct->set_$field() needs one parameter\";\n"
				if $picky;
			$ret .= "  \$_[0][$id] = \$_[1]\n";
			$ret .= "}\n";
			$idx++;
		}
	}

	$ret .= "\n";
	$ret .= "1;\n\n";
}

sub defstruct {
	run definition @_;
	$_[0]
}

sub install_and_run_constructor {
	my $struct = ref($_[0]) || $_[0];
	no strict 'refs';
	no warnings 'redefine';
	my $canBUILD = UNIVERSAL::can($struct, "BUILD") ? 1 : 0;
	*{"${struct}::new"} = $canBUILD ?
		\&{"${struct}::_new_with_BUILD"} :
		\&{"${struct}::_new_simple"};
	goto &{"${struct}::new"};
}

sub run($) {
	my $code = shift;
	local $@;
	my $ret = eval $code;
	my $err = $@;
	if ($err) {
		$err =~ s/\s+$//;
		my $msg = "\n"
			. __PACKAGE__ . ": internal eval error:\n"
			. "#" x 60 . "\n";
		my @l = split /\r?\n/, $code;
		for (my $i = 0; $i < @l; $i++) {
			$msg .= sprintf "%3d %s\n", $i + 1, $l[$i];
		}
		$msg .= "#" x 60 . "\n";
		$msg .= $err . "\n";
		die $msg;
	}

	if ($print) {
		local $| = 1;
		print $code;
	}

	$ret
}

1;

