#!/usr/bin/perl -w
use strict;
use warnings;

use File::Path;
use List::MoreUtils qw(uniq);

our $indexDir = ".legit/index";
our $debug = 0;


sub main() {
	
	if ($ARGV[0] eq "init") {
		if (!-d ".legit") {
			mkdir ".legit";
			mkdir ".legit/index";
			mkdir ".legit/branches";
			#make_branch("master");			
			mkdir ".legit/branches/master";			
			mkdir ".legit/branches/master/snapshots";	
			mkdir ".legit/.branch";				# keep track of current branch
			mkdir ".legit/.commitNum"; 			# keep track of commit number
			set_branch("master");						
			open my $log , ">>", ".legit/log.txt" or die;
			open my $commitFile,  ">>", ".legit/commitNum.txt" or die;
			print $commitFile "0";
			close $log;
			close $commitFile;
			print "Initialized empty legit repository in .legit\n";
		} else {
			print "legit.pl: error: .legit already exists\n";
		}
	} elsif (!-d ".legit") {
		print "legit.pl: error: no .legit directory containing legit repository exists\n";
	} elsif ($ARGV[0] eq "add") {
		add_files(@ARGV[1..$#ARGV]);
	} elsif ($ARGV[0] eq "commit") {
		#my $message = $ARGV[2];
		if ($ARGV[1] eq "-m") {
			commit_index($ARGV[2]);	# only -m option
		} else {
			update_index();
			commit_index($ARGV[3]);	# -a option..
		}
	} elsif ($ARGV[0] eq "log") {
		show_log();
	} elsif ($ARGV[0] eq "show") {
		$ARGV[1] =~ /([0-9]*):(.*)/;
		show_commit($1, $2);
	} elsif ($ARGV[0] eq "rm") {
		my $indexOnly = 0;
		my $force = 0;
		my $startIndex;
		if ($ARGV[1] ne "--force" && $ARGV[1] ne "--cached") { # two arguments
			$startIndex = 1;
		} elsif ($ARGV[1] eq "--force" && $ARGV[2] eq "--cached") { # four arguments
			$force = 1;
			$indexOnly = 1;
			$startIndex = 3;
		} elsif ($ARGV[1] eq "--cached" && $ARGV[2] eq "--force") {
			$force = 1;
			$indexOnly = 1;
			$startIndex = 3;
		} elsif ($ARGV[1] eq "--force") {   #three arguments (rm, --(force|cached), filenames)
			$force = 1;
			$startIndex = 2;
		} else {
			$indexOnly = 1;
			$startIndex = 2;
		}
		remove_file($indexOnly, $force, @ARGV[$startIndex..$#ARGV]);
	} elsif ($ARGV[0] eq "status") {
		my @trackableFiles = getTrackableFiles();
		foreach my $file (sort @trackableFiles) {
			print get_status($file);
		}
	} elsif ($ARGV[0] eq "branch") {
		if (! -e ".legit/.snapshot.0/") {
			die "legit.pl: error: your repository does not have any commits yet\n";
		}

		if ($#ARGV == 0) {
			show_branches();
		} elsif ($#ARGV == 1) {
			make_branch($ARGV[1]);
		} else {
			delete_branch($ARGV[2]);
		}
	} elsif ($ARGV[0] eq "checkout") {
		change_branch($ARGV[1]);
	}
	exit 1;
}

sub get_branch() {
	my $branchFileDirectory = (glob ".legit/\.branch/*")[0]; 
	open my $branchFile, "<", "$branchFileDirectory" or die;
	my $branchName = <$branchFile>;
	close $branchFile;
	return $branchName;
}

sub set_branch {
	my ($branchName) = @_;
	rmtree ".legit/\.branch";
	mkdir ".legit/\.branch";
	open my $branchFile, ">", ".legit/\.branch/$branchName" or die;
	print $branchFile "$branchName";
	close $branchFile;
}

#sub get_current_branch() {
#	$branchName =~ s/.*\///;
#	return $branchName;
#}
sub change_branch {
	my ($targetBranch) = @_;
	my $currentBranch = get_branch();

	if ($currentBranch eq $targetBranch) { 
		die "cant change to same branch \n";
	} elsif (! -d ".legit/branches/$targetBranch") {
		die "legit.pl: error: unknown branch '$targetBranch'\n";
	}

	# Moving files from current branch to the .legit directory
	my $lastSnapshot = get_last_snapshot();
	foreach my $file (glob "**") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if (-e ".legit/$lastSnapshot/$fileName" && 
		!same_file($file, ".legit/$lastSnapshot/$fileName")) {
			print "Not removing $file because it has changed since last commit!\n" if $debug;
			print ".legit/$lastSnapshot/$fileName is different to $file\n" if $debug;
			# If the file in current branch is differnet to its last commit,
			# keep the file ..... why
			copy_file(".legit/$lastSnapshot/$fileName", ".legit/branches/$currentBranch/$fileName");
		} else {
#			print get_status($fileName);
			if (get_status($fileName) ne "$fileName - untracked\n") {
				print "Removing $file from current directory\n" if $debug;
				copy_file($file, ".legit/branches/$currentBranch/$fileName");
				unlink $file;
			} else {
				print "Not removing $file since it is untracked\n" if $debug;
			}
		}
	}

	# Moving snapshots from .legit folder to the branches folder
	my $snapshotDir = ".legit/branches/$currentBranch/snapshots";
	foreach my $snapshot (glob ".legit/\.snapshot*") {
		my $snapshotName = $snapshot;
		$snapshotName =~ s/.*\///;
		copy_files("$snapshot", "$snapshotDir/$snapshotName");
		rmtree $snapshot;
	}

	# Moving snapshots from target branch folder to .legit folder
	$snapshotDir = ".legit/branches/$targetBranch/snapshots";
	foreach my $snapshot (glob "$snapshotDir/\.snapshot*") {
		my $snapshotName = $snapshot;
		$snapshotName =~ s/.*\///;
		copy_files("$snapshot", ".legit/$snapshotName");
		#rmtree "$snapshot";
	} 
	rmtree "$snapshotDir"; #so that snapshots folder isnt copied in the next two steps
	
	foreach my $file (glob ".legit/branches/$targetBranch/*") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if (! -e $fileName) {
			print "Copying $file into user directory as $fileName\n" if $debug;
			copy_file($file, $fileName);
		} else {
			print "Not copying $file into user directory as $fileName\n" if $debug;
		}
		unlink $file;		
	}
	mkdir "$snapshotDir";
	set_branch("$targetBranch");
	print "Switched to branch '$targetBranch'\n";
}	

sub copy_files {
	my ($dir1, $dir2) = @_;
	
	foreach my $file (glob "$dir1/*") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		mkdir "$dir2";
		print "Copying $file into \"$dir2/$fileName\"\n" if $debug;
		copy_file ($file, "$dir2/$fileName");
#		print "Finished copy\n" if $debug;
	}
} 

sub delete_branch {
	my ($branchName) = @_;
	if ($branchName eq "master") {
		print "legit.pl: error: can not delete branch 'master'\n";
	} elsif (! -d ".legit/branches/$branchName") {
		print "legit.pl: error: branch '$branchName' does not exist\n";
	} else {
		rmtree ".legit/branches/$branchName";
		print "Deleted branch '$branchName'\n"; 
	}
}

sub show_branches() {
	my $branchFolder = ".legit/branches";
	
	foreach my $branch (glob "$branchFolder/*") {
		my $branchName = $branch;
		$branchName =~ s/.*\///;
		print "$branchName\n";
	}	
}

sub make_branch {
	my ($branchName) = @_;
	my $branch = ".legit/branches/$branchName";
	if (! -e $branch) { 
		mkdir "$branch";
		mkdir "$branch/snapshots";
		foreach my $snapshot (glob ".legit/\.snapshot*") {
			my $snapshotName = $snapshot;
			$snapshotName =~ s/.*\///;
#			print "entering copy_files\n";
			copy_files($snapshot, "$branch/snapshots/$snapshotName");
#			print "exiting copy_Files\n";
		}		
	} else {
		die "legit.pl: error: branch '$branchName' already exists\n";
	}
	foreach my $file (glob "**") {
		copy_file($file, "$branch/$file");
	}
}

sub getTrackableFiles() {
	my @curDirArray = glob "**";
	my @indexArray = glob ".legit/index/*";
	my $snapshot = get_last_snapshot();;
	my @repoArray = ();
#	my $suffix = 0;
#	while (-e ".legit/$snapshot") {
		my @curSnapshotFiles = glob ".legit/$snapshot/*";
		@repoArray = (@repoArray, @curSnapshotFiles);
#		$suffix++;
#		$snapshot = ".snapshot.$suffix";
#	}
	my @trackableFiles = (@curDirArray, @indexArray, @repoArray);
	@trackableFiles = map {$_ =~ s/\.legit\/index\///; $_} @trackableFiles;
	@trackableFiles = map {$_ =~ s/\.legit\/.snapshot\.[0-9]+\///; $_} @trackableFiles;
	return uniq(@trackableFiles);
}

sub get_status() {
	my ($file) = @_;
	#my @trackedFiles = getTrackableFiles();
	my $oldSnapshot = get_last_snapshot();	
	
	#	foreach my $file (sort @trackedFi
		my $statusString = "$file -";
		if (! -e $file) { 
			if (! -e ".legit/index/$file") {
				$statusString = "$statusString deleted\n";
			} else {
				$statusString = "$statusString file deleted\n";
			}
		} elsif (! -e ".legit/$oldSnapshot/$file" && -e ".legit/index/$file") {
			$statusString = "$statusString added to index\n";
		} elsif (! -e ".legit/index/$file") { #".legit/$oldSnapshot/$file") {
			$statusString = "$statusString untracked\n";
		} elsif (!same_file($file, ".legit/$oldSnapshot/$file")) {
			$statusString = "$statusString file changed,";
			if (same_file($file, ".legit/index/$file")) {
				$statusString = "$statusString changes staged for commit\n";
			} elsif (same_file(".legit/index/$file", ".legit/$oldSnapshot/$file")) {
				# oldSnapshotFile == indexFile, therefore no changes
				$statusString = "$statusString changes not staged for commit\n";
			} else {
				$statusString = "$statusString different changes staged for commit\n";
			}
		} else {
			$statusString = "$statusString same as repo\n";
		}
		return $statusString;
	#}
}



#sub file_exists { 
#	my ($file1) = @_;
#	open FILE1, '<', $file1 or return 0;
#	close FILE1;
#	#open FILE2, '<', $file2 or return 0;
#	#close FILE2;
#	return 1;
#}

sub remove_file {
	my ($indexOnly, $force, @files) = @_;
	my $oldSnapshot = get_last_snapshot();
	foreach my $fileName (@files) {
		my $indexFile = ".legit/index/$fileName";
		if (! -e $indexFile) {
			die "legit.pl: error: '$fileName' is not in the legit repository\n";
		}
	}
	foreach my $fileName (@files) {
		my $indexFile = ".legit/index/$fileName";
		my $repositoryFile = ".legit/$oldSnapshot/$fileName";
		my $currentFile = "$fileName";
		if ($force != 1) {	
			if (-e $repositoryFile && -e $indexFile && -e $currentFile) {
				if (!same_file($indexFile, $repositoryFile) && 
					!same_file($indexFile, $currentFile)) {
					die "legit.pl: error: '$fileName' in index is different to both working file and repository\n";
				}
			}		
			if (-e $indexFile && $indexOnly == 0) {
				if (! -e $repositoryFile) {
					die "legit.pl: error: '$fileName' has changes staged in the index\n";
				} elsif (-e $repositoryFile) {
					if (!same_file($indexFile, $repositoryFile)) {
						die "legit.pl: error: '$fileName' has changes staged in the index\n";
					}
				}
			}
			if (-e $repositoryFile && -e $currentFile && $indexOnly == 0) {
				if (!same_file($repositoryFile, $currentFile)) {
					die "legit.pl: error: '$fileName' in repository is different to working file\n";
				}
			}
		}
		if (! -e $indexFile) {
			die "legit.pl: error: '$fileName' is not in the legit repository\n";		
		}
		if (! -e $currentFile && $indexOnly == 0) {
			die "$currentFile doesnt exist :)\n";
		}
		# Deleting index files first
		unlink $indexFile;
		if ($indexOnly == 0) {
			unlink $currentFile;
		}
	
	}
}

#sub delete_file {
	#my ($file1, $file2, $force) = @_;
	#if ($force == 1) {

sub show_commit() {   #commitID:fileName 
	my ($commitID, $fileName) = @_;
	my $folder;
	my $file;
	if ($commitID !~ /[0-9]+/) {
		$folder = ".legit/index/$fileName";
		open $file, '<', $folder or die "legit.pl: error: '$fileName' not found in index\n";
	} else {
		$folder = ".legit/.snapshot.$commitID/$fileName";
		if (!-d ".legit/.snapshot.$commitID") {die "legit.pl: error: unknown commit '$commitID'\n";}
		open $file, '<', $folder or die "legit.pl: error: '$fileName' not found in commit $commitID\n";
	}
	#print "$folder is folder\n";
	#open $file, '<', $folder or print "legit.pl: error: 'c' not found in;
	print <$file>;
}

sub update_log {    #logs are updated after successful commits
	my ($message) = @_;
	#print "$message is message\n";
	open my $log, '>>', ".legit/log.txt" or die;
	my $numCommits = log_lines();
	$message = "$numCommits $message";
	print $log $message;
	print $log "\n";
	close $log;
}

sub log_lines() {     #how many lines/commits there are in the log
	open my $log, '<', ".legit/log.txt" or die;
	my @lines = <$log>;
	close $log;
	return @lines;
}

sub show_log() {      #prints the contents of the log
	#test log
	open my $log, '<', ".legit/log.txt" or die;
	my @logLines = <$log>;
	foreach my $line (reverse @logLines) {
		print "$line";
	}
	#print "is updated log\n";
	close $log;
}
sub update_index() {  #used to update index for the -a tag in commit
	# $indexDir = ".legit/index";
	foreach my $file (glob "$indexDir/*") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if (!same_file("$file", "$fileName")) {
			unlink $file;
			copy_file("$fileName", "$file");
#			print "Replaced $file\n";
		}
	}
}
	
sub commit_index() {  #commits by creating a new snapshot and transferring files from index
	my ($message) = @_;
#	my $indexDir = ".legit/index";
	my $oldSnapshot = get_last_snapshot();
	my $indexHasChanged = 0;

	# Checks if all files in index exist in old snapshot
	foreach my $indexFile (glob "$indexDir/*") {	#file contains path relative to current directory
		my $fileName = $indexFile;
		$fileName =~ s/.*\///;
		my $oldRepoFile = ".legit/$oldSnapshot/$fileName";
		if (! -e "$oldRepoFile") { 				#if index has changed from last 
			$indexHasChanged = 1;				#snapshot, make new dir
		} elsif (-e "$oldRepoFile") { 				#changed = different no. of files OR
			if (!same_file("$indexFile", "$oldRepoFile")) {	#same file with different contents
				$indexHasChanged = 1;
			}
		}
	}

	# Checks if all files in old snapshot exist in index
	foreach my $oldRepoFile (glob ".legit/$oldSnapshot/*") {
		my $fileName = $oldRepoFile;
		$fileName =~ s/.*\///;
		if (! -e "$indexDir/$fileName") {
			$indexHasChanged = 1;
		}
	}
	
	# Creates new repo/snapshot and then commits all files in index to it
	
	if ($indexHasChanged == 0) {
		die "nothing to commit\n";
	}

	my $newSnapshot = get_new_snapshot();
	#$newSnapshot =~ /\.snapshot\.(.*)/;
	my $commitNum = get_commit_num();
	mkdir ".legit/$newSnapshot";
	foreach my $indexFile (glob "$indexDir/*") {
		my $fileName = $indexFile;
		$fileName =~ s/.*\///;
		copy_file("$indexFile", ".legit/$newSnapshot/$fileName");
	}
	
	print "Committed as commit $commitNum\n"; 
	set_commit_num($commitNum+1);
	update_log($message);
	#return 1;
}

sub get_commit_num() {
	open my $commitFile, "<", ".legit/commitNum.txt" or die;
	my $commitNum = <$commitFile>;
	print "Current commitNum = $commitNum\n" if $debug;
	return $commitNum;
}

sub set_commit_num {
	my ($commitNum) = @_;
	print "Setting commitNum to $commitNum\n" if $debug;
	open my $commitFile, ">", ".legit/commitNum.txt" or die;
	print $commitFile "$commitNum";
}


# Returns 0 if they are not the same file(or if one of the files dont exist), 1 if they are
sub same_file() {
	my ($file1, $file2) = @_;
	open FILE1, '<', $file1 or die;	# if the file doesnt exist in oldSnapshot(FILE2),  
					        # new commit is required. Return 0
	open FILE2, '<', $file2 or die;
	my @lines1 = <FILE1>;
	my @lines2 = <FILE2>;
	close FILE1;
	close FILE2;

	if (@lines1 == @lines2) {
		my $i=0;
		while ($i < $#lines1+1) {
			my $line1 = $lines1[$i]; 
			my $line2 = $lines2[$i];
			if ($line1 ne $line2) {
				#print "$file1 and $file2 do not match!\n";
				return 0;
			}
			$i++;
		} 
	} else {
		return 0;
	}
	return 1;
}

sub get_last_snapshot {
    my $suffix = 0;
    chdir ".legit";
    while (1) {
        my $snapshot_directory = ".snapshot.$suffix";

        if (!-d $snapshot_directory) { # checks if its currently not a directory
            #mkdir $snapshot_directory or die "can not create $snapshot_directory: $!\n";
            #print "Creating snapshot $suffix\n";
            chdir "..";
	    $suffix = $suffix - 1;
	    $snapshot_directory = ".snapshot.$suffix";
            return $snapshot_directory;
        }
        $suffix = $suffix + 1;
    }
}

sub get_new_snapshot { # Copied from Lab08 Sample Solution
    my $suffix = 0;
    chdir ".legit";
    while (1) {
        my $snapshot_directory = ".snapshot.$suffix";

        if (!-d $snapshot_directory) { # checks if its currently not a directory
            #mkdir $snapshot_directory or die "can not create $snapshot_directory: $!\n";
            #print "Creating snapshot $suffix\n";
	    chdir "..";
            return $snapshot_directory;
        }
        $suffix = $suffix + 1;
    }
}

sub add_files {
#        my $indexDir = ".legit/index/";
        my (@files) = @_;
	my $file;
	foreach $file (@files) {
		if (! -e $file && ! -e "$indexDir/$file") {
			die "legit.pl: error: can not open 'non_existent_file'\n";
		} elsif (! -e $file && -e "$indexDir/$file") {
			#wierd subset 0_13 case 
			#if file being added doesnt exist in directory, but exists in index and is added..
			#DELETE it 
			unlink "$indexDir/$file";
		} else {
			copy_file("$file", "$indexDir/$file");
		}
	}
}


sub copy_file { # Copied from Lab08 Sample Solution
    my ($source, $destination) = @_;

    open my $in, '<', $source or die "Cannot open $source: $!";
    open my $out, '>', $destination or die "Cannot open $destination: $!";

    while (my $line = <$in>) {
        print $out $line;
    }
    close $in;
    close $out;
}

main();
