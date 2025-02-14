#!/usr/bin/env perl

use Carp;
use strict;
use warnings;
use Getopt::Long;
use Cwd;
use Data::Dumper;
no warnings 'experimental::smartmatch';
use List::Util qw/first/;

#Declare variables

my $p=0; # Change if we want to print percentages
# $p=1 if shift eq '-p';
my @indel_count; my @snp_count;
my @transitions; my @transversions;
my @A_C;my @A_G;my @A_T;my @C_A;my @C_G;my @C_T;my @G_A;my @G_C;my @G_T;my @T_A;my @T_C;my @T_G;
my @ERS;
#INDELs
my @one;my @two;my @three;my @more;
my @minone;my @mintwo;my @minthree;my @less;
my %mutations;
my %null; my $totlines=0;


my ($input);
GetOptions
(
    'i|input=s'         => \$input,
);

( $input && -f $input ) or die qq[Usage: $0 -i <input vcf>\n];

# Get DelN from the input string (which should contain the DelFolder)
my @samplein=split( /\//, $input);
my $deln=first { $_ =~ 'Del[0-9]+_.+' } @samplein;


my $ifh;
if( $input =~ /\.gz/ ){open($ifh, qq[gunzip -c $input|]);}else{open($ifh, $input ) or die $!;}
my @VCF=<$ifh>;
close($ifh);


@VCF=<STDIN> unless @VCF;
my @samples;
foreach my $line (@VCF){
	chomp $line;
	next if $line =~ /^##/;
	if ($line =~ /^#/){
			#read header
			my @row=split "\t", $line;
			@samples=splice @row, 9;
			for my $sample (@samples){
				$null{$sample}=0;
			}
			next
	}
        next unless $line =~ /PASS/;
	(my $chrom, my $pos, my $ID, my $REF, my $ALT, my $QUAL, my $FILT, my $INFO, my $FORMAT, my @mutations) = split "\t", $line;
#	next if $FILT ne 'PASS'; next if $QUAL<180;
	$totlines++;
  # printf "$line\n";
	my @alt_list=split ",", $ALT;
	for (my $c=0; $c<scalar @samples; $c++){
		if ($mutations[$c] =~ /[0-9]\/[0-9]|[0-9]\/[0-9]\/[0-9]\/[0-9]/){
			#split the sample field and recover the genotype information
			my @mm1=split ":", $mutations[$c];
			my @mm2=split "/", $mm1[0];
      foreach my $allele (@{uniq(@mm2)})	 {
        next if $allele == 0;
        my $alt_pos=$allele-1;
        die if $alt_pos<0;
        my $size = length($alt_list[$alt_pos]) - length($REF);

        if ($size == 0) {
          push @{$mutations{$samples[$c]}{'ID_SNV'}},  "$chrom-$pos";
  				$mutations{$samples[$c]}{$REF.">".$alt_list[$alt_pos]}++; #FIXME what if both lengths are 2??
  			  $mutations{$samples[$c]}{'SNP_COUNT'}++;
        } elsif (abs($size) > 0) {
          push @{$mutations{$samples[$c]}{'ID_INDEL'}},  "$chrom-$pos";
  				$mutations{$samples[$c]}{'IND_COUNT'}++;
  				if (abs($size) < 4) {
  					$mutations{$samples[$c]}{$size}++;
  				}
  				elsif ($size > 3){
  					$mutations{$samples[$c]}{'>3'}++;
  				}
  				elsif ($size < -3){
            $mutations{$samples[$c]}{'<-3'}++;
  	      }
  				else {die "Something odd happened, investigate!!!\n"}
        }
        else {
            die "Bad line in vcf file > $line\n";
        }
      }
    }
    elsif ($mutations[$c] =~ /^\.$/){
			$null{$samples[$c]}++;
		}
	}
}




#Identify control sample
foreach my $k (@samples){
	$mutations{$k}{'SAMPLES'}=$k;
	$mutations{$k} = 'control' if $null{$k} == $totlines;
}

@samples= grep {$mutations{$_} ne 'control'} @samples;

#Find how many unique mutations in the file in each sample
#For every sample that is not a control
foreach my $sample1 (@samples){
	#and again for every sample
	foreach my $sample2 (@samples){
		# skip when the two sample name match, we are not interested
		next if $sample1 eq $sample2;
		#for both the ID of SNV and INDELS
		foreach my $elem ("ID_SNV", "ID_INDEL"){
			#for every mutation in the list of mutation ID of sample 1
			foreach my $mutation (@{$mutations{$sample1}{$elem}}){
#				print "$mutation\n";
				#increase the counter only if the mutation currently examined is not found in sample2
				push @{$mutations{$sample1}{"uniq".$elem}}, $mutation unless $mutation ~~ @{$mutations{$sample2}{$elem}}
			}

#		print "Sample1: $sample1 ; Sample2: $sample2; ";
#		print Dumper \@{$mutations{$sample1}{'uniqID_SNV'}};
#		print  "\n";
		}
	}
}
#

my $s=0;
foreach my $k (@samples){
	$mutations{$k}{'G>T'} = ( $mutations{$k}{'G>T'} || 0 )+ ( $mutations{$k}{'C>A'} || 0);
	$mutations{$k}{'C>T'} = ( $mutations{$k}{'C>T'} || 0 )+ ( $mutations{$k}{'G>A'} || 0);
	$mutations{$k}{'C>G'} = ( $mutations{$k}{'C>G'} || 0 )+ ( $mutations{$k}{'G>C'} || 0);
	$mutations{$k}{'A>T'} = ( $mutations{$k}{'A>T'} || 0 )+ ( $mutations{$k}{'T>A'} || 0);
	$mutations{$k}{'A>G'} = ( $mutations{$k}{'A>G'} || 0 )+ ( $mutations{$k}{'T>C'} || 0);
	$mutations{$k}{'A>C'} = ( $mutations{$k}{'A>C'} || 0 )+ ( $mutations{$k}{'T>G'} || 0);
	$mutations{$k}{'TS'} =  $mutations{$k}{'C>T'} +  $mutations{$k}{'A>G'};
	$mutations{$k}{'TV'} =  $mutations{$k}{'G>T'} +  $mutations{$k}{'C>G'} +  $mutations{$k}{'A>T'} +  $mutations{$k}{'A>C'};
#	$mutations{$k}{'uniqID_SNV_NO'} = scalar(@{$mutations{$k}{"uniqID_SNV"}});
#       $mutations{$k}{'uniqID_INDEL_NO'} = scalar(@{$mutations{$k}{"uniqID_INDEL"}});
	$mutations{$k}{'uniqID_SNV'} = uniq(@{$mutations{$k}{"uniqID_SNV"}});
	$mutations{$k}{'uniqID_INDEL'} = uniq(@{$mutations{$k}{"uniqID_INDEL"}});
	$mutations{$k}{'uniqID_SNV_no'} = scalar @{$mutations{$k}{'uniqID_SNV'}};
        $mutations{$k}{'uniqID_INDEL_no'} = scalar @{ $mutations{$k}{'uniqID_INDEL'}};
	$s++;
}

#print Dumper \%mutations;



my @fields=qw[IND_COUNT SNP_COUNT TS TV C>T A>G A>T C>G G>T A>C <-3 -3 -2 -1 1 2 3 >3 uniqID_SNV_no uniqID_INDEL_no SAMPLES];
my %out;
my @output;
for my $field (@fields){
	for my $sample(@samples){
		if ($p){
			if ($field =~ /[ACTG]>[ACTG]/){
				my $percentage=sprintf ("%.2f", ( ( $mutations{$sample}{$field} || 0)/$mutations{$sample}{'SNP_COUNT'}) * 100);
				push @{$out{$field}}, $percentage."%" unless  $mutations{$sample} eq 'control';
			}
			elsif ($field =~ /[0-9]/ || $field =~ /[<>][0-9]/ ){
                                my $percentage=sprintf ("%.2f", ( ( $mutations{$sample}{$field} || 0)/$mutations{$sample}{'IND_COUNT'}) * 100);
                                push @{$out{$field}}, $percentage."%" unless  $mutations{$sample} eq 'control';
                        }
			else {
                        	push @{$out{$field}}, ($mutations{$sample}{$field} || 0) unless  $mutations{$sample} eq 'control';
                	}

		}
		else {
			push @{$out{$field}}, ($mutations{$sample}{$field} || 0) unless  $mutations{$sample} eq 'control';
		}
	}
	if (exists $out{$field}){
		push @output , (join ':', @{$out{$field}});
	}
	else{
		push @output ,"0";
	}
}

splice @output, 4, 0, $deln;
splice @output, -1, 0, $s;
#print Dumper \@output;

print("INDEL\tSNP\tTs\tTv\tSample \tC>T\tA>G\tA>T\tC>G\tG>T\tA>C\t<-3\t-3\t-2\t-1\t1\t2\t3\t>3\tuqSNV\tuqIND\tNumber of samples\n");
print join "\t", @output;
print "\n";

sub uniq {
  my %seen;
  my @uniq=grep { !$seen{$_}++ } @_;
  return \@uniq;
}
