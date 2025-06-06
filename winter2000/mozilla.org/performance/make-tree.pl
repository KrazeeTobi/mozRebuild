#!/usr/bin/perl -w
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
# $Id: make-tree.pl,v 1.8 1999/11/16 02:14:49 waterson%netscape.com Exp $
#
# See http://www.mozilla.org/performance/refcnt-balancer.html for more info.
#

use 5.004;
use strict;
use Getopt::Long;

$::opt_prune_depth = 0;
$::opt_subtree_size = 0;
$::opt_reverse = 0;

# GetOption will create $opt_object & $opt_exclude, so ignore the
# warning that gets spit out about those vbls.
GetOptions("object=s", "exclude=s", "ignore-balanced", "subtree-size=i", "prune-depth=i",
            "collapse-to-method", "collapse-to-class", "old-style", "reverse");

$::opt_object ||
     die qq{
usage: leak.pl < logfile
  --object <obj>         The address of the object to examine (required)
  --exclude <file>       Exclude routines listed in <file>
  --ignore-balanced      Ignore balanced subtrees
  --subtree-size <n>     Print subtrees with more than <n> nodes separately
  --prune-depth <depth>  Prune the tree to <depth>
  --collapse-to-method   Aggregate data by method
  --collapse-to-class    Aggregate data by class (subsumes --collapse-to-method)
  --reverse              Reverse call stacks, showing leaves first
  --old-style            Old-style formatting
};

$::opt_prune_depth = 0 if $::opt_prune_depth < 0;
$::opt_subtree_size = 0 if $::opt_subtree_size < 0;

warn "object $::opt_object\n";
warn "ignoring balanced subtrees\n" if $::opt_ignore_balanced;
warn "prune depth $::opt_prune_depth\n" if $::opt_prune_depth;
warn "collapsing to class\n" if $::opt_collapse_to_class;
warn "collapsing to method\n" if $::opt_collapse_to_method && !$::opt_collapse_to_class;
warn "reversing call stacks\n" if $::opt_reverse;


# The 'excludes' are functions that, if detected in a particular call
# stack, will cause the _entire_ call stack to be ignored. You might,
# for example, explicitly exclude two functions that have a matching
# AddRef/Release pair.

my %excludes;

if ($::opt_exclude) {
     open(EXCLUDE, "<".$::opt_exclude)
         || die "unable to open $::opt_exclude";
 
     while (<EXCLUDE>) {
         chomp $_;
         warn "excluding $_\n";
         $excludes{$_} = 1;
     }
}

# Each entry in the tree rooted by callGraphRoot contains the following:
#   #name#      This call's name+offset string
#   #refcount#  The net reference count of this call
#   #label#     The label used for this subtree; only defined for labeled nodes
#   #children#  List of children in alphabetical order
# zero or more children indexed by method name+offset strings.

my $callGraphRoot;
$callGraphRoot = { '#name#' => '.root', '#refcount#' => 'n/a' };

# The 'imbalance' is a gross count of how balanced a particular
# callsite is. It is used to prune away callsites that are detected to
# be balanced; that is, that have matching AddRef/Release() pairs.

my %imbalance;
$imbalance{'.root'} = 'n/a';


# The main read loop.

LINE: while (<>) {
     next LINE if (! /^</);
     my @fields = split(/ /, $_);

     my $class = shift(@fields);
     my $obj   = shift(@fields);
     my $sno   = shift(@fields);
     next LINE unless ($obj eq $::opt_object);

     my $op  = shift(@fields);
     next LINE unless ($op eq "AddRef" || $op eq "Release");

     my $cnt = shift(@fields);

     # Collect the remaining lines to create a stack trace.
     my @stack;
     CALLSITE: while (<>) {
         chomp;
         last CALLSITE if (/^$/);
         $stack[++$#stack] = $_;
     }

     # Reverse the remaining fields to produce the call stack, with the
     # oldest frame at the front of the array.
     if (! $::opt_reverse) {
         @stack = reverse(@stack);
     }

     my $call;

     # If any of the functions in the stack are supposed to be excluded,
     # march on to the next line.
     foreach $call (@stack) {
         next LINE if exists($excludes{$call});
     }


     # Add the callstack as a path through the call graph, updating
     # refcounts at each node.

     my $caller = $callGraphRoot;

     foreach $call (@stack) {

         # Chop the method offset if we're 'collapsing to method' or
         # 'collapsing to class'.
         $call =~ s/\+0x.*$//g if ($::opt_collapse_to_method || $::opt_collapse_to_class);

         # Chop the method name if we're 'collapsing to class'.
         $call =~ s/::.*$//g if ($::opt_collapse_to_class);

         my $site = $caller->{$call};
         if (!$site) {
             # This is the first time we've seen this callsite. Add a
             # new entry to the call tree.

             $site = { '#name#' => $call, '#refcount#' => 0 };
             $caller->{$call} = $site;
         }

         if ($op eq 'AddRef') {
             ++($site->{'#refcount#'});
             ++($imbalance{$call});
         } elsif ($op eq 'Release') {
             --($site->{'#refcount#'});
             --($imbalance{$call});
         } else {
             die "Bad operation $op";
         }

         $caller = $site;
     }
}


# Given a subtree and its nesting level, return true if that subtree should be pruned.
# If it shouldn't be pruned, destructively attempt to prune its children.
# Also compute the #children# properties of unpruned nodes.
sub prune($$) {
     my ($site, $nest) = @_;

     # If they want us to prune the tree's depth, do so here.
     return 1 if ($::opt_prune_depth && $nest >= $::opt_prune_depth);

     # If the subtree is balanced, ignore it.
     return 1 if ($::opt_ignore_balanced && !$site->{'#refcount#'});

     my $name = $site->{'#name#'};

     # If the symbol isn't imbalanced, then prune here (and warn)
     if ($::opt_ignore_balanced && !$imbalance{$name}) {
         warn "discarding " . $name . "\n";
#         return 1;
     }

     my @children;
     foreach my $child (sort(keys(%$site))) {
         if (substr($child, 0, 1) ne '#') {
             if (prune($site->{$child}, $nest + 1)) {
                 delete $site->{$child};
             } else {
                 push @children, $site->{$child};
             }
         }
     }
     $site->{'#children#'} = \@children;
     return 0;
}


# Compute the #label# properties of this subtree.
# Return the subtree's number of nodes, not counting nodes reachable 
# through a labeled node.
sub createLabels($) {
     my ($site) = @_;
     my @children = @{$site->{'#children#'}};
     my $nChildren = @children;
     my $nDescendants = 0;

     foreach my $child (@children) {
         my $childDescendants = createLabels($child);
         if ($nChildren > 1 && $childDescendants > $::opt_subtree_size) {
             die "Internal error" if defined($child->{'#label#'});
             $child->{'#label#'} = "__label__";
             $childDescendants = 1;
         }
         $nDescendants += $childDescendants;
     }
     return $nDescendants + 1;
}


my $nextLabel = 0;
my @labeledSubtrees;

sub list($$$$$) {
     my ($site, $nest, $nestStr, $childrenLeft, $root) = @_;
     my $label = !$root && $site->{'#label#'};

     # Assign a unique number to the label.
     if ($label) {
         die unless $label eq "__label__";
         $label = "__" . ++$nextLabel . "__";
         $site->{'#label#'} = $label;
         push @labeledSubtrees, $site;
     }

     print $nestStr;
     if ($::opt_old_style) {
         print $label, " " if $label;
         print $site->{'#name#'}, ": bal=", $site->{'#refcount#'}, "\n";
     } else {
         my $refcount = $site->{'#refcount#'};
         my $l = 8 - length $refcount;
         $l = 1 if $l < 1;
         print $refcount, " " x $l;
         print $label, " " if $label;
         print $site->{'#name#'}, "\n";
     }

     $nestStr .= $childrenLeft && !$::opt_old_style ? "| " : "  ";
     if (!$label) {
         my @children = @{$site->{'#children#'}};
         $childrenLeft = @children;
         foreach my $child (@children) {
             $childrenLeft--;
             list($child, $nest + 1, $nestStr, $childrenLeft);
         }
     }
}


if (!prune($callGraphRoot, 0)) {
     createLabels $callGraphRoot if ($::opt_subtree_size);
     list $callGraphRoot, 0, "", 0, 1;
     while (@labeledSubtrees) {
         my $labeledSubtree = shift @labeledSubtrees;
         print "\n------------------------------\n", 
$labeledSubtree->{'#label#'}, "\n";
         list $labeledSubtree, 0, "", 0, 1;
     }
     print "\n------------------------------\n" if @labeledSubtrees;
}

print qq{
Imbalance
---------
};

foreach my $call (sort(keys(%imbalance))) {
     print $call . " " . $imbalance{$call} . "\n";
}

