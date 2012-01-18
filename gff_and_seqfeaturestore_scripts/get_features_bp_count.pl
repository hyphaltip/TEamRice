#!/usr/bin/perl -w
use strict;
use Bio::DB::SeqFeature::Store;
use Data::Dumper;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use File::Spec;
## sqlite data file path
## ex:/home_stajichlab/robb/rice/database/MSUr7.mping.insertions.sqlite
my $sqlite = shift; 
$sqlite = File::Spec->rel2abs($sqlite);

# Open the sequence database
my $db = Bio::DB::SeqFeature::Store->new(-adaptor => 'DBI::SQLite',
                                           -dsn     => $sqlite);
my %ref;
my $ref_total = 0;
my %transposons;
##change chromosome to your reference type, ex: scaffold
my @features_type = $db->get_features_by_type('chromosome');

##if there are any chromosomes or scaffolds you want to skip,
##put the names in the regex
foreach my $feature (@features_type) {
  my $ref = $feature->ref;
  next if $ref =~/Un/ or $ref =~ /Sy/;
  my $len = $feature->length;
  $ref{$ref}= $len ;
  $ref_total+=$len;
}
print "ref: $ref_total\n";
my %feat;

##change the @queries list to features you want to count total nucleotides
my @queries = qw (gene cds three_prime_UTR five_prime_UTR);
foreach my $query (@queries){
  foreach my $feature ($db->get_features_by_type($query)) {
    my $ref = $feature->ref; 
    next if !exists $ref{$ref};
    if (!exists $feat{$query}{$ref}){
      for (my $i = 0; $i < $ref{$ref} + 1 ; $i++){
        ${$feat{$query}{$ref}}[$i] = 0;
      }
    }
	
### do not count anything that belongs to a gene that is annotated as a transposon
##change this to =0 if you want to count transposons
my $transposonCheck = 1;

##I do not want to count any exons or other features that belong
##to transposons. determined by the word 'transposon' appearing in
##the 9th column Note=
    if ($transposonCheck){
      my %attr = $feature->attributes;
      if ($query eq 'gene'){
        my $notes_arry_ref = $attr{'Note'};
        my $note = ${$notes_arry_ref}[0];
        my $name = ${$attr{'load_id'}}[0];
        $transposons{$name}=0 if $note =~ /transposon/;
        next if $note =~ /transposon/;
      }else{
        my $name_arry_ref = $attr{'parent_id'};
        my $name = ${$name_arry_ref}[0];
        $name =~ s/(\w+)\.\d+?$/$1/;
        next if exists $transposons{$name};    
      }
    }
## end transposon check


    my $f_start = $feature->start;
    my $f_end = $feature->end;
    for (my $i= $f_start ; $i < ($f_end +1) ; $i++){
	${$feat{$query}{$ref}}[$i] = 1; 
    }
  }  
}
foreach my $feat (sort keys %feat){
  my $feat_total = 0;
  foreach my $ref (sort keys %{$feat{$feat}}){
    my $feat_sum = sum @{$feat{$feat}{$ref}}; 
    $feat_total += $feat_sum;
  }
  print "$feat: $feat_total\n";
}

