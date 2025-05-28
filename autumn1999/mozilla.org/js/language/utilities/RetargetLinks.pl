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
# RetargetLinks [-v] [-n] -prefix prefix dir ... dir
#
# All fragments with the given prefix in the given directory must have unique names.
# Retarget all references to these fragments to point to the proper file.
# If -v is given, print progress information.
# If -n is given, don't write the files.
#

use 5.004;
use strict;
use diagnostics;
use File::Basename;
use Getopt::Long;
use POSIX;
use GeneralUtilities;
use HTMLUtilities;

my $verbose = 0;
my $prefix;

my %fragmentFiles;  #<fragment> -> <full-pathname> of defining file

sub scanInputFile($\@) {
	my ($file, $runs) = @_;
	cleanAttributes @$runs;
	foreach (@$runs) {
		if (my ($fragment) = /^<A\s+name="(${prefix}[^"<>#]*)"\s*>$/) {
			if (defined $fragmentFiles{$fragment}) {
				warning "Fragment '$fragment' defined in both '$fragmentFiles{$fragment}' and '$file'";
			} else {
				$fragmentFiles{$fragment} = $file;
			}
		}
	}
}

sub updateInputFile($\@) {
	my ($file, $runs) = @_;
	cleanAttributes @$runs;
	foreach (@$runs) {
		if (my ($oldDstFile, $fragment) = /^<A\s+href="([^"<>#]*)#(${prefix}[^"<>#]*)"\s*>$/) {
			if (defined $fragmentFiles{$fragment}) {
				my $newDstFile = pathDifference $file, $fragmentFiles{$fragment};
				if ($newDstFile ne $oldDstFile) {
					alertChange "Updated link from \"$oldDstFile#$fragment\" to \"$newDstFile#$fragment\"";
					$_ = "<A href=\"$newDstFile#$fragment\">";
				}
			} else {
				warning "Fragment '$oldDstFile#$fragment' not defined in any given file";
			}
		}
	}
}


GetOptions("v" => \$verbose, "n" => \$noSet, "prefix=s" => \$prefix);
print "# Scanning...\n" if $verbose;
processInputFiles \&scanInputFile, @ARGV;
print "# Updating...\n" if $verbose;
processInputFiles \&updateInputFile, @ARGV;
print STDERR "\n***** ", $nWarnings, " warnings\n" if $nWarnings;

1;
