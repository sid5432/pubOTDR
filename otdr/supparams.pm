#!/usr/bin/perl -w
use strict;
use Exporter;
# use FindBin qw($Bin);
# use lib "$Bin/../..";
use otdr::utils qw(get_val get_string get_hexstring);

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( process_supparams );

package otdr;

# *LOG = *STDERR;

sub process_supparams
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    if ( $var->{flavor} == 1 ) {
	return _process_supparams1($bufref, $pos, $var);
    }elsif($var->{flavor} == 2 ) {
	return _process_supparams2($bufref, $pos, $var);
    }else{
	
	return;
    }
}

# .................................................
# for Bellcore 1.x
sub _process_supparams1
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my ($str,$hex,$count);
    
    my @plist = (
	"supplier", # ............. 0
	"OTDR", # ................. 1
	"OTDR S/N", # ............. 2
	"module", # ............... 3
	"module S/N", # ........... 4
	"software", # ............. 5
	"other", # ................ 6
    );

    my $val;
    for(my $i=0; $i<= $#plist; $i++) {
	($str,$hex,$count,$pos)= get_string( $bufref, $pos );
	
	my $label = "supparams::$plist[$i]";
	$var->{$label} = $str;
	print $otdr::LOG $otdr::utils::subpre,"$i. $plist[$i]: $str\n";
    }
    
    return;
}

# ...............................................
# for Bellcore 2.x
sub _process_supparams2
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my ($str,$hex,$count);
    
    # header and '\0'
    ($str,$hex,$count,$pos)= get_string( $bufref, $pos );
    if ( $str ne 'SupParams' ) {
	print $otdr::LOG $otdr::utils::pre," ERROR: should be SupParams; got '$str' instead\n";
	return;
    }
    
    my @plist = (
	"supplier", # ............. 0
	"OTDR", # ................. 1
	"OTDR S/N", # ............. 2
	"module", # ............... 3
	"module S/N", # ........... 4
	"software", # ............. 5
	"other", # ................ 6
    );

    my $val;
    for(my $i=0; $i<= $#plist; $i++) {
	($str,$hex,$count,$pos)= get_string( $bufref, $pos );
	
	my $label = "supparams::$plist[$i]";
	$var->{$label} = $str;
	print $otdr::LOG $otdr::utils::subpre,"$i. $plist[$i]: $str\n";
    }
    
    return;
}

1;
