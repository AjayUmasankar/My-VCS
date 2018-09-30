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
		commit_index();
		
		# Empty out index!!
	} elsif ($ARGV[0] eq "log") {
		show_log();
	} elsif ($ARGV[0] eq "show") {
		$ARGV[1] =~ /([0-9]*):(.*)/;
		show_commit($1, $2);
	}
}

sub show_commit() {
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

sub update_log() {
	my $message = $ARGV[2];
	#print "$message is message\n";
	open my $log, '>>', ".legit/log.txt" or die;
	$numCommits = log_lines();
	$message = "$numCommits $message";
	print $log $message;
	print $log "\n";
	close $log;
}

sub log_lines() {
	open my $log, '<', ".legit/log.txt" or die;
	@lines = <$log>;
	close $log;
	return @lines;
}

sub show_log() {	
	#test log
	open my $log, '<', ".legit/log.txt" or die;
	my @logLines = <$log>;
	foreach $line (reverse @logLines) {
		print "$line";
	}
	#print "is updated log\n";
	close $log;
}

sub commit_index() {
	my ($indexDir) = ".legit/index";
	my $file;
	my $oldSnapshot = get_last_snapshot();
	my $newSnapshot = get_new_snapshot(); #doesnt create, just gets the next possible directory
	$newSnapshot =~ /\.snapshot\.(.*)/;
	$commitNum = $1;

	#Makes new directory if necessary
	foreach $file (glob "$indexDir/*") {	#file contains path relative to current directory
		my $fileName = $file;
		$fileName =~ s/.*\///;	# gets the name of the file being copied 
		if (!same_file("$file", ".legit/$oldSnapshot/$fileName")) {
			if (! -d ".legit/$newSnapshot") {
				mkdir ".legit/$newSnapshot";
			}
			#copy_file("$file", ".legit/$newSnapshot/$fileName");
		}
	}
	if (! -d ".legit/$newSnapshot") { 
		die "nothing to commit\n"; 
	} else {	
		#the directory does exist(so atleast one change from oldSnapshot 
		#  so we need to copy everything from index
		foreach $file (glob "$indexDir/*") {
			my $fileName = $file;
			$fileName =~ s/.*\///;
			copy_file("$file", ".legit/$newSnapshot/$fileName");
		}
	}
	print "Committed as commit $commitNum\n"; 
	update_log();
	#return 1;
}

sub same_file() {
	my ($file1, $file2) = @_;
	open FILE1, '<', $file1 or die;		# if the file doesnt exist in oldSnapshot(FILE2),  
					        # new commit is required. Return 0
	open FILE2, '<', $file2 or return 0;
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
        #$indexDir = "
        my (@files) = @_;
	my $file;
	foreach $file (@files) {
		if (! -e $file) {
			print "legit.pl: error: can not open 'non_existent_file'\n";
			exit 1;
		}
	}
        foreach $file (@files) {
                copy_file($file,".legit/index/$file");
        }
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
