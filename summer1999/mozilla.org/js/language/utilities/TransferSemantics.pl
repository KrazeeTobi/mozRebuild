#!/usr/bin/perl -w
# Waldemar Horwat
# Netscape
#
# TransferSemantics <src-file> <dst-file>
# Copy the HTML body from <src-file> to <dst-file> in between the <!--SEMANTICS--> and
# <!--/SEMANTICS--> comments without altering <dst-file>'s resources.
# <dst-file>'s modification date will be the later of <src-file>'s or <dst-file>'s modification dates.

use 5.004;
use strict;
use diagnostics;

# Return true if the two arrays are equal.
sub arrayEq(\@\@) {
	my ($a1, $a2) = @_;
	my $len = scalar @$a1;
	return "" if $len != scalar @$a2;
	for (my $i = 0; $i != $len; $i++) {
		return "" if $$a1[$i] ne $$a2[$i];
	}
	return 1;
}


my ($srcFile, $dstFile) = @ARGV;

die "$dstFile doesn't exist" unless -f $dstFile;
my $srcModDate = (stat $srcFile)[9] or die "Can't open $srcFile";
my $dstModDate = (stat $dstFile)[9] or die "Can't open $dstFile";
$dstModDate = $srcModDate if $srcModDate > $dstModDate;

my @srcLines;
open SRCFILE, "<".$srcFile or die $^E;
do {
	defined($_ = <SRCFILE>) or die "Can't find <BODY>";
} until (/<BODY>\s*$/);
while (1) {
	defined($_ = <SRCFILE>) or die "Can't find </BODY>";
	last if (/^\s*<\/BODY>/);
	push @srcLines, $_;
}
close SRCFILE or die $^E;

my @dstPre;
my @dstSemantics;
my @dstPost;
open DSTFILE, "<".$dstFile or die $^E;
do {
	defined($_ = <DSTFILE>) or die "Can't find <!--SEMANTICS-->";
	push @dstPre, $_;
} until (/<!--SEMANTICS-->\s*$/);
while (1) {
	defined($_ = <DSTFILE>) or die "Can't find <!--/SEMANTICS-->";
	last if (/<!--\/SEMANTICS-->\s*$/);
	push @dstSemantics, $_;
}
push @dstPost, $_;
while (<DSTFILE>) {
	push @dstPost, $_;
}
close DSTFILE or die $^E;

unless (arrayEq @srcLines, @dstSemantics) {
	open DSTFILE, ">".$dstFile or die $^E;
	print DSTFILE @dstPre, @srcLines, @dstPost;
	close DSTFILE or die $^E;
	utime time, $dstModDate, $dstFile or die $^E;
	print "Copied semantics from $srcFile to $dstFile\n";
}
1;
