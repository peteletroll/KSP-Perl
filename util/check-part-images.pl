#!/usr/bin/perl

use strict;
use warnings;

use KSP qw(:all);
use KSP::Util qw(Part sortby);

binmode \*STDOUT, ":utf8";

if (1) {
	my $n = 0;
	foreach my $p (sortby { $_->name } Part()) {
		my @i = $p->images;
		@i and next;
		printf "%3d no images for %s\n", ++$n, $p;
	}
}

if (1) {
	my $n = 0;
	my @p = sort keys %{KSP::DB::part_images()};
	foreach my $p (@p) {
		if (Part($p)) {
			# print "FOUND $p\n";
		} else {
			printf "%3d/%-3d no part for %s\n", ++$n, scalar(@p), $p;
		}

	}
}

