#!/usr/bin/perl -w
# Waldemar Horwat
# Netscape

use 5.004;
use strict;
use diagnostics;
use Mac::Files;


# Given a pathname, return the trash folder on the same volume.
# In a list context returns the trash folder and the given pathname's
# dirID, which can be used as an argument to setPutAway.
sub getTrashFolder($) {
	my ($file) = @_;
	my $fileCat = FSpGetCatInfo $file or die $^E;
	my $vRefNum = $fileCat->ioVRefNum;
	my $parID = $fileCat->ioFlParID;
	my $trashFolder = FindFolder $vRefNum, kTrashFolderType, 1 or die $^E;
	$trashFolder .= ":";
	return wantarray ? ($trashFolder, $parID) : $trashFolder;
}


# Set the Finder's put-away directory for the given file.
sub setPutAway($$) {
	my ($file, $parID) = @_;
	my $fileCat = FSpGetCatInfo $file or die $^E;
	my $flXFndrInfo = $fileCat->ioFlXFndrInfo or die $^E;
	$flXFndrInfo->fdPutAway($parID);
	$fileCat->ioFlXFndrInfo($flXFndrInfo);
	FSpSetCatInfo($file, $fileCat) or die $^E;
	return 1;
}

1;
