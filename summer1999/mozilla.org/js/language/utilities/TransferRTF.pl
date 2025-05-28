#!/usr/bin/perl -w
# Waldemar Horwat
# Netscape
#
# TransferRTF <src-file> <dst-file>
# Copy the contents from <src-file> to <dst-file> without altering <dst-file>'s resources.
# <dst-file>'s modification date will be the later of <src-file>'s or <dst-file>'s modification dates.

use 5.004;
use strict;
use diagnostics;


my ($srcFile, $dstFile) = @ARGV;

die "$dstFile doesn't exist" unless -f $dstFile;
my $srcModDate = (stat $srcFile)[9] or die "Can't open $srcFile";
my $dstModDate = (stat $dstFile)[9] or die "Can't open $dstFile";
$dstModDate = $srcModDate if $srcModDate > $dstModDate;
open SRCFILE, "<".$srcFile or die $^E;
my @lines = <SRCFILE>;
close SRCFILE or die $^E;
open DSTFILE, ">".$dstFile or die $^E;
print DSTFILE @lines;
close DSTFILE or die $^E;
utime time, $dstModDate, $dstFile or die $^E;
print "Copied RTF from $srcFile to $dstFile\n";
1;
