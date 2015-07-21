#!/usr/bin/perl -w
package otdr::cksum;
use strict;
use Exporter;
use FindBin qw($Bin);
use lib "$Bin/.";
use otdr::utils qw(get_val get_signed_val get_string get_hexstring);

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( process_cksum );

*LOG = *STDERR;

sub process_cksum
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my ($str,$hex,$count);
    
    # header and '\0'
    if ( $var->{flavor} == 2 ) {
	($str,$hex,$count,$pos)= get_string( $bufref, $pos );
	if ( $str ne 'Cksum' ) {
	    print $otdr::utils::pre," ERROR: should be Cksum; got '$str' instead\n";
	    return;
	}
    }
    
    my $val;
    
    ($val,$pos) = get_val($bufref, $pos, 2);
    my $disp = sprintf "0x%04X", $val;
    
    print $otdr::utils::subpre,"checksum $val ($disp)\n";
    return;
}
