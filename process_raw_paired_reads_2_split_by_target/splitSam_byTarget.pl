#!/usr/bin/perl -w
use strict;
use File::Spec;
use Getopt::Long;


my $sam_file;
my $sam_dir;
my $current     = File::Spec->curdir();
my $current_dir = File::Spec->rel2abs($current);
my $out_dir     = "$current_dir/split_by_target";

##takes a sam file and splits it into separate files based on the
##targets sequences.

GetOptions(
    's|sam:s' => \$sam_file,
    'd|dir:s' => \$sam_dir,
    'o|out:s' => \$out_dir,
    'h|help'  => \&getHelp,
);

sub getHelp () {
    print "
usage:
./splitSam_byTarget.pl [-d sam_directory] [-s sam file] [-o out_directory][-h] 

options:
-s STR          sam file [no default]
-d STR          directory of sam files [no default]
-o STR		directory for the new sam files [current_dir/split_by_target]
-h              this message
";
    exit 1;
}

if ( !defined $sam_file and !defined $sam_dir ) {
    print "\n\nMust provide a sam file or a directory containing sam files\n\n";
    &getHelp;
    exit 1;
}
elsif ( (defined $sam_file and !-e $sam_file) ){
    print
"Must provde a valid sam file \n\n";
    &getHelp;
    exit 1;
}elsif ( defined $sam_dir and !-d $sam_dir ) {
    print
"Must provde a valid directory containing sam files\n\n";
    &getHelp;
    exit 1;
}

mkdir "$out_dir", 0777 unless -d "$out_dir";
my $sam_dir_path;
my @sam_files;

#open OUTSH, ">$out_dir/convert_sam2fq.sh" or die $!;
#print OUTSH "#!/bin/bash\n\n";

if ( defined $sam_dir and -d $sam_dir ) {
    $sam_dir_path = File::Spec->rel2abs($sam_dir);
    opendir( DIR, $sam_dir_path ) || die "$!";
    foreach my $file ( readdir(DIR) ) {
        if ( $file =~ /\.sam$/ ) {
            $file = $sam_dir_path . "/" . $file;
            push @sam_files, $file;
        }
    }
}
elsif ( defined $sam_file and -e $sam_file ) {
    push @sam_files, $sam_file;
}

foreach my $in_sam (@sam_files) {
    my $sample;
    my ( $volume, $directories, $filename ) = File::Spec->splitpath($in_sam);
    if ( $filename =~ /(\S+)\.\S+$/ ) {
        $sample = $1;
    }
    else {
        warn "file: $in_sam";
    }

    open INSAM, $in_sam;
    my %targets;
    my %headers;
    my $PGline; 
    my %seqs;

    while ( my $line = <INSAM> ) {
        chomp $line;
        if ( $line =~ /^\@SQ\s+SN:(\S+)/ ) {
            $headers{$1} = $line;
        }
        elsif ( $line =~ /^\@PG/ ) {
            $PGline = $line;
        }
        else {
            my ( $seq, $col2, $target ) = split /\t/, $line;
            ## if flag is between 64 and 127 left pair
            ## if flag is > 127 right pair
            my $left_right;
            if ( $col2 > 63 and $col2 < 128 ) {
                $left_right = 'left';
            }
            elsif ( $col2 > 127 ) {
                $left_right = 'right';
            }elsif ( $col2 < 64 ) {
		$left_right = 'unpaired';
	    }
            ##add each seq name to its target and count
            ##add each line of sam file to its seq name, noting if it is left or right
            ##this will also collect unmapped reads, to target *
            ##when printing files get both right and left for each target
            $targets{$target}{$seq}++;
            $seqs{$seq}{$left_right} = $line;
        }
    }

    #for every target that is not * add the unmapped reads
    foreach my $target ( sort keys %targets ) {
        next if $target eq '*';
        ##get each unmapped read from target *
        foreach my $seq ( sort keys %{ $targets{'*'} } ) {
            $targets{$target}{$seq}++;
        }
    }

##print each read to the appropriate target file
##includes each read that mappped to target and its mate
##includes each unmapped read
    foreach my $target ( sort keys %targets ) {
        next if $target eq '*';
	mkdir "$out_dir/$target", 0777 unless -d "$out_dir/$target";
	my $outfile;
        if ($sample =~/(\S+)\.unPaired/){
		$outfile = "$1.$target.unPaired.sam";	
	}else{
		$outfile = "$sample.$target.sam";
        }
	open OUTSAM, ">$out_dir/$target/$outfile" or die $!;

        #add every target SQ line to each file
        foreach my $header (sort keys %headers) {
            print OUTSAM $headers{$header}, "\n";
        }
        print OUTSAM $PGline, "\n" if defined $PGline;

#print both lft and right read even if only one of the 2 was actullly mapped to this target
        foreach my $seq ( sort keys %{ $targets{$target} } ) {
            foreach my $left_right ( sort keys %{ $seqs{$seq} } ) {
                print OUTSAM $seqs{$seq}{$left_right}, "\n";
            }
        }
    }
}
