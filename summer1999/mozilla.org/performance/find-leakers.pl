#!perl -w
#
# The contents of this file are subject to the Netscape Public License
# Version 1.0 (the "NPL"); you may not use this file except in
# compliance with the NPL.  You may obtain a copy of the NPL at
# http://www.mozilla.org/NPL/
#
# Software distributed under the NPL is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the NPL
# for the specific language governing rights and limitations under the
# NPL.
#
# The Initial Developer of this code under the NPL is Netscape
# Communications Corporation.  Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation.  All Rights
# Reserved.
#
# $Id: find-leakers.pl,v 1.1 1999/06/16 08:50:37 waterson%netscape.com Exp $
#
# See http://www.mozilla.org/performance/refcnt-balancer.html for more info.
#

my %allocs;
my $id = 0;

LINE: while (<>) {
    my @fields = split(/ /, $_);
    my $loc = shift(@fields);
    my $obj = shift(@fields);
    my $op  = shift(@fields);
    my $cnt = shift(@fields);

    if ($op eq 'AddRef' && $cnt == 1) {
        $allocs{$obj} = ++$id; # the order of allocation
    }
    elsif ($op eq 'Release' && $cnt == 0) {
        delete($allocs{$obj});
    }
}

foreach $key (keys(%allocs)) {
    print "$key (", $allocs{$key}, ")\n";
}

