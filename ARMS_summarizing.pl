#!usr/bin/perl
# ARMS_summarizing.pl
# Kate Lee April 2016 for Ivan Campos
# Takes in a number of label files and summarises output (to reduce false positives) 
# i.e. only want to identify a bird when the model for that bird is positive and all other models indicate "other_sp"

# input: text file (default sum_me.txt) with a list of the files to be summarised (one on each line), categories.txt file with a list of all the categories
# usage: perl ARMS_summarizing.pl <sum_me.txt> <outfile_name>


######################################################################################################################################

# RULES (from Ivan):
# 1. When the five labels are indicating the same category, use that category
#       -(example1: five models indicating “background”)
#       -(example2:  five models indicating “other_sp”)
# 2. The  “background” label should be used every time it appears in at least one of the five models, with two exceptions:
#       -Exception 1:  when “background” appears at the same time as “noise” – use “noise” in this case.
#       -Exception 2:  when “background” appears at the same time as two different bird species – use “unidentified” in this case.
# 3. The “noise” label should be used every time it appear in one of the five models.
# 4. When among the five models there are 2 categories indicated and one of the categories is a bird species and the other is “other_sp”,
#   use the bird species label (ex: one model indicate GFP and all the others indicate “other_sp” = the GFP label should be used)
# 5. When among the five models there are 3 categories indicated:
#        5A: In that case the category "unidentified” should be used. 
#            (example: two of the categories are bird species and the other is “other_sp” or “background”).
#            In this case the “unidentified” should be indicated from the beginning of the bird species which started first and go until 
#            the end of the second species.
# 6. When among the five models there are 4 categories use “unidentified”.
# 7. Replace "other_sp" label with "unidentified"

####################################################################################################################################### 


use strict; 
use warnings; 

my $sumfile;
my $outfile;


if ( (scalar(@ARGV) != 0) && (scalar(@ARGV) != 2) ) { die "ERROR: input must be 'perl sum_labelfiles.pl' OR 'perl sum_labelfiles.pl <sum_file.txt> <outfile_name> ";}


if (@ARGV == 0) {$sumfile = "sum_me.txt"; $outfile = "summary.labels.txt"}
else {$sumfile = $ARGV[0]; $outfile = $ARGV[1]}

# open log file
open (LOG, "> label.log") || die "ERROR, couldn't open log file: $!";

# open list of files 
open (SUMME, "< $sumfile") || die "ERROR, couldn't open sum_me.txt: $!";

# open output file
open (OUT, "> $outfile") || die "ERROR, couldn't open output file: $!";

# read in files in sum_me.txt list and put each into an array-of-arrays (@dataset)
my @dataset;
my $filecounter = 0;
#print "got to fileloop\n";
while(<SUMME>){
    chomp;
    print LOG "reading in $_\n";
    open (TEMP,"<$_") || die "ERROR couldn't open $_: $!";
    chomp (@{ $dataset[$filecounter] } = <TEMP>);
    close TEMP;
    $filecounter++;
}
close SUMME;
print LOG "$filecounter files parsed\n";

# test printing out label file -------- WORKS ;)
#foreach my $item (@{$dataset[1]}) {
#    print $item ."\n";
#}
#print "passed fileloop \n";

#exit;


# find start and end times (assumes all models have been run on the same audiofile)
my @values = split /\s/, $dataset[1][0];
my $starttime = $values[0];
@values = split /\s/, $dataset[1][-1];
my $endtime = $values[1];
print LOG "experiment runs from $starttime to $endtime \n";



# build categories hash
my %categories;
print LOG "\ncategories used include:\n";
open (CAT, "<categories.txt") || die "ERROR cannot open categories.txt file: $!";
while(<CAT>){
    chomp;
    $categories{$_} = 0;
    print LOG "$_\n";
}

print LOG "\n\n\n";

# species list hash
my %species = %categories;
delete($species{'background'});
delete($species{'noise'});
delete($species{'other_sp'});


# iterate through arrays to find blocks
my $i;
my $last_start = $starttime;
my $last_end = $starttime;
my $last_category = 'none';
my $current_start = $starttime;
my $current_end = $starttime;
my $current_category = 'none';
my $checkpoint = 0;
my $manybirds = 0;
my $birdcount = 0;


#for (my $counter=1; $counter <= 200; $counter++) {
until ($current_end == $endtime){    
    # move current values to $last values
    $last_start = $current_start;
    $last_end = $current_end;
    $last_category = $current_category;

    # empty categories hash for next block
    for my $key (sort keys %categories) {
	$categories{$key} = 0;
	#print "$key\t";
    }
    print LOG "\n";

    # move to next block, skip values = 0
    for ($i=0; $i <= $filecounter -1; $i++){
	my @values = split /\t/, $dataset[$i][0];
	if ($values[1] == $checkpoint) { shift(@{$dataset[$i]}); }
	@values = split /\t/, $dataset[$i][0];
	if ($values[2] eq "0") { print LOG "0 was here\n";shift(@{$dataset[$i]}); }
    }

    print LOG "______________________________________________________________________________________________\n"; 
    # get values for all models in next time block and mark the smallest end time as the next checkpoint
    my %section;
    $checkpoint = $checkpoint + 100;
    for ($i=0; $i <= $filecounter -1; $i++){
	print LOG "$i $dataset[$i][0] \n";
	my @values = split ("\t", $dataset[$i][0]);
	$section{category}{$i} = $values[2];
	$section{start}{$i} = $values[0];
	$section{end}{$i} = $values[1];
#	print "values[1] = $values[1] and checkpoint = $checkpoint\n";    # numbers correct
#	if ($values[1] <= $checkpoint) { print "it is smaller\n";}        # if statement works
	if ($values[1] <= $checkpoint) { 
	    $checkpoint = $values[1];
	}
    }
    #print "next checkpoint = $checkpoint\n";

    # sum catagories
    for ($i=0; $i <= $filecounter -1; $i++){
	$categories{$section{category}{$i}}++;
    }
    
    # test category hash
    for $i (sort keys %categories) {
    #print "$i $categories{$i}\t";
    }

    # determine summary category for this block
    $birdcount = 0;
    if ($categories{'noise'} > 0) { $current_category = 'noise';}                  # if any category is noise                            -> 'noise'
    elsif ( ($categories{'other_sp'} > 0) || ($categories{'background'} > 0) ) {   
	my $tempcategory = 'unknown';
	for my $i (sort keys %species){                                            # check for birds identified
	    if ($categories{$i} > 0) { $birdcount++; $tempcategory = $i; }
	}
	if ( ($manybirds == 0) && ($birdcount > 1) ) { $manybirds = 1; $current_category = 'unidentified'; }    # no 'noise', manybirds = 0, 2+ birds  ->  'unidentified', change manybirds = 1
	elsif ( ($manybirds == 1) && ($birdcount > 1) ) { $current_category = 'unidentified'; }                 # no 'noise', manybirds = 1, 2+ birds  ->  'unidentified'  
	elsif ( ( $manybirds == 1) && ($birdcount == 1) ) { 
	    if ($categories{'background'} > 0) {$current_category = 'background'; $manybirds = 0; }  # no 'noise', manybirds flag = 1, one bird, 'background' > 0 -> 'background', change manybirds = 0, 
 	    else { $current_category = 'unidentified';}                                # no 'noise', manybirds flag = 1, one bird, no 'background'   ->  'unidentified', 
	}
	elsif ( ( $manybirds == 0) && ($birdcount == 1) ) { 
	    if ($categories{'background'} > 0) {$current_category = 'background';} # no 'noise', manybirds = 0, one bird, 'background' > 0  -> 'background'
 	    else { $current_category = $tempcategory; }                            # no 'noise', manybirds = 0, one bird, no 'background'   ->  'bird'
	}
	elsif ($birdcount == 0){
	    if ($categories{'background'} > 0) { $current_category = 'background'; $manybirds = 0;}    # no 'noise', no birds, 'background' > 0   -> 'background', change manybirds = 0
	    elsif ($categories{'other_sp'} > 0) { $current_category = 'unidentified'; $manybirds = 0;}     # no 'noise', no birds, no 'background', 'other_sp' > 0  -> 'unidentified', change manybirds = 0
      	}
	else { $current_category = 'unknown'; }
    }
    #elsif ($categories{'background'} > 0) { $current_category = 'background'; $manybirds = 0; }   
    #elsif ($categories{'other_sp'} > 0) { $current_category = 'unidentified' ; }
    else {$current_category = 'unknown';}

    #print "\ncurrent category = $current_category\n";

    # find curent end (where next block will start)
    $current_end = 1000000;
    for ($i=0; $i <= $filecounter -1; $i++){
        my @values = split ("\t", $dataset[$i][0]);
	if ($values[1] < $current_end){
	    $current_end = $values[1];
	}
    }


    # add block to last or print to file
    if ($current_category eq $last_category) {
	$current_start = $last_start;
    }
    else {
	if ($manybirds == 1) { $current_start = $last_start;} 
	else { $current_start = $last_end; } 
	unless ( ($last_end == $starttime) ||  ( ($manybirds == 1) && ($last_category ne 'background') && ($last_category ne 'noise') ) ){
	    print LOG "\n******SUM LINE: $last_start\t$last_end\t$last_category*********\n";
	    print OUT "$last_start\t$last_end\t$last_category\n";
	}
    }
    
    print LOG "current category = $current_category\ncurrent start = $current_start\ncurrent end = $current_end\ncurrent manybirds = $manybirds\nbirdcount = $birdcount\n";	

}

# if last block, print to file and exit
if ($current_end == $endtime){
    print OUT "$current_start\t$current_end\t$current_category\n";
}
