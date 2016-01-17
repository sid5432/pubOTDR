#!/usr/bin/perl -w
use strict;
use Exporter;
# use FindBin qw($Bin);
# use lib "$Bin/../..";
use otdr::utils qw(get_val get_string get_hexstring);

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( process_genparams );

package otdr;

*LOG = *STDERR;

sub process_genparams
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    if ( $var->{flavor} == 1 ) {
	return _process_genparams1($bufref, $pos, $var);
    }elsif($var->{flavor} == 2 ) {
	return _process_genparams2($bufref, $pos, $var);
    }else{
	
	return;
    }
}

# .................................................
# for Bellcore 1.x
sub _process_genparams1
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my ($str,$hex,$count);
    
    # next two bytes should be language
    ($str,$hex,$count,$pos)= get_string( $bufref, $pos, 2 );
    my $lang = $str;
    if ( $count != 2 ) {
	print $otdr::LOG $otdr::utils::pre,"ERROR: language should be two bytes; got $count bytes ($hex)\n";
	# print LOG "ERROR: language should be two bytes; got $count bytes ($hex)\n";
	return;
    }
    print $otdr::LOG $otdr::utils::subpre," language: '$lang', next pos $pos\n";

    my @plist = (
	"cable ID",    # ........... 0
	"fiber ID",    # ........... 1
	"wavelength",  # ............2: fixed 2 bytes value
	
	"location A", # ............ 3
	"location B", # ............ 4
	"cable code/fiber type", # ............ 5
	"build condition", # ....... 6: fixed 2 bytes char/string
	"(unknown 2)", # ........... 7: fixed 4 bytes
	"operator",    # ........... 8
	"comments",    # ........... 9
    );

    my $tmp;
    my $val;
    for(my $i=0; $i<= $#plist; $i++) {
	if ( $i==6 ) { # build condition
	    ($str,$hex,$count,$pos)= get_string( $bufref, $pos, 2 );
	    $str = build_condition( $str );
	}elsif ( $i==2 ) { # wavelength
	    ($val,$pos) = get_val( $bufref, $pos, 2 );
	    $str = "$val nm";
	}elsif( $i==7 ) { # unknown 2; 4 bytes
	    ($val,$pos) = get_val( $bufref, $pos, 4 );
	    $str = sprintf "VALUE $val";
	}else{
	    ($str,$hex,$count,$pos)= get_string( $bufref, $pos );
	    # print "DEBUG: get $plist[$i] ... '$str' ($hex) $count bytes\n";
	}
	
	my $label = "genparams::$plist[$i]";
	$var->{$label} = $str;
	
	print $otdr::LOG $otdr::utils::subpre,"$i. $plist[$i]: $str\n";
    }
    
    return;
}

# ...............................................
# for Bellcore 2.x
sub _process_genparams2
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my ($str,$hex,$count);
    
    # header and '\0'
    ($str,$hex,$count,$pos)= get_string( $bufref, $pos );
    if ( $str ne 'GenParams' ) {
	print $otdr::LOG $otdr::utils::pre," ERROR: should be GenParams; got '$str' instead\n";
	return;
    }
    
    # next two bytes should be language
    ($str,$hex,$count,$pos)= get_string( $bufref, $pos, 2 );
    my $lang = $str;
    if ( $count != 2 ) {
	print $otdr::LOG $otdr::utils::pre,"ERROR: language should be two bytes; got $count bytes ($hex)\n";
	# print LOG "ERROR: language should be two bytes; got $count bytes ($hex)\n";
	return;
    }
    print $otdr::LOG $otdr::utils::subpre," language: '$lang', next pos $pos\n";
    
    my @plist = (
	"cable ID",    # ........... 0
	"fiber ID",    # ........... 1
	
	"fiber type",  # ........... 2: fixed 2 bytes value
	"wavelength",  # ............3: fixed 2 bytes value
	
	"location A", # ............ 4
	"location B", # ............ 5
	"cable code/fiber type", # ............ 6
	"build condition", # ....... 7: fixed 2 bytes char/string
	"(unknown 2)", # ........... 8: fixed 8 bytes
	"operator",    # ........... 9
	"comments",    # ........... 10
    );

    my $tmp;
    my $val;
    for(my $i=0; $i<= $#plist; $i++) {
	if ( $i==7 ) { # build condition
	    ($str,$hex,$count,$pos)= get_string( $bufref, $pos, 2 );
	    $str = build_condition( $str );
	}elsif ( $i==2 ) { # fiber type
	    ($val,$pos) = get_val( $bufref, $pos, 2 );
	    $str = fiber_type( "$val" );
	}elsif ( $i==3 ) { # wavelength
	    ($val,$pos) = get_val( $bufref, $pos, 2 );
	    $str = "$val nm";
	}elsif( $i==8 ) {
	    ($val,$pos) = get_val( $bufref, $pos, 8 );
	    $str = sprintf "VALUE $val";
	}else{
	    ($str,$hex,$count,$pos)= get_string( $bufref, $pos );
	}

	my $label = "genparams::$plist[$i]";
	$var->{$label} = $str;
	print $otdr::LOG $otdr::utils::subpre,"$i. $plist[$i]: $str\n";
    }
    
    return;
}

# .........................................................
# REF: http://www.ciscopress.com/articles/article.asp?p=170740&seqNum=7
sub fiber_type
{
    my $str = shift;
    
    if ( $str == '651' ) { # ITU-T G.651
	$str = "G.651 (50um core multimode)";
    }elsif( $str == '652' ) { # standard nondispersion-shifted 
	$str = "G.652 (standard SMF)";
	# G.652.C low Water Peak Nondispersion-Shifted Fiber		
    }elsif( $str == '653' ) {
	$str = "G.653 (dispersion-shifted fiber)";
    }elsif( $str == '654' ) {
	$str = "G.654 (1550nm loss-minimzed fiber)";
    }elsif( $str == '655' ) {
	$str = "G.655 (nonzero dispersion-shifted fiber)";
    }else{
	$str .= " (unknown)";
    }	    
    
    return $str;
}

# ..............................................................
sub build_condition
{
    my $str = shift;
    
    if ( $str eq 'BC' ) {
	$str .= " (as-built)";
    }elsif( $str eq 'CC' ) {
	$str .= " (as-current)";
    }elsif( $str eq 'RC' ) {
	$str .= " (as-repaired)";
    }elsif( $str eq 'OT' ) {
	$str .= " (other)";
    }else{
	$str .= " (unknown)";
    }
    return $str;
}

1;
