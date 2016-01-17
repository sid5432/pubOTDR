#!/usr/bin/perl -w
use strict;
use Digest::CRC;
use Exporter;
# use FindBin qw($Bin);
# use lib "$Bin/../..";
use otdr::utils qw(get_val get_signed_val get_string get_hexstring);

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( process_cksum calc_cksum );

package otdr;

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
	    print $otdr::LOG $otdr::utils::pre," ERROR: should be Cksum; got '$str' instead\n";
	    return;
	}
    }
    
    my $val;
    
    ($val,$pos) = get_val($bufref, $pos, 2);
    my $disp = sprintf "0x%04X", $val;
    
    print $otdr::LOG $otdr::utils::subpre,"checksum $val ($disp)\n";
    return;
}

sub calc_cksum
{
    my $bufref = shift;
    my $var = shift;
    
    my $b1 = $bufref->[-1];
    my $b2 = $bufref->[-2];
    
    # calculate checksum from last two bytes
    # my $file_cksum = ord($b1)*256 + ord($b2);
    # my $hex = sprintf "0x%02x%02x", ord($b1), ord($b2);
    # print "* File checksum is $file_cksum ($hex) <----------\n";
    
    # swap last two bytes (because little endian)
    $bufref->[-1] = $b2;
    $bufref->[-2] = $b1;
    
    my $ctx = Digest::CRC->new(width=>16, poly=>0x1021, init=>0xffff, refin=>0, refout=>0,
	xorout=>0x0000, cont=>0); # check=0x29b1 name="CRC-16/CCITT-FALSE"    
    
    # sanity check; don't really need this
    my $digest;
    if ( 0 ) {
	$ctx->add("123456789");
	$digest = $ctx->digest;
	if ( $digest != 0x29b1 ) {
	    print $otdr::LOG $otdr::utils::subpre,"CRC-16/CCITT-FALSE algorithm failed!\n";
	}else{
	    # printf "* CRC-16/CCITT-FALSE digest check is %d (0x%x)\n", $digest, $digest;
	    print $otdr::LOG $otdr::utils::subpre,"[ CRC-16/CCITT-FALSE digest algorithm looks okay ]\n";
	}
    }
    my $buffer = join('',@{$bufref});
    $ctx->add($buffer);
    
    $digest = $ctx->digest;
    # print $otdr::utils::subpre,"CRC-16/CCITT-FALSE digest is %d (0x%x)\n", $digest, $digest;
    if ( $digest == 0 ) {
	print $otdr::LOG $otdr::utils::subpre,"checksum MATCHES!\n";
    }else{
	print $otdr::LOG $otdr::utils::subpre,"checksum DOES NOT MATCH!\n";
    }
    
    return $digest;
}

1;
