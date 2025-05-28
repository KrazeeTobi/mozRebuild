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

package HTMLUtilities;
use 5.004;
use strict;
use diagnostics;
use File::Basename;
use GeneralUtilities;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter);
@EXPORT = qw($verbose $currentPathName $changed $nWarnings %indexFiles alertChange warning fetchFile parseTags cleanAttributes closeTags
			 warnOfEmptyElements decodeTag warnOfSpaces listInputFiles processInputFiles);
@EXPORT_OK = qw($printElementHierarchy);

use vars qw($verbose $currentPathName $changed $nWarnings $printElementHierarchy %indexFiles);
$verbose = 0;
$nWarnings = 0;

$printElementHierarchy = 0; # Set to print the hierarchy of the elements in the file


# Files that are to be examined before other files in the same directory.
%indexFiles = ("index.html" => -10, "futures.html" => -9);


# Elements with no end tags
my %singletonElements = listToHash "AREA", "BASE", "BASEFONT", "BR", "COL", "FRAME", "HR", "IMG", "INPUT",
	"ISINDEX", "LINK", "META", "PARAM";

my @inlineElementList = ("TT", "I", "B", "U", "S", "STRIKE", "BIG", "SMALL", "EM", "STRONG", "DFN", "CODE",
	"SAMP", "KBD", "VAR", "CITE", "ABBR", "ACRONYM", "A", "IMG", "APPLET", "OBJECT", "FONT", "BASEFONT", "BR", "SCRIPT",
	"MAP", "Q", "SUB", "SUP", "SPAN", "BDO", "IFRAME", "INPUT", "SELECT", "TEXTAREA", "LABEL", "BUTTON");
my %inlineElements = listToHash @inlineElementList;
my %flowElements = listToHash "P", "H1", "H2", "H3", "H4", "H5", "H6", "UL", "OL", "DIR", "MENU", "PRE", "DL",
	"DIV", "CENTER", "NOSCRIPT", "NOFRAMES", "BLOCKQUOTE", "FORM", "ISINDEX", "HR", 
	"TABLE", "FIELDSET", "ADDRESS", @inlineElementList;
my %trElement = listToHash "TR";
my %possiblyEmptyElements = listToHash "A", "BODY", "SCRIPT", "TD", "TH";
my %okToRemoveEmptyElements = listToHash "TT", "I", "B", "U", "S", "STRIKE", "BIG", "SMALL", "EM", "STRONG", "DFN", "CODE",
	"SAMP", "KBD", "VAR", "CITE", "ABBR", "ACRONYM", "FONT", "SCRIPT", "SUB", "SUP", "SPAN",
	"P", "H1", "H2", "H3", "H4", "H5", "H6", "DIV";
my %okToRemoveSpacesInside = listToHash "P", "H1", "H2", "H3", "H4", "H5", "H6", "UL", "OL", "DIR", "MENU", "DL",
	"DIV", "TABLE", "ADDRESS", "TD", "TH", "TR", "LI";
my %okToRemoveSpacesAround = listToHash "BR", "HR";

# Elements with optional end tags.  The values are hash-lists of allowed nested tags.
my %selfTerminatingElements = (
	COLGROUP => {listToHash("COL")},
	DD => \%flowElements,
	DT => \%inlineElements,
	HEAD => {listToHash "TITLE", "ISINDEX", "BASE", "SCRIPT", "STYLE", "META", "LINK", "OBJECT"},
	HTML => {listToHash "HEAD", "BODY"},
	LI => \%flowElements,
	OPTION => {},
	P => \%inlineElements,
	TBODY => \%trElement,
	TFOOT => \%trElement,
	THEAD => \%trElement,
	TD => \%flowElements,
	TH => \%flowElements,
	TR => {listToHash "TD", "TH"});

# Attributes whose values should always be quoted.
my %alwaysQuotedAttributes = listToHash "alt", "href", "name";


sub alertChange(@) {
	print STDERR "\nIn '$currentPathName':\n" unless $changed;
	$changed = 1;
	print STDERR @_, "\n";
}


sub warning(@) {
	print STDERR "***** WARNING: ", @_, "\n";
	$nWarnings++;
}


# Read a file with the given file or path name.  Strip trailing whitespace from each line.
# Return the file as a list of lines.
sub fetchFile($) {
	($currentPathName) = @_;
	
	$changed = 0;
	open SRCFILE, "<".$currentPathName or die "Cannot open '$currentPathName'";

	my $nModifiedLines = 0;
	my @lines;
	local $_;
	while (<SRCFILE>) {
		$nModifiedLines += s/[ \t]+$//;
		push @lines, $_;
	}
	close SRCFILE or die $^E;
	alertChange "Removed trailing whitespace on $nModifiedLines lines" if $nModifiedLines;
	return @lines;
}


# Given a list of lines, each ending with a newline except maybe the last, parse
# it into a list of runs.  Each run is either plain text or an HTML comment,
# tag (opening or closing), or directive.  Return the list of runs.
# If $replaceQuots is true, replace &quot; with " except inside scripts or tags.
sub parseTags($@) {
	my $replaceQuots = shift;
	my @runs;
	my $textRun = "";
	my $nQuots;
	local $_ = "";
	while (1) {
		my $pos = index $_, "<";
		if ($pos == -1) {
			$textRun .= $_;
			$_ = shift || last;
		} else {
			$textRun .= substr $_, 0, $pos;
			$_ = substr $_, $pos;
			if ($textRun ne "") {
				die "> should be &gt; in: ", $textRun if index($textRun, ">") != -1;
				$nQuots += $textRun =~ s/&quot;/"/gs if $replaceQuots;
				push @runs, $textRun;
				$textRun = "";
			}
			
			my $markup;
			while (1) {
				if (($markup) = /^(<(?:![ \t]*--.*?--[ \t]*|\/?[:0-9A-Za-z]+[^<>]*|![0-9A-Za-z\[][^<>]*)>)/s) {
					push @runs, $markup;
					$_ = substr $_, length $markup;
					last;
				} elsif (/^<(?:![ \t]*--|\/?[:0-9A-Za-z]+|![0-9A-Za-z\[])/) {
					$_ .= shift || die "Unterminated tag: $_";
				} else {
					die "Unknown markup: $_";
				}
			}
			
			if ($markup =~ /^<SCRIPT/i) {
				while (($pos = index $_, "</") == -1) {
					$textRun .= $_;
					$_ = shift || die "Unterminated script: ", $textRun, $_;
				}
				$textRun .= substr $_, 0, $pos;
				if ($textRun ne "") {
					die "Script shouldn't begin with a < in: ", $textRun if substr($textRun, 0, 1) eq "<" and substr($textRun, 1, 1) ne "!";
					push @runs, $textRun;
					$textRun = "";
				}
				$_ = substr $_, $pos;
			}
		}
	}
	if ($textRun ne "") {
		die "> should be &gt; in: ", $textRun if index($textRun, ">") != -1;
		$nQuots += $textRun =~ s/&quot;/"/gs if $replaceQuots;
		push @runs, $textRun;
		$textRun = "";
	}
	alertChange "Replaced $nQuots occurrences of &quot; with double quotes" if $nQuots;
	return @runs;
}


# Given a list of runs, convert attributes in each tag to a canonical format:
#   Tag names in upper case;
#   Attribute names in lower case;
#   Attribute values quoted with double quotes unless consist only of alphanumerics or _ or -;
#   Attributes separated by one space
# Return the list of runs, which is modified in place.
sub cleanAttributes(@) {
	my $nModifiedTags = 0;
	foreach (@_) {
		if (/^<[\/:0-9A-Za-z]/ && !/^<\/?[:0-9A-Z]+( [-:a-z]+(=([-0-9A-Za-z]+|"[^<>"]*[^-0-9A-Za-z<>"][^<>"]*"))?)*>/) {
			my ($tagName,$args) = /^<(\/?[:0-9A-Za-z]+)([^<>]*?)\s*>$/ or die "Bad attributes: ", $_;
			$tagName = uc $tagName;
			my $newTag = "<" . $tagName;
			while ($args ne "") {
				my ($key, $value, $rest) = $args =~ /^\s+([-:0-9A-Za-z]+)(?:\s*=\s*([-0-9A-Za-z._]+|'[^<>']*'|"[^<>"]*"))?(.*)$/s
					or die "Bad attributes ($args) in: ", $_;
				$key = lc $key;
				$newTag .= " " . $key;
				if (defined $value) {
					if ($value =~ /^'(.*)'$/s) {
						$value = $1;
						$value =~ s/"/&quot;/g;
					}
					elsif ($value =~ /^"(.*)"$/s) {$value = $1;}
					$value = '"'.$value.'"' if $value !~ /^[-0-9A-Za-z]+$/ || $alwaysQuotedAttributes{$key};
					$newTag .= "=".$value;
				}
				$args = $rest;
			}
			$newTag .= ">";
			if ($_ ne $newTag) {
				$nModifiedTags++;
				$_ = $newTag;
			}
		}
	}
	alertChange "Reformatted $nModifiedTags tags" if $nModifiedTags;
	return @_;
}


# Given a list of runs, insert all optional closing tags.
# Return the list of runs, which is modified in place.
sub closeTags(\@) {
	my ($runs) = @_;
	my @stack;	# Tags opened but not yet closed
	my $i;
	my %insertedTags;

	my $addClosingTag = sub {
		my ($closingTagName) = @_;
		my $closingTag = "</" . $closingTagName . ">";
		if ($i && $$runs[$i-1] =~ /^(.*?)(\s+)$/s) {
			if ($1 eq "") {
				splice @$runs, $i-1, 0, $closingTag;
				$i++;
			} else {
				splice @$runs, $i-1, 1, $1, $closingTag, $2;
				$i += 2;
			}
		} else {
			splice @$runs, $i, 0, $closingTag;
			$i++;
		}
		$insertedTags{$closingTag} = 1;
	};

	for ($i = 0; $i <= $#$runs; $i++) {
		if ($$runs[$i] =~ /^<(\/?)([0-9A-Za-z]+)/) {
			my $isClose = $1;
			my $tagName = $2;
			if ($isClose) {
				while (1) {
					my $prevTag = pop @stack or die "Closing tag without opening tag: ", $$runs[$i];
					last if $prevTag eq $tagName;
					die "Tag $$runs[$i] trying to close $prevTag" unless $selfTerminatingElements{$prevTag};
					$addClosingTag->($prevTag);
				}
				print "  "x@stack, "/$tagName\n" if $printElementHierarchy;
			} else {
				while (@stack) {
					my $allowedChildren = $selfTerminatingElements{$stack[$#stack]};
					last unless $allowedChildren && !$$allowedChildren{$tagName};
					$addClosingTag->(pop @stack);
				}
				print "  "x@stack, $tagName, "\n" if $printElementHierarchy;
				push @stack, $tagName unless $singletonElements{$tagName};
			}
		}
	}
	while (@stack) {
		my $prevTag = pop @stack;
		die "Unclosed tag: ", $prevTag unless $selfTerminatingElements{$prevTag};
		$addClosingTag->($prevTag);
	}
	alertChange "Inserted tags ", join ", ", sort keys %insertedTags if %insertedTags;
	return @$runs;
}


# Given a list of runs, warn about empty elements that do not appear in %possiblyEmptyElements.
# Remove empty elements that appear in %okToRemoveEmptyElements.
sub warnOfEmptyElements(\@) {
	my ($runs) = @_;
	my $i;
	my $currentTag = "";
	my $blank;
	my $line = 1;
	local $_;

	for ($i = 0; $i <= $#$runs; $i++) {
		$_ = $$runs[$i];
		if (/^<(\/?)([0-9A-Za-z]+)/) {
			if ($1) {
				if ($currentTag eq $2 && !$possiblyEmptyElements{$currentTag}) {
					if (!$blank && $okToRemoveEmptyElements{$currentTag}) {
						alertChange "Removed empty tag $currentTag on line $line";
						splice @$runs, $i-1, 2;
						$i -= 2;
					} else {
						warning $blank ? "Blank" : "Empty", " tag $currentTag on line $line in $currentPathName";
					}
				}
				$currentTag = "";
			} else {
				$currentTag = $2;
				$blank = 0;
			}
		} elsif (/^\s*$/) {
			$blank = 1;
		} else {
			$currentTag = "";
		}
		$line++ while (/\n/g);
	}
	return @$runs;
}


# If the $i-th element of $runs is an opening or closing tag, return a list consisting of:
#   either "" or "/" depending on whether the tag opens or closes;
#   the name of the tag.
# If not, return a list consisting of "?" and "".
sub decodeTag(\@$) {
	my ($runs, $i) = @_;
	if ($i >= 0 && $i <= $#$runs && $$runs[$i] =~ /^<(\/?)([0-9A-Za-z]+)/) {
		return ($1, $2);
	}
	return ("?", "");
}


# Given a list of runs, warn about spaces after opening tags or before closing tags.
# Remove spaces after opening tags or before closing tags that appear in %okToRemoveSpacesInside.
# Remove spaces before or after tags that appear in %okToRemoveSpacesAround.
sub warnOfSpaces(\@) {
	my ($runs) = @_;
	my $i;
	my $prevSlash;
	my $prevTag;
	my $nextSlash;
	my $nextTag;
	my $nonBlank;
	my $line = 1;
	local $_;

	for ($i = 0; $i <= $#$runs; $i++) {
		$_ = $$runs[$i];
		if (/^[ \t]+$/) {
			($prevSlash, $prevTag) = decodeTag @$runs, $i-1;
			($nextSlash, $nextTag) = decodeTag @$runs, $i+1;
			if ($prevSlash eq "" && ($okToRemoveSpacesInside{$prevTag} || $okToRemoveSpacesAround{$prevTag})) {
				alertChange "Removed spaces after tag $$runs[$i-1] on line $line";
				splice @$runs, $i, 1;
				$_ = "";
				$i--;
			} elsif ($nextSlash eq "" ? $okToRemoveSpacesAround{$nextTag} : $okToRemoveSpacesInside{$nextTag}) {
				alertChange "Removed spaces before tag $$runs[$i+1] on line $line";
				splice @$runs, $i, 1;
				$_ = "";
				$i--;
			} elsif ($prevSlash eq "" || $nextSlash eq "/") {
				warning "Extra spaces on line $line in $currentPathName: '$$runs[$i-1]','$_','$$runs[$i+1]'";
			}
		} else {
			if (($nonBlank) = /^[ \t]+([^ \t].*)$/s) {
				($prevSlash, $prevTag) = decodeTag @$runs, $i-1;
				if ($prevSlash eq "" && ($okToRemoveSpacesInside{$prevTag} || $okToRemoveSpacesAround{$prevTag})) {
					alertChange "Removed spaces after tag $$runs[$i-1] on line $line";
					$$runs[$i] = $nonBlank;
					$_ = $nonBlank;
				} elsif ($prevSlash eq "") {
					warning "Extra spaces on line $line in $currentPathName: '$$runs[$i-1]','$_'";
				}
			}
			if (($nonBlank) = /^(.*\S)[ \t]+$/s) {
				($nextSlash, $nextTag) = decodeTag @$runs, $i+1;
				if ($nextSlash eq "" ? $okToRemoveSpacesAround{$nextTag} : $okToRemoveSpacesInside{$nextTag}) {
					alertChange "Removed spaces before tag $$runs[$i+1] on line $line";
					$$runs[$i] = $nonBlank;
					$_ = $nonBlank;
				} elsif ($nextSlash eq "/") {
					warning "Extra spaces on line $line in $currentPathName: '$_','$$runs[$i+1]'";
				}
			}
		}
		$line++ while (/\n/g);
	}
	return @$runs;
}


sub orderPaths {
	my ($aName, $aDir) = fileparse $a;
	my ($bName, $bDir) = fileparse $b;
	if ($aDir ne $bDir) {
		$aDir =~ s|$sep|\01|go;
		$bDir =~ s|$sep|\01|go;
	}
	return $aDir cmp $bDir
		|| ($indexFiles{$aName} || 0) <=> ($indexFiles{$bName} || 0)
		|| $aName cmp $bName;
}

# Given a list of directories and/or files (which must have proper case, even on case-insensitive
# file systems), return a list of the input HTML files' absolute pathnames.
sub listInputFiles(@) {
	my @dirs = map {pathToAbsolute $_} @_;
	return sort orderPaths findFiles "html", @dirs;
}

# Given a list of directories and/or files (which must have proper case, even on case-insensitive
# file systems), call fun for each HTML file in the list.  fun takes two arguments: the name of the file
# and a reference to the list of its runs.  If the file has been changed, write it back out to disk.
sub processInputFiles(&@) {
	my $fun = shift;
	warning "Nothing to do" unless @_;
	foreach (listInputFiles @_) {
		print "# '$_'\n" if $verbose;
		my @file = fetchFile $_;
		my @runs = parseTags 1, @file;
		if ($runs[0] =~ /^<!DOCTYPE\s/i) {
			&$fun($_, \@runs);
			if ($changed) {
				updateFile $_, 60, @runs;
			}
		} else {
			warning "File $_ ignored because it doesn't start with <!DOCTYPE";
		}
	}
}

1;
