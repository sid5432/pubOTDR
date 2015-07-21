#!/usr/bin/perl -w
package otdr::utils;
use strict;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( get_string get_val get_signed_val get_hexstring );

# export by default
# our @EXPORT = qw( get_string get_val get_hexstring );

# can be redfined
$otdir::utils::pre = "MAIN: ";
$otdir::utils::subpre = "    : ";

*LOG = *STDERR;

# =======================================================
# subroutines:
#  - all $bufref arguments are references to array
#  - no shifting of array
#  - little-endian
sub get_val
{
    # get unsigned integer; 2 bytes by default
    # return value and next position
    my $bufref = shift;
    my $start = shift;
    my $nn = shift || 2; # number of bytes

    my $val = 0;
    my $j = $start + $nn - 1;
    for(my $i=0; $i<$nn; $i++) {
	if ( $j > $#{$bufref} ) {
	    print $otdir::utils::pre,"ERROR: array index out of range\n";
	    print LOG "ERROR: array index out of range\n";
	    last;
	}
	$val = $val * 256 + ord($$bufref[$j]);
	$j--;
    }
    
    return ($val, $start+$nn);
}

# .............................................................
sub get_signed_val
{
    # get signed integer; 2 bytes by default
    my $bufref = shift;
    my $start = shift;
    my $nn = shift || 2;
    
    my $val = 0;
    my $j = $start + $nn - 1;
    for(my $i=0; $i<$nn; $i++) {
	if ( $j > $#{$bufref} ) {
	    print $otdir::utils::pre,"ERROR: array index out of range\n";
	    print LOG "ERROR: array index out of range\n";
	    last;
	}
	$val = $val * 256 + ord($$bufref[$j]);
	$j--;
    }
    
    my $th = 0x1 << (8*$nn-1);
    my $sub = ($th << 1);
    if ( $val & $th ) {
	$val -= $sub;
    }
    
    return ($val, $start+$nn);
}

# ...............................................
sub get_hexstring
{
    # get hex repr of next $nn bytes;
    # return position of next byte
    my $bufref = shift;
    my $start = shift;
    my $nn = shift;

    my $str = "";
    
    for(my $i=$start; $i<$start+$nn; $i++) {
	if ( $i > $#{$bufref} ) {
	    print $otdir::utils::pre,"ERROR: array index out of range\n";
	    print LOG "ERROR: array index out of range\n";
	    last;
	}
	$str .= sprintf "%02X ", ord($$bufref[$i]);
    }
    
    return ($str, $start+$nn);
}

# ...........................................................
sub get_string
{
    my $bufref = shift;
    my $start  = shift;
    my $nn     = shift || 0;

    if ( $nn == 0 ) {
	return _get_string($bufref, $start);
    }else{
	return _get_string_fixed($bufref, $start, $nn);
    }	
}
# ...........................................................
sub _get_string_fixed
{
    # get next string, length $nn bytes; return:
    #  - string
    #  - hex string
    #  - number of bytes (not including terminating '\0')
    #  - position of next byte after terminating '\0'
    #
    # but return early if encounter '\0'
    #
    my $bufref = shift;
    my $start  = shift;
    my $nn     = shift;
    
    my $str = "";
    my $hex = "";
    my $count = 0;
    my $pos;
    
    for($pos=$start; $pos<$start+$nn; $pos++) {
	if ( ord($$bufref[$pos]) == 0 ) {
	    $pos++;
	    last;
	}
	if ( $pos > $#{$bufref} ) {
	    print $otdir::utils::pre,"ERROR: array index out of range (2)\n";
	    print LOG "ERROR: array index out of range (2)\n";
	    last;	    
	}
	
	$str .= $$bufref[$pos];
	$hex .= sprintf "%02X ", ord($$bufref[$pos]);
	$count++;
    }
    
    return ($str, $hex, $count, $pos);
}
# ...........................................................
sub _get_string
{
    # get next '\0'-terminated string; return:
    #  - string
    #  - hex string
    #  - number of bytes (not including terminating '\0')
    #  - position of next byte after terminating '\0'
    #
    my $bufref = shift;
    my $start  = shift;
    
    my $str = "";
    my $hex = "";
    my $count = 0;
    
    my $pos = $start;
    
    while( $pos <= $#{$bufref} ) {
	if ( ord($$bufref[$pos]) == 0 ) {
	    $pos++;
	    last;
	}
	$str .= $$bufref[$pos];
	$hex .= sprintf "%02X ", ord($$bufref[$pos]);
	$count++;
	$pos++;
    }
    
    return ($str, $hex, $count, $pos);
}

1;
