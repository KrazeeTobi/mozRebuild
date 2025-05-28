#!/usr/bin/perl -w
# Waldemar Horwat
# Netscape
#
# UpdateModDates <suffix> <src-tree> <dst-tree>
# Update the modification date of every file in <src-tree> with the given <suffix> to
# be the same as the corresponding file in <dst-tree>.

use 5.004;
use strict;
use diagnostics;
use Cwd;
use File::Basename;
use File::Find;


# Find all files in the given directory (including subdirectories) with the given suffix.
# Return a list of the files' full pathnames.
sub findFiles($$) {
    my ($dirName, $suffix) = @_;

	my @files;
	find(sub {push @files, $File::Find::name if (/\.$suffix$/)}, $dirName);
	return @files;
}


# Convert the given pathname to an absolute pathname.
# (Mac-specific)
sub pathToAbsolute($) {
	($_) = @_;
	$_ = ":".$_ if index($_, ':') == -1;
	$_ = cwd . $_ if substr($_, 0, 1) eq ':';
	while (s/:[^:]+::/:/) {}
	return $_;
}


# Replace srcPrefix with dstPrefix in the pathname.
# (Mac-specific)
sub replacePathPrefix($$$) {
	my ($srcPrefix, $dstPrefix, $path) = @_;
	die "Bad prefix $srcPrefix of $path" unless uc substr($path, 0, length $srcPrefix) eq uc $srcPrefix;
	return $dstPrefix . substr($path, length $srcPrefix);
}


my ($suffix, $srcTree, $dstTree) = @ARGV;
$srcTree = pathToAbsolute $srcTree;
$dstTree = pathToAbsolute $dstTree;
foreach (findFiles $dstTree, $suffix) {
	my $src = replacePathPrefix $dstTree, $srcTree, $_;
	if (my $srcTime = (stat $src)[9]) {
		my $dstTime = (stat $_)[9] or die "Can't open $_";
		if ($dstTime != $srcTime) {
			print scalar(localtime $dstTime), " <== ", scalar(localtime $srcTime), ":   $_ <== $src\n";
			utime time, $srcTime, $_ or die $^E;
		}
	} else {
		print STDERR "Can't find $src\n";
	}
}
1;
