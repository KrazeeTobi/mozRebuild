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
# $Id: make-tree.pl,v 1.1 1999/06/16 08:50:38 waterson%netscape.com Exp $
#
# See http://www.mozilla.org/performance/refcnt-balancer.html for more info.
#

use Getopt::Long;

# GetOption will create $opt_object & $opt_exclude, so ignore the
# warning that gets spit out about those vbls.
GetOptions("object=s", "exclude=s", "ignore-balanced");

$opt_object ||
    die "usage: leak.pl --object <obj> [--exclude <file>] [--ignore-balanced]";

warn "object $opt_object\n";
warn "ignoring balanced subtrees\n" if $opt_ignore_balanced;


my %excludes;

if ($opt_exclude) {
    open(EXCLUDE, "<$opt_exclude")
        || die "unable to open $opt_exclude";
    
    while (<EXCLUDE>) {
        chomp $_;
        warn "excluding $_\n";
        $excludes{$_} = 1;
    }
}

my %callgraph;
$callgraph{'.root'} = { 'name' => '.root', 'refcount' => 'n/a' };

LINE: while (<>) {
    chomp;
    my @fields = split(/ /, $_);
    my $loc = shift(@fields);

    my $obj = shift(@fields);
    next LINE unless ($obj eq $opt_object);

    my $op  = shift(@fields);
    my $cnt = shift(@fields);

    # Reverse the remaining fields to produce the call stack, with the
    # oldest frame at the front of the array.
    my @stack = reverse(@fields);
    my $call;

    # If any of the functions in the stack are supposed to be excluded,
    # march on to the next line.
    foreach $call (@stack) {
        next LINE if exists($excludes{$call});
    }


    # Add the callstack as a path through the call graph, updating
    # refcounts at each node.

    my $caller = $callgraph{'.root'};

    foreach $call (@stack) {
        if (! $callgraph{$call}) {
            $callgraph{$call} = { 'name' => $call, 'refcount' => 0 };
        }

        my $site = $callgraph{$call};

        if ($op eq 'AddRef') {
            ++($site->{'refcount'});
        }
        else {
            --($site->{'refcount'});
        }

        $caller->{$call} = $site;
        $caller = $site;
    }
}


my %listed;

sub list {
    my ($site, $nest) = @_;

    return if ($opt_ignore_balanced && !$site->{'refcount'});

    # Indent
    my $i = $nest;
    while ($i-- > 0) {
        print "  ";
    }

    # Payload
    print $site->{'name'}, ": bal=", $site->{'refcount'}, "\n";

    if ($listed{$site}) {
        # If we've already dumped this callsite, then don't recurse.
        return;
    }

    # Mark the site as listed.
    $listed{$site} = 1;

    # Recurse
    CALL: foreach $call (sort(keys(%$site))) {
        next CALL if $call eq 'name';
        next CALL if $call eq 'refcount';

        list ($site->{$call}, $nest + 1);
    }
}



&list($callgraph{'.root'}, 0);

