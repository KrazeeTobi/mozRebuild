#!/usr/bin/perl -w
# Waldemar Horwat
# Netscape
#
# UpdateModDate <src-file> <dst-file> <delta>
# Update the modification date of <dst-file> to be the same as <src-file> plus <delta> in seconds.

use 5.004;
use strict;
use diagnostics;


my ($srcFile, $dstFile, $delta) = @ARGV;
$delta = 0 unless defined $delta;
my $srcTime = (stat $srcFile)[9] or die "Can't open $srcFile";
my $dstTime = (stat $dstFile)[9] or die "Can't open $dstFile";
$srcTime += $delta;
if ($dstTime != $srcTime) {
	print scalar(localtime $dstTime), " <== ", scalar(localtime $srcTime), ":   $dstFile <== $srcFile\n";
	utime time, $srcTime, $dstFile or die $^E;
}
1;
