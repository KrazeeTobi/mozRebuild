#!/usr/bin/perl -w
# Waldemar Horwat
# Netscape
#
# DeAnchor <src-file> <dst-file>
# Copy the HTML body from <src-file> to <dst-file> while removing all A tags and translating
# all numeric entities above 255 into JavaScripts.  The latter appeases DreamWeaver 2.0, which
# corrupts numeric entities above 255.

use 5.004;
use strict;
use diagnostics;

my ($srcFile, $dstFile) = @ARGV;

open SRCFILE, "<".$srcFile or die $^E;
open DSTFILE, ">".$dstFile or die $^E;
while (<SRCFILE>) {
	s/<\/?A\b[^<>]*>//ig;
	s/&#(?:\d{4,}|[3-9]\d\d|2[6-9]\d|25[6-9]);/<SCRIPT type="text\/javascript">document.write("$&")<\/SCRIPT>/ig;
	print DSTFILE;
}
close SRCFILE or die $^E;
close DSTFILE or die $^E;
print "DeAnchored $srcFile into $dstFile\n";
1;
