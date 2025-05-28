#!/usr/bin/perl -w
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
# 
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
# 
# The Original Code is Waldemar's Perl Utilities.
# 
# The Initial Developer of the Original Code is Netscape Communications
# Corporation.  Portions created by Netscape Communications Corporation are
# Copyright (C) 1999 Netscape Communications Corporation.  All
# Rights Reserved.
# 
# Contributor(s):   Waldemar Horwat <waldemar@acm.org>
#
#
# PostProcessHTML [-p] [-n] [-stylebase dir] [-summarize srcfile -o dstfile] dir ... dir
#
# If -p is given, print progress information.
# If -n is given, don't write the files.
# If -stylebase is given, ensure that references to "styles.css", "unicodeCompatibility.js", and "arrows/....gif"
#   go to the given directory.
# If dir's are given, postprocess all html files in the given directories (including subdirectories).
# If -summarize is given, also coalesce all files referred from srcfile's CONTENTS into the file given by -o.
#

use 5.004;
use strict;
use diagnostics;
use File::Basename;
use Getopt::Long;
use POSIX;
use GeneralUtilities;
use HTMLUtilities;


# Update the modification dates based on the given date
sub updateModDate($@) {
	my $newModDate = shift;
	my $newDateString = formatDate localtime $newModDate;
	my $nDatesFound = 0;
	my $nDatesChanged = 0;
	foreach (@_) {
		if ((/^<ADDRESS[>\s]/i ... /^<\/ADDRESS>/i) ||
			(/^<P\s.*class\s*=\s*['"]?mod-date['"]?[>\s]/si ... /^<\/P>/i)) {
			if (substr($_, 0, 1) ne "<" &&
				/\b([A-Za-z]+day,\s+[A-Za-z]+\s+\d{1,2},\s+\d{4})\b/i) {
				$nDatesFound++;
				if ($1 ne $newDateString) {
					s/[A-Za-z]+day,\s+[A-Za-z]+\s+\d{1,2},\s+\d{4}/$newDateString/i;
					$nDatesChanged++;
				}
			}
		}
	}
	warning "Found $nDatesFound dates in $currentPathName" if $nDatesFound != 2;
	alertChange "Updated $nDatesChanged dates to $newDateString" if $nDatesChanged;
	return @_;
}


my %prevLinks;  #<full-pathname> -> <full-pathname> of previous page
my %nextLinks;  #<full-pathname> -> <full-pathname> of next page
my %startLinks; #<full-pathname> -> <full-pathname> of contents and start page
my %upLinks;    #<full-pathname> -> <full-pathname> of referring page

my %linkKinds = (
	"Lprev" => \%prevLinks,
	"Lnext" => \%nextLinks,
	"Lstart" => \%startLinks,
	"Lcontents" => \%startLinks,
	"Aleft" => \%prevLinks,
	"Aright" => \%nextLinks,
	"Aup" => \%upLinks);

my %linkMultiples = (
	"Lprev" => 1,
	"Lnext" => 1,
	"Lstart" => 1,
	"Lcontents" => 1,
	"Aleft" => 2,
	"Aright" => 2,
	"Aup" => 2);


# Look up the link of the given kind from the given pathname.  Return the relative link
# as a unix-style relative path or undefined if there is no link given.
sub lookupLink($$) {
	my ($linkKind, $pathName) = @_;
	my $dstPathName = $linkKinds{$linkKind}{$pathName};
	return undef if !defined $dstPathName;
	return pathDifference $pathName, $dstPathName;
}



# Given a list of runs of an index file, update the %prevLinks, %nextLinks, %startLinks and
# %upLinks hash tables based on the file's contents between the CONTENTS and /CONTENTS
# or DOWN and /DOWN HTML comments.
sub readTableOfContents($@) {
	my $pathName = shift;

	my $prev = $pathName;
	foreach (@_) {
		if (/^<!--\s*CONTENTS\s*-->/ ... /^<!--\s*\/CONTENTS\s*-->/) {
			if (/^<A\s+href="([^"<>\/][^"<>]*\.html)">$/) {
				my $ref = pathSum $pathName, $1;
				print "# CONTENTS: $ref\n" if $verbose;
				if (defined $prev) {
					updateHash %nextLinks, $prev, $ref;
					updateHash %prevLinks, $ref, $prev;
					updateHash %startLinks, $ref, $pathName;
					updateHash %upLinks, $ref, $pathName;
				}
				$prev = $ref;
			}
		}
		if (/^<!--\s*DOWN\s*-->/ ... /^<!--\s*\/DOWN\s*-->/) {
			if (/^<A\s+href="([^"<>\/][^"<>]*\.html)">$/) {
				my $ref = pathSum $pathName, $1;
				print "# DOWN: $ref\n" if $verbose;
				updateHash %upLinks, $ref, $pathName;
			}
		}
	}
	return @_;
}


# Update a file's links and arrow-image anchors based on the %prevLinks, %nextLinks, %startLinks and
# %upLinks values.
sub updateLinks($@) {
	my $pathName = shift;
	if ($pathName !~ /-old\.html$/) {
		my $nLinks = 0;
	
		foreach (@_) {
			if (my ($pre, $linkKind, $href, $post) = /^(<LINK\s+rel=['"]?(Start|Contents|Prev|Next)['"]?\s+href=")([^"<>]*)("[>\s].*)$/is) {
				$nLinks++;
				$linkKind = lc $linkKind;
				my $newHRef = lookupLink "L".$linkKind, $pathName;
				if (!defined $newHRef) {
					warning "No $linkKind link specified from $pathName";
				} elsif ($newHRef ne $href) {
					$_ = $pre . $newHRef . $post;
					alertChange "Updated $linkKind link from \"$href\" to \"$newHRef\"";
				}
			}
			last if $_ eq "<BODY>";
		}
		
		my $i = 0;
		my $limit = scalar(@_) - 2;
		while ($i < $limit) {
			if (my ($pre, $href, $post) = $_[$i] =~ /^(<A\s+href=")([^"<>]*)("[>\s].*)$/is and
				my ($arrowKind) = $_[$i+1] =~ /^<IMG\s+src="[^"<>]*arrows\/([^"<>\/]*)\.gif"/is and
				uc $_[$i+2] eq "</A>") {
				$nLinks++;
				my $newHRef = lookupLink "A".$arrowKind, $pathName;
				if (!defined $newHRef) {
					warning "No $arrowKind arrow link specified from $pathName";
				} elsif ($newHRef ne $href) {
					$_[$i] = $pre . $newHRef . $post;
					alertChange "Updated $arrowKind arrow link from \"$href\" to \"$newHRef\"";
				}
			}
			$i++;
		}
	
		my $nLinksExpected = 0;
		while (my ($linkKind, $links) = each %linkKinds) {
			$nLinksExpected += $linkMultiples{$linkKind} if defined $$links{$pathName};
		}
	
		warning "Expected $nLinksExpected and found $nLinks links in $pathName" if $nLinks != $nLinksExpected;
	}
	return @_;
}


# Update a file's style and arrow-image links to point to entries in the $styleDirectory directory.
sub updateStyleLinks($$@) {
	my $pathName = shift;
	my $styleDirectory = shift;

	foreach (@_) {
		my ($pre, $href, $hrefFile, $post);
		if (($pre, $href, $hrefFile, $post) = /^(<LINK\s.*href=")((?:[^"<>]*\/)?([^"<>\/]+))("[>\s].*)$/is) {
			if ($hrefFile eq "styles.css") {
				my $newHRef = pathDifference $pathName, $styleDirectory . $hrefFile;
				if ($newHRef ne $href) {
					$_ = $pre . $newHRef . $post;
					alertChange "Updated link from \"$href\" to \"$newHRef\"";
				}
			} else {
				warning "Local style sheet reference in $_" if $hrefFile !~ /\.html$/;
			}
		}
		if (($pre, $href, $hrefFile, $post) = /^(<SCRIPT\s.*src=")((?:[^"<>]*\/)?([^"<>\/]+))("[>\s].*)$/is) {
			if ($hrefFile eq "unicodeCompatibility.js") {
				my $newHRef = pathDifference $pathName, $styleDirectory . $hrefFile;
				if ($newHRef ne $href) {
					$_ = $pre . $newHRef . $post;
					alertChange "Updated script reference from \"$href\" to \"$newHRef\"";
				}
			} else {
				warning "Local script reference in $_";
			}
		}
		if (($pre, $href, $hrefFile, $post) = /^(<IMG\s.*src=")((?:[^"<>]*\/)?arrows\/([^"<>\/]+))("[>\s].*)$/is) {
			my $newHRef = pathDifference($pathName, $styleDirectory . "arrows") . "/" . $hrefFile;
			if ($newHRef ne $href) {
				$_ = $pre . $newHRef . $post;
				alertChange "Updated image reference from \"$href\" to \"$newHRef\"";
			}
		}
	}
	return @_;
}


my %noWrapDirectories; # Hash table of directory -> list of files to not be wrapped in that directory

# Record the file in %noWrapDirectories if it contains any LINK, SCRIPT, or STYLE in its head section.
sub recordNoWrap($@) {
	my $pathName = shift;
	if ($pathName !~ /-old\.html$/) {
		foreach (@_) {
			if (/^<(LINK|SCRIPT|STYLE)[>\s]/is) {
				my ($srcName, $srcPath) = fileparse $pathName;
				push @{$noWrapDirectories{$srcPath}}, $srcName;
				last;
			}
			last if $_ eq "<BODY>";
		}
	}
	return @_;
}


# Return the NOWRAP file in the given directory as a list.  Return the empty list if there
# is no NOWRAP file there.  Also initialize $changed and $currentPathName.
sub readNoWrap($) {
	my ($path) = @_;

	$changed = 0;
	$currentPathName = $path . "NOWRAP";
	return () unless -f $currentPathName;
	open NOWRAPFILE, "<".$currentPathName or die $^E;
	my @noWrapFiles;
	while (<NOWRAPFILE>) {
		if (/^\s*([^:\/\n\r]+)\s*$/) {
			push @noWrapFiles, $1;
		} else {
			die "Bad NOWRAP line: $_";
		}
	}
	close NOWRAPFILE or die $^E;
	return @noWrapFiles;
}


# Ensure that all entries in %noWrapDirectories are present in NOWRAP files.  Update the NOWRAP files
# as appropriate.
sub processNoWrapRequests() {
	while (my ($path, $requiredNoWrapFiles) = each %noWrapDirectories) {
		# print "$path:  ", join(", ", @$requiredNoWrapFiles), "\n";
		my @oldNoWrapFiles = readNoWrap($path);
		my %newNoWrapFiles = listToHash @oldNoWrapFiles;
		foreach (@oldNoWrapFiles) {
			unless (-f $path.$_) {
				alertChange "Removed $_";
				delete $newNoWrapFiles{$_};
			}
		}
		foreach (@$requiredNoWrapFiles) {
			unless ($newNoWrapFiles{$_}) {
				$newNoWrapFiles{$_} = 1;
				alertChange "Added $_";
			}
		}
		my @newNoWrapFiles = sort keys %newNoWrapFiles;
		alertChange "Sorted files" unless $changed || arrayEq @oldNoWrapFiles, @newNoWrapFiles;
		if ($changed) {
			if ($noSet) {
				print STDERR "***** File $currentPathName not written due to -n\n";
			} else {
				backUpFile $currentPathName if -f $currentPathName;
				open DSTFILE, ">".$currentPathName or die $^E;
				foreach (@newNoWrapFiles) {
					print DSTFILE $_, "\n";
				}
				close DSTFILE or die $^E;
			}
		}
	}
}

my $styleDirectory;

# Process the input file with the given name and contents.
sub processInputFile($\@) {
	my ($f, $runs) = @_;
	cleanAttributes @$runs;
	closeTags @$runs;
	warnOfEmptyElements @$runs;
	warnOfSpaces @$runs;
	recordNoWrap $f, @$runs;
	readTableOfContents $f, @$runs if $indexFiles{basename $f};
	my $fileModDate = (stat $f)[9] or die $^E;
	updateModDate $fileModDate, @$runs;
	updateLinks $f, @$runs;
	updateStyleLinks $f, $styleDirectory, @$runs if defined $styleDirectory;
}


# $root must be an absolute path to a directory ending with a directory separator character.
# $path must be an absolute path to a file contained, directly or indirectly, in that directory.
# Return a string consisting of the relative path from $root to $path with directory separators
# replaced by underscores and with the file suffix dropped.
sub pathToRelativeId($$) {
	my ($root, $path) = @_;
	local $_ = $path;
	die "File '$path' is not in '$root'" if index $_, $root, 0;
	$_ = substr $_, length $root;
	s/$sep/_/go;
	s/\..*$//;
	return $_;
}


# Summarize the given list of directories and files into the summarizeFile.
sub summarizeFile($$) {
	my ($summaryRoot, $summaryFile) = @_;
	my @summaryPrefix;
	my @summarySuffix;
	local $_;

	my $summaryRootDirectory = (fileparse $summaryRoot)[1];
	print "#\n# Summarizing '$summaryRootDirectory' into '$summaryFile':\n" if $verbose;
	open SUMMARYFILE, "<".$summaryFile or die $^E;
	do {
		defined($_ = <SUMMARYFILE>) or die "Can't find <!--SUMMARY-->";
		push @summaryPrefix, $_;
	} until (/<!--SUMMARY-->\s*$/);
	do {
		defined($_ = <SUMMARYFILE>) or die "Can't find <!--/SUMMARY-->";
	} until (/<!--\/SUMMARY-->\s*$/);
	push @summarySuffix, $_;
	while (<SUMMARYFILE>) {
		push @summarySuffix, $_;
	}
	close SUMMARYFILE or die $^E;

	if ($noSet) {
		print STDERR "***** File '$summaryFile' not written due to -n\n";
	} else {
		backUpFile $summaryFile;
		open SUMMARYFILE, ">".$summaryFile or die $^E;
		print SUMMARYFILE @summaryPrefix;

		# Accumulate a hash indexed by all files to be summarized in %summaryFiles.
		my %summaryFiles;
		my $f = $summaryRoot;
		while (defined $f) {
			$summaryFiles{$f} = 1;
			$f = $nextLinks{$f};
		}

		$f = $summaryRoot;
		while (defined $f) {
			print "# '$f'\n" if $verbose;
			my @file = fetchFile $f;
			my @runs = parseTags 0, @file;
			my $id = pathToRelativeId $summaryRootDirectory, $f;
			print SUMMARYFILE "\n<HR>\n<A name=\"$id\"></A>\n";

			my $lastHR = $#runs;
			$lastHR-- while $lastHR >= 0 && $runs[$lastHR] ne "<HR>";
			if ($lastHR < 0) {
				warning "Missing <HR> in $f";
			} else {
				my $seenBody = 0;
				for (my $i = 0; $i != $lastHR; $i++) {
					$_ = $runs[$i];
					if (!$seenBody) {
						$seenBody = 1 if /^<BODY>$/i;
					} else {
						my ($pre, $href, $post, $loc, $fragment);
						if (($pre, $href, $post) = /^(<A\s+href=")([^":<>\/][^":<>]*)("[>\s].*)$/is) {
							($loc, $fragment) = split(/#/, $href);
							my $target = pathSum $f, $loc;
							if (defined $summaryFiles{$target}) {
								$href = "#" . pathToRelativeId($summaryRootDirectory, $target);
								$href .= "_$fragment" if defined $fragment;
							} else {
								print "# Outbound link: '$href' => " if $verbose;
								$href = pathDifference $summaryFile, $target;
								$href .= "#$fragment" if defined $fragment;
								print "'$href'\n" if $verbose;
							}
							$_ = $pre . $href . $post;
						} elsif (($pre, $href, $post) = /^(<IMG\s+src=")([^":<>\/#][^":<>#]*)("[>\s].*)$/is) {
							$href = pathDifference $summaryFile, pathSum($f, $href);
							$_ = $pre . $href . $post;
						} elsif (($pre, $fragment, $post) = /^(<A\s+name=")([^"#<>\/]+)("[>\s].*)$/is) {
							$fragment = pathToRelativeId($summaryRootDirectory, $f) . "_$fragment";
							$_ = $pre . $fragment . $post;
						} elsif ($_ eq "<!--NOSUMMARY-->") {
							do {
								$i++;
								die "No matching <!--/NOSUMMARY-->" if ($i == $lastHR);
							} while ($runs[$i] ne "<!--/NOSUMMARY-->");
							next;
						} elsif (/^<!--SUMMARYONLY\s+(.*\S)\s*-->$/s) {
							$_ = $1;
						}
						print SUMMARYFILE $_;
					}
				}
			}
			$f = $nextLinks{$f};
		}

		print SUMMARYFILE "\n", @summarySuffix;
		close SUMMARYFILE or die $^E;
		print "# Wrote '$summaryFile'.\n" if $verbose;
	}
}


my $summaryRoot;
my $summaryFile;

GetOptions("p" => \$verbose, "n" => \$noSet, "stylebase=s" => \$styleDirectory,
		   "summarize=s" => \$summaryRoot, "o=s" => \$summaryFile);

$styleDirectory = addDirectorySuffix pathToAbsolute $styleDirectory if defined $styleDirectory;
processInputFiles \&processInputFile, @ARGV;
if (defined $summaryRoot) {
	die "Need -o option" unless defined $summaryFile;
	summarizeFile(pathToAbsolute $summaryRoot, pathToAbsolute $summaryFile);
}
processNoWrapRequests;
print STDERR "\n***** $nWarnings warnings\n" if $nWarnings;

1;
