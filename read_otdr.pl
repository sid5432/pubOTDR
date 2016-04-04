#!/usr/bin/perl -w
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin";
use otdr;

my $var = {};

# -----------------------------------------------
my $filename = shift or die("USAGE: $0 SOR_filename [dump(yes or no)]\n");
my $dump = shift || "no";
  
my $output = $filename;
my @arr = split /\//, $output;
my $logfile;

$output = $logfile = $arr[$#arr];
$output =~ s/\.sor$/\-trace\.dat/oi;
# $logfile =~ s/\.sor$/\-log\.dat/oi;
# open(DATA,">$logfile") or die("Cannot write results/log to $logfile\n");

# $otdr::LOG = *DATA;
$otdr::LOG = *STDERR;

$var->{calc_checksum} = 1;
otdr::parse( $filename, $output, $var );
# close(DATA);

# ..............................
my $pre    = "MAIN: ";
my $subpre = "    : ";
my $div    = ("-"x80)."\n";

# grand summary
if ( $dump =~ m/^yes/oi ) {
    
    print "\n",$div;
    print $pre,"SUMMARY:\n";
    
    foreach my $item (sort keys %{$var}) {
	print $pre,"$item: $var->{$item}\n";
    }
}

exit;
