#!/usr/bin/perl -w


sub main() {
	if ($ARGV[0] eq "init") {
		if (!-d ".legit") {
			mkdir ".legit";
			mkdir ".legit/index";
			open my $log , ">>", ".legit/log.txt" or die;
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
	}
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
			
#			if (! -e $currentFile) {
#				die "legit.pl: error: '$indexFile' has changes staged in the index\n";
#			}
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
	$numCommits = log_lines();
	$message = "$numCommits $message";
	print $log $message;
	print $log "\n";
	close $log;
}

sub log_lines() {     #how many lines/commits there are in the log
	open my $log, '<', ".legit/log.txt" or die;
	@lines = <$log>;
	close $log;
	return @lines;
}

sub show_log() {      #prints the contents of the log
	#test log
	open my $log, '<', ".legit/log.txt" or die;
	my @logLines = <$log>;
	foreach $line (reverse @logLines) {
		print "$line";
	}
	#print "is updated log\n";
	close $log;
}
sub update_index() {  #used to update index for the -a tag in commit
	my $indexDir = ".legit/index";
	foreach $file (glob "$indexDir/*") {
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
	my $indexDir = ".legit/index";
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
	$newSnapshot =~ /\.snapshot\.(.*)/;
	my $commitNum = $1;
	mkdir ".legit/$newSnapshot";
	foreach my $indexFile (glob "$indexDir/*") {
		my $fileName = $indexFile;
		$fileName =~ s/.*\///;
		copy_file("$indexFile", ".legit/$newSnapshot/$fileName");
	}

	print "Committed as commit $commitNum\n"; 
	update_log($message);
	#return 1;
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
        $indexDir = ".legit/index/";
        my (@files) = @_;
	my $file;
	foreach $file (@files) {
		if (! -e $file && ! -e "$indexDir$file") {
			die "legit.pl: error: can not open 'non_existent_file'\n";
		} elsif (! -e $file && -e "$indexDir$file") {
			#wierd subset 0_13 case 
			unlink "$indexDir$file";
		} else {
			copy_file("$file", "$indexDir$file")
		}
	}
        #foreach $file (@files) {
	#	if (-e $file) {
        #       	copy_file($file,".legit/index/$file");
	#	}
        #}
}


sub copy_file { # Copied from Lab08 Sample Solution
    my ($source, $destination) = @_;

    open my $in, '<', $source or die "Cannot open $source: $!";
    open my $out, '>', $destination or die "Cannot open $destination: $!";

    while ($line = <$in>) {
        print $out $line;
    }

    close $in;
    close $out;
}

main();
