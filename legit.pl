#!/usr/bin/perl -w
use strict;
use warnings;
use File::Path;
use List::MoreUtils qw(uniq);
use Algorithm::Merge qw(merge diff3 traverse_sequences3);

our $log = ".log.txt";
our $legit = ".legit";
our $snapshot = ".snapshot.";
our $branches = "$legit/branches";
our $index = "$legit/index";
our $debug = 0;

our @commands = ("init", "rm", "log", "show", "add", "commit", "status", "branch", "checkout", "merge");
our %commands = map {$_ => 1} @commands;

sub main() {
	 if ($#ARGV == -1) {
		usage("");
	 } elsif (!$commands{$ARGV[0]}) {
		usage("$ARGV[0]");
	 } elsif ($ARGV[0] eq "init") {
		if ($#ARGV != 0) {
			print STDERR "usage: legit.pl init\n";
			exit 1;
		}
		if (!-d "$legit") {
			mkdir "$legit";
			mkdir "$index";
			mkdir "$branches";	
			mkdir "$branches/master";			
			mkdir "$branches/master/.snapshots";	
			mkdir "$legit/.branch";				# keep track of current branch
			mkdir "$legit/.commitNum"; 			# keep track of commit number
			set_branch("master");						
			open my $log , ">>", "$legit/$log" or die;
			open my $commitFile,  ">>", "$legit/commitNum.txt" or die;
			print $commitFile "0";
			close $log;
			close $commitFile;
			print "Initialized empty legit repository in $legit\n";
		} else {
			print STDERR "legit.pl: error: $legit already exists\n";
			exit 1;
		}
	} elsif (!-d "$legit" && $commands{$ARGV[0]}) {
		print STDERR "legit.pl: error: no $legit directory containing legit repository exists\n";
		exit 1;
	} elsif ($ARGV[0] eq "add") {
		add_files(@ARGV[1..$#ARGV]);
	} elsif ($ARGV[0] eq "commit") {
		if ($#ARGV < 1) {
			usage_commit();
		} elsif ($ARGV[1] eq "-m") {
			if ($#ARGV == 1) {
				print STDERR "legit.pl: error: empty commit message\n";
				exit 1;
			} elsif ($#ARGV != 2) { 
				usage_commit();
			} 
			commit_index($ARGV[2]);	# only -m option
		} elsif ($ARGV[1] eq "-a") {
			if ($#ARGV == 2 && $ARGV[2] eq "-m") {
				print STDERR "legit.pl: error: empty commit message\n";
				exit 1;
			} elsif ($#ARGV == 3 && $ARGV[2] eq "-m") {
				update_index();
				commit_index($ARGV[3]);	# -a option..
			} else {
				usage_commit();
			}
		} else {
			usage_commit();
		}
	} elsif (check_no_commits()) { 	# all functions past here require atleast 1 commit
	} elsif ($ARGV[0] eq "log") {
		if ($#ARGV != 0) {
#			print STDERR "usage: legit.pl log\n";
#			exit 1;
			die "usage: legit.pl log\n";
		}
		show_log();
	} elsif ($ARGV[0] eq "show") {
		if ($#ARGV != 1) {
			print "usage: legit.pl show <commit>:<filename>\n";
			exit 1;
		}
		if ($ARGV[1] =~ /(.*?):(.*)/) {
			my $commitNum = $1;
			my $fileName = $2;
			show_commit($commitNum, $fileName);
		} else {
			print "legit.pl: error: invalid object $ARGV[1]\n";
			exit 1;
		}
	} elsif ($ARGV[0] eq "rm") {
		my $indexOnly = 0;
		my $force = 0;
		my $startIndex;
		foreach my $arg (@ARGV) {
			if ($arg =~ /^-/ && ($arg ne "--force" && $arg ne "--cached")) {
#				print "$arg\n";
				usage_remove();
			}
		}
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
		check_no_commits();
		foreach my $file (sort @trackableFiles) {
			print get_status($file);
		}
	} elsif ($ARGV[0] eq "branch") {
		check_no_commits();
		if ($#ARGV == 0) {
			show_branches();
		} elsif ($#ARGV == 1) {
			make_branch($ARGV[1]);
		} elsif ($#ARGV == 2) {
			if ($ARGV[1] ne "-d") {
				usage_branch();
			}
			delete_branch($ARGV[2]);
		} else {
			usage_branch();
		}
	} elsif ($ARGV[0] eq "checkout") {
		if ($#ARGV != 1) {
			print STDERR "usage: legit.pl checkout <branch>\n";
			exit 1;
		}
		change_branch($ARGV[1]);
	} elsif ($ARGV[0] eq "merge") {
		if ($#ARGV != 3) {
			if ($#ARGV == 1 && $ARGV[1] ne "-m") {
				print STDERR "legit.pl: error: empty commit message\n";
			} else {
				print STDERR "usage: legit.pl merge <branch|commit> -m message\n";
			}
			exit 1;
		} elsif ($#ARGV >= 2 && $ARGV[2] ne "-m" && $ARGV[1] ne "-m") {
			print STDERR "usage: legit.pl merge <branch|commit> -m message\n";
			exit 1;
		}
		if ($ARGV[1] eq "-m") {
			merge_branch($ARGV[3], $ARGV[2]);
		} else {
			merge_branch($ARGV[1], $ARGV[3]);
		}
	}# else {
#		usage($ARGV[0]);
#	}
	exit 1;
}

sub same_files {
	my ($dir1, $dir2) = @_;
	foreach my $file1 (glob "$dir1/*") {
		my $file_found = 0;
		foreach my $file2 (glob "$dir2/*") {
			if (same_file($file1,$file2)) {
				$file_found = 1;
			}
		}
		if ($file_found == 0) {
			return 0;
		}
	}
	return 1;
}


sub usage_remove() {
	print STDERR "usage: legit.pl rm [--force] [--cached] <filenames>\n";	
	exit 1;
}

sub usage_commit() {
	print STDERR "usage: legit.pl commit [-a] -m commit-message\n";
	exit 1;
}

sub usage_branch() {
	print STDERR "usage: legit.pl branch [-d] <branch>\n";
	exit 1;
}

sub check_no_commits() {
	if (! -e "$legit/.snapshot.0/") {
		print STDERR "legit.pl: error: your repository does not have any commits yet\n";
		exit 1;
	}
}
sub usage {
	my ($command) = @_;
	if ($command ne "") {
		print STDERR "legit.pl: error: unknown command $command\n";
	}
	print STDERR <<usage;
Usage: legit.pl <command> [<args>]

These are the legit commands:
   init       Create an empty legit repository
   add        Add file contents to the index
   commit     Record changes to the repository
   log        Show commit log
   show       Show file at particular state
   rm         Remove files from the current directory and from the index
   status     Show the status of files in the current directory, index, and repository
   branch     list, create or delete a branch
   checkout   Switch branches or restore current directory files
   merge      Join two development histories together

usage
exit 1;
}


sub merge_branch {
	my ($targetBranch, $message) = @_;
	my $lastSnapshot = get_last_snapshot();
	#my $currentBranch = get_branch();
	my $merged = 0;
	my @unmerged;

	if (! -d "$branches/$targetBranch") {
		print STDERR "legit.pl: error: unknown branch '$targetBranch'\n";
		exit 1;
	}
	foreach my $file (glob "$branches/$targetBranch/*") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if (-e $fileName && !same_file($file,$fileName)) {
			my $mergeBase = get_common_snapshot( $targetBranch);                   
			#print "$mergeBase\n";
                        my $unmerged_file = merge_file($file, $fileName, "$mergeBase/$fileName"); # merge $file into $fileName
			if ($unmerged_file eq "") {
				print "Auto-merging $fileName\n";
				add_files($fileName);
				$merged = 1;
			} else {
				push (@unmerged, $unmerged_file);
			}
		} elsif (! -e $fileName) {
			add_files($file);
			copy_file($file, $fileName);			
		}
	}
	if (scalar(@unmerged) != 0) {
		print STDERR "legit.pl: error: These files can not be merged:\n";
		foreach my $file (@unmerged) {
			print STDERR "$file\n";
		}
		exit 1;
	} elsif ($merged == 1) {
#		print `cat "$legit/$log"`;
#		copy_snapshots($targetBranch);
		#open FILE, '>', "empty.txt";
		#close FILE;
		#merge_file("$branches/$targetBranch/$log", "$legit/$log", "empty.txt");
		#copy_file("$log", "$legit/$log");
		#unlink "empty.txt";
		commit_index($message);
		reconcile_logs($targetBranch);
	} else {
		print "Fast-forward: no commit created\n";
	}
}

sub reconcile_logs {
	my ($targetBranch) = @_;
	open my $log1, '<', "$legit/$log" or die;
	open my $log2, '<', "$branches/$targetBranch/$log" or die;
	my @lines1 = <$log1>;
	my @lines2 = <$log2>;
	open my $file, '>', "$log" or die;
	my @newLog = uniq((@lines1, @lines2));
	foreach my $line (sort {substr($a,0,1) <=> substr($b,0,1)} @newLog) {
		print $file $line;
	}

#	my $count1 = 0;
#	my $count2 = 0;
#	my $count3 = 0;
#	my $count4 = 0;
#	my $finished = 0;
#	while ($finished != 1) {
#		$finished = 1;
#		#my $past1 = $count1;
#		if ($count1 < scalar(sort reverse @lines1)) {
#			if ($lines1[$count1] =~ /^$count3/) {
#				print $file $lines1[$count1];
#				$count1++;
#				$count3++;
#				$finished=0;
#			}
#		}
#		if ($count2 < scalar(sort reverse @lines2)) {
#			if ($lines2[$count2] =~ /^$count3/) {
#				#if ($past1 == $count1) {
#				print $file $lines2[$count2];
#				$count2++;
#				$count3++;
#				$finished=0;
#				#}
#			}
#		}
#		#$count3++;
#	}
	close $log1;
	close $log2;
	close $file;
	copy_file("$log", "$legit/$log");
	unlink "$log";
	#while ($count < get_commit_num()) {
		
}

sub copy_snapshots {
	my ($targetBranch) = @_;
	my $lastSnapshot = get_last_snapshot();
	my $lastSuffix = $lastSnapshot;
	$lastSuffix =~ s/.*\.//;
	$lastSuffix+=1;
	foreach my $dir1 (glob "$branches/$targetBranch/\.snapshots/\.snapshot*") {
		#dir1 = ... .. /.snapshot.suffix
		#print "$dir1\n";
		my $snapshot = $dir1;
		$snapshot =~ s/.*\///;
		#print "$snapshot\n";
		if (! -d "$legit/$snapshot") {
			print "$legit/$snapshot doesnt exist\n";
			copy_files($dir1, "$legit/$snapshot");
		} elsif (!same_files($dir1, "$legit/$snapshot")) {
			print "$legit/$snapshot does exist, therefore $snapshot$lastSuffix\n";
			copy_files($dir1, "$legit/$snapshot$lastSuffix");
			$lastSuffix++;
		} else {
			print "why\n";
		}
	}
}

sub get_common_snapshot {
	my ($targetBranch) = @_;
	foreach my $dir1 (glob "$branches/$targetBranch/\.snapshots/\.*") {
		my $snapshot = ".snapshot.0";
		my $suffix = 0;
		#print "$dir1\n";
		while (-d "$legit/$snapshot") {
			#print "$snapshot exists\n";
			if (same_files($dir1, "$legit/$snapshot")) {
				#print "Returning $legit/$snapshot\n";
				return "$legit/$snapshot";
			}
			$suffix = $suffix + 1;
			$snapshot = ".snapshot.$suffix";
		}
	}
	return "howdidthishappen\n";
}


sub merge_file { 
	my ($file1, $file2, $mergeBase) = @_;
	our $conflict = 0;
	open my $mergedFile, ">", "\.merge.txt" or die;
	open my $commonFile, "<", "$mergeBase" or die; #or die "Couldn't read $mergeBase\n";
	open my $fh1, "<", $file1 or die;
	open my $fh2, "<", $file2 or die;
	my @file1 = <$fh1>;
	my @file2 = <$fh2>;
	my @commonFile = <$commonFile>;
	my @merged = merge(\@commonFile, \@file1, \@file2, { 
              CONFLICT => sub {$conflict = 1 } 
          });
#	print "@merged\n";
	if ($conflict == 1) {
		close $mergedFile;
		unlink "\.merge.txt";
		return $file2;
	}
	foreach my $line (@merged) { 
#		print "$line\n";
		print $mergedFile $line;
	}
	close $mergedFile;
	copy_file("\.merge.txt", $file2);
	unlink "\.merge.txt";
	return "";
=pod
	#print "@commonFile\n";
	close $fh1;
	close $fh2;
	close $commonFile;

	my $lineCount = 0;
	foreach my $line (@commonFile) {
		my $line1 = $file1[$lineCount];
		my $line2 = $file2[$lineCount];
		if ($line eq $line1 && $line ne $line2) {
			print $mergedFile $line2;
		} elsif ($line ne $line1 && $line eq $line2) {
			print $mergedFile $line1;
		} else {
			print $mergedFile $line;
		}
		$lineCount++;
	}
	close $mergedFile;
	#print `cat "\.merge.txt"`;
	copy_file("\.merge.txt", $file2);
	unlink "\.merge.txt";
=cut
}

sub get_branch() {
	my $branchFileDirectory = (glob "$legit/\.branch/*")[0]; 
	open my $branchFile, "<", "$branchFileDirectory" or die;
	my $branchName = <$branchFile>;
	close $branchFile;
	return $branchName;
}

sub set_branch {
	my ($branchName) = @_;
	rmtree "$legit/\.branch";
	mkdir "$legit/\.branch";
	open my $branchFile, ">", "$legit/\.branch/$branchName" or die;
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
		print STDERR "Already on '$targetBranch'\n";
		exit 1;
	} elsif (! -d "$branches/$targetBranch") {
		print STDERR "legit.pl: error: unknown branch '$targetBranch'\n";
		exit 1;
	}
	
	# Checking for files that might be overwritten
	my $lastSnapshot = get_last_snapshot();
	my @overwrittenFiles = ();
	foreach my $file (glob "**") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if (! -e "$legit/$lastSnapshot/$fileName")  {
			if (-e "$branches/$targetBranch/$fileName") {
				# if File exists in targetBranch, it will be overwritten
				push @overwrittenFiles, $fileName;
			}
		}
	}
	if (scalar(@overwrittenFiles) > 0) {
		my $overwrittenFiles = join(' ', @overwrittenFiles);
		die "legit.pl: error: Your changes to the following files would be overwritten by checkout:\n$overwrittenFiles\n";
	}

	# Moving files from current branch to the $legit directory
	foreach my $file (glob "**") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if (-e "$legit/$lastSnapshot/$fileName" && 
		!same_file($file, "$legit/$lastSnapshot/$fileName")) {
			print "Not removing $file because it has changed since last commit!\n" if $debug;
			print "$legit/$lastSnapshot/$fileName is different to $file\n" if $debug;
			# If the file in current branch is differnet to its last commit,
			# keep the file ..... why
			copy_file("$legit/$lastSnapshot/$fileName", "$branches/$currentBranch/$fileName");
		} elsif (get_status($fileName) eq "$fileName - untracked\n") {
			print "Untracked file :$fileName, doing nothing\n" if $debug; 
		} else {
			print "Removing $file from current directory\n" if $debug;
			copy_file($file, "$branches/$currentBranch/$fileName");
			unlink $file;
		}
	}



	# Moving snapshots from $legit folder to the branches folder
	my $snapshotDir = "$branches/$currentBranch/.snapshots";
	foreach my $snapshot (glob "$legit/\.snapshot*") {
		my $snapshotName = $snapshot;
		$snapshotName =~ s/.*\///;
		copy_files("$snapshot", "$snapshotDir/$snapshotName");
		rmtree $snapshot;
	}

	# Moving snapshots from target branch folder to $legit folder
	$snapshotDir = "$branches/$targetBranch/.snapshots";
	foreach my $snapshot (glob "$snapshotDir/\.snapshot*") {
		my $snapshotName = $snapshot;
		$snapshotName =~ s/.*\///;
		copy_files("$snapshot", "$legit/$snapshotName");
		#rmtree "$snapshot";
	} 
	rmtree "$snapshotDir"; #so that snapshots folder isnt copied in the next two steps
	
	#Moving files from target branch folder to current directory
	foreach my $file (glob "$branches/$targetBranch/*") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
	#	if ($fileName eq "$log") {
	#		copy_file
		if (! -e $fileName) {
			print "Copying $file into user directory as $fileName\n" if $debug;
			copy_file($file, $fileName);
		} else {
			print "Not copying $file into user directory as $fileName\n" if $debug;
		}
		unlink $file;		
	}

	# Moving logs between branches
	copy_file("$legit/$log", "$branches/$currentBranch/$log");
	copy_file("$branches/$targetBranch/$log", "$legit/$log");
	#unlink "$log";

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
	my $currentBranch = get_branch();

	if ($branchName eq "master") {
		print STDERR "legit.pl: error: can not delete branch 'master'\n";
		exit 1;
	} elsif (! -d "$branches/$branchName") {
		print STDERR "legit.pl: error: branch '$branchName' does not exist\n";
		exit 1;
	} else {
		my $branchDirectory = "**";
		if ($currentBranch ne $branchName) {
			$branchDirectory = "$branches/$branchName/*";	
		}
		foreach my $file (glob "$branchDirectory") {
			my $fileName = $file;
			$fileName =~ s/.*\///;
			#if ($fileName eq "snapshots") { next };
			if (! -e $fileName || (-e $fileName && !same_file($file, $fileName))) {
				print STDERR "legit.pl: error: branch '$branchName' has unmerged changes\n";
				exit 1;
			}
		}
		rmtree "$branches/$branchName";
		print "Deleted branch '$branchName'\n"; 
	}
}

sub show_branches() {
	foreach my $branch (glob "$branches/*") {
		my $branchName = $branch;
		$branchName =~ s/.*\///;
		print "$branchName\n";
	}	
}

sub make_branch {
	my ($branchName) = @_;
	my $branch = "$branches/$branchName";
	if (! -e $branch) { 
		mkdir "$branch";
		mkdir "$branch/.snapshots";
		copy_file("$legit/$log", "$branch/$log");
#		print "Making log file at $branch/$log\n";
		foreach my $snapshot (glob "$legit/\.snapshot*") {
			my $snapshotName = $snapshot;
			$snapshotName =~ s/.*\///;
			copy_files($snapshot, "$branch/.snapshots/$snapshotName");
		}		
	} else {
		print STDERR "legit.pl: error: branch '$branchName' already exists\n";
		exit 1;
	}
	foreach my $file (glob "**") {
		my $fileStatus = get_status($file);
		if ($fileStatus ne "$file - untracked\n") {
			copy_file($file, "$branch/$file");
		}
	}
}

sub getTrackableFiles() {
	my @curDirArray = glob "**";
	my @indexArray = glob "$index/*";
	my $snapshot = get_last_snapshot();;
	my @repoArray = ();
#	my $suffix = 0;
#	while (-e "$legit/$snapshot") {
		my @curSnapshotFiles = glob "$legit/$snapshot/*";
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
	my $oldSnapshot = get_last_snapshot();	
	my $statusString = "$file -";
	if (! -e $file) { 
		if (! -e "$index/$file") {
			$statusString = "$statusString deleted\n";
		} else {
			$statusString = "$statusString file deleted\n";
		}
	} elsif (! -e "$legit/$oldSnapshot/$file" && -e "$index/$file") {
		$statusString = "$statusString added to index\n";
	} elsif (! -e "$index/$file") { #"$legit/$oldSnapshot/$file") {
		$statusString = "$statusString untracked\n";
	} elsif (! -e "$legit/$oldSnapshot/$file") {
		# index file exists, current dir file exists but no last snapshot
	} elsif (!same_file($file, "$legit/$oldSnapshot/$file")) {
		$statusString = "$statusString file changed,";
		if (same_file($file, "$index/$file")) {
			$statusString = "$statusString changes staged for commit\n";
		} elsif (same_file("$index/$file", "$legit/$oldSnapshot/$file")) {
			# oldSnapshotFile == indexFile, therefore no changes
			$statusString = "$statusString changes not staged for commit\n";
		} else {
			$statusString = "$statusString different changes staged for commit\n";
		}
	} elsif (same_file($file, "$legit/$oldSnapshot/$file")) {
		$statusString = "$statusString same as repo\n";
	}
	return $statusString;
}



sub remove_file {
	my ($indexOnly, $force, @files) = @_;
	my $oldSnapshot = get_last_snapshot();
	my @filesToDelete = ();
	foreach my $fileName (@files) {
		my $indexFile = "$index/$fileName";
		my $repositoryFile = "$legit/$oldSnapshot/$fileName";
		my $currentFile = "$fileName";
		if (! -e $indexFile) {
			print STDERR "legit.pl: error: '$fileName' is not in the legit repository\n";
			exit 1;
		}
		if ($force != 1) {	
			if (-e $repositoryFile && -e $indexFile && -e $fileName) {
				if (!same_file($indexFile, $repositoryFile) && 
					!same_file($indexFile, $fileName)) {
					print STDERR "legit.pl: error: '$fileName' in index is different to both working file and repository\n";
					exit 1;
				}
			}		
			if (-e $indexFile && $indexOnly == 0) {
				if (! -e $repositoryFile) {
					print STDERR "legit.pl: error: '$fileName' has changes staged in the index\n";
					exit 1;
				} elsif (-e $repositoryFile) {
					if (!same_file($indexFile, $repositoryFile)) {
						print STDERR "legit.pl: error: '$fileName' has changes staged in the index\n";
						exit 1;	
					}
				}
			}
			if (-e $repositoryFile && -e $fileName && $indexOnly == 0) {
				if (!same_file($repositoryFile, $currentFile)) {
					print STDERR "legit.pl: error: '$fileName' in repository is different to working file\n";
					exit 1;
				}
			}
		}
#		if (! -e $indexFile) {
#			die "legit.pl: error: '$fileName' is not in the legit repository\n";		
#		}
		if (! -e $fileName && $indexOnly == 0) {
			die "$fileName doesnt exist :)\n";
		}
		# Deleting index files first
		push @filesToDelete, $currentFile;
	}

	foreach my $fileName (@filesToDelete) {
		my $indexFile = "$index/$fileName";
		unlink $indexFile;
		if ($indexOnly == 0) {
			unlink $fileName;
		}
	}
}


sub show_commit {   #commitID:fileName 
	my ($commitID, $fileName) = @_;
	my $folder;
	my $directory = "";
	my $fileDirectory;

	if ($commitID eq "") {
		$directory = "$legit/index";
	} elsif ($commitID =~ /^[0-9]+$/) {
		if (! -d "$legit/$snapshot$commitID") {
			print "legit.pl: error: unknown commit '$commitID'\n";
			exit 1;
		}
		$directory = "$legit/$snapshot$commitID";	
	} else {
		print "legit.pl: error: unknown commit '$commitID'\n";
		exit 1;
	}
	if ($fileName !~ /^[a-zA-Z0-9]+$/) {
		print "legit.pl: error: invalid filename '$fileName'\n";
		exit 1;
	} else {
		$fileDirectory = "$directory/$fileName";
	}

	my $file;
	if($fileDirectory !~ /\/index\//) {
		open $file, '<', $fileDirectory or die "legit.pl: error: '$fileName' not found in commit $commitID\n";
	} else {
		open $file, '<', $fileDirectory or die "legit.pl: error: '$fileName' not found in index\n";# && exit 1;
	}
	print <$file>;
}

sub update_log {    #logs are updated after successful commits
	my ($message) = @_;
	open my $log, '>>', "$legit/$log" or die;
	my $numCommits = get_commit_num()-1;
	$message = "$numCommits $message";
	print $log $message;
	print $log "\n";
	close $log;
}

sub log_lines() {     #how many lines/commits there are in the log
	open my $log, '<', "$legit/$log" or die;
	my @lines = <$log>;
	close $log;
	return @lines;
}

sub show_log() {      #prints the contents of the log
	#test log
	open my $log, '<', "$legit/$log" or die;
	my @logLines = <$log>;
	foreach my $line (reverse @logLines) {
		print "$line";
	}
	close $log;
}
sub update_index() {  #used to update index for the -a tag in commit
	foreach my $file (glob "$index/*") {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if (! -e $fileName) {
			unlink $file;
		} elsif (!same_file("$file", "$fileName")) {
			unlink $file;
			copy_file("$fileName", "$file");
#			print "Replaced $file\n";
		}
	}
}
	
sub commit_index() {  #commits by creating a new snapshot and transferring files from index
	my ($message) = @_;
	my $oldSnapshot = get_last_snapshot();
	my $indexHasChanged = 0;

	if ($message =~ /^-/) {
		usage_commit();
	}

	# Checks if all files in index exist in old snapshot
	foreach my $indexFile (glob "$index/*") {	#file contains path relative to current directory
		my $fileName = $indexFile;
		$fileName =~ s/.*\///;
		my $oldRepoFile = "$legit/$oldSnapshot/$fileName";
		if (! -e "$oldRepoFile") { 				#if index has changed from last 
			$indexHasChanged = 1;				#snapshot, make new dir
		} elsif (-e "$oldRepoFile") { 				#changed = different no. of files OR
			if (!same_file("$indexFile", "$oldRepoFile")) {	#same file with different contents
				$indexHasChanged = 1;
			}
		}
	}

	# Checks if all files in old snapshot exist in index
	foreach my $oldRepoFile (glob "$legit/$oldSnapshot/*") {
		my $fileName = $oldRepoFile;
		$fileName =~ s/.*\///;
		if (! -e "$index/$fileName") {
			$indexHasChanged = 1;
		}
	}
	
	# Creates new repo/snapshot and then commits all files in index to it
	if ($indexHasChanged == 0) {
		die "nothing to commit\n";
	}

	my $newSnapshot = get_new_snapshot();
	my $commitNum = get_commit_num();
	mkdir "$legit/$newSnapshot";
	foreach my $indexFile (glob "$index/*") {
		my $fileName = $indexFile;
		$fileName =~ s/.*\///;
		copy_file("$indexFile", "$legit/$newSnapshot/$fileName");
	}
	
	print "Committed as commit $commitNum\n"; 
	set_commit_num($commitNum+1);
	update_log($message);
}

sub get_commit_num() {
	open my $commitFile, "<", "$legit/commitNum.txt" or die;
	my $commitNum = <$commitFile>;
	print "Current commitNum = $commitNum\n" if $debug;
	return $commitNum;
}

sub set_commit_num {
	my ($commitNum) = @_;
	print "Setting commitNum to $commitNum\n" if $debug;
	open my $commitFile, ">", "$legit/commitNum.txt" or die;
	print $commitFile "$commitNum";
}


# Returns 0 if they are not the same file(or if one of the files dont exist), 1 if they are
sub same_file() {
	my ($file1, $file2) = @_;
	open FILE1, '<', $file1 or die "cannot open $file1: $!";
	open FILE2, '<', $file2 or die "cannot open $file2: $!";
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
    chdir "$legit";
    while (1) {
        my $snapshot_directory = ".snapshot.$suffix";

        if (!-d $snapshot_directory) { # checks if its currently not a directory
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
    chdir "$legit";
    while (1) {
        my $snapshot_directory = ".snapshot.$suffix";

        if (!-d $snapshot_directory) { # checks if its currently not a directory
	    chdir "..";
            return $snapshot_directory;
        }
        $suffix = $suffix + 1;
    }
}

sub add_files {
        my (@files) = @_;
	my $file;
	foreach $file (@files) {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if ($fileName !~ /^[a-zA-Z0-9\@\.\-\_]+$/ || $fileName !~ /^[a-zA-Z0-9]/) {
			# file doesnt start with alphanumeric char OR 
			# contains characters that are not allowed
			if ($fileName =~ /^-/) {
				print STDERR "usage: legit.pl add <filenames>\n";
				exit 1;
			} else {
				print STDERR "legit.pl: error: invalid filename '$file'\n";
				exit 1;
			}
		} elsif (! -e $file && ! -e "$index/$file") {
			print STDERR "legit.pl: error: can not open '$file'\n";
			exit 1;
		}
	}

	foreach $file (@files) {
		my $fileName = $file;
		$fileName =~ s/.*\///;
		if (! -e $file && -e "$index/$file") {
			#wierd subset 0_13 case 
			#if file being added doesnt exist in directory, but exists in index and is added..
			#DELETE it 
			unlink "$index/$file";
		} else {
			copy_file("$file", "$index/$fileName");
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
