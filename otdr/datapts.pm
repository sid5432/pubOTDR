#!/usr/bin/perl -w
package otdr;
use strict;
use Exporter;
# use FindBin qw($Bin);
# use lib "$Bin/../..";
use otdr::utils qw(get_val get_signed_val get_string get_hexstring);

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( process_datapts );

# *LOG = *STDERR;

# method used by STV: minimum reading shifted to zero
# method used by AFL/Noyes Trace.Net: maximum reading shifted to zero (approx)
my $offset = "STV"; # "AFL" or "STV"
  
sub process_datapts
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    my $filename = shift || "trace.dat";
    
    if ( $var->{flavor} == 1 ) {
	return _process_datapts1($bufref, $pos, $var, $filename);
    }elsif($var->{flavor} == 2 ) {
	return _process_datapts2($bufref, $pos, $var, $filename);
    }else{
	
	return;
    }
}

# .................................................
# for Bellcore 1.x
sub _process_datapts1
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    my $filename = shift || "trace.dat";
    
    my ($str,$hex,$count, $val);
    
    if ( $var->{'supparams::OTDR'} eq 'OFL250' ) {
	# old Noyes/AFL OFL250 model is off by factor of 10
	print $otdr::LOG $otdr::utils::subpre,"Adjusting for old OFL250 model\n";
	$var->{xscaling} = 0.1;
    }
    
    # initial 12 bytes
    print $otdr::LOG $otdr::utils::subpre,"[initial 12 byte header follows]\n";
    
    ($val,$pos) = get_val( $bufref, $pos, 4 );
    print $otdr::LOG $otdr::utils::subpre,"num data points = $val\n";
    my $N = $val;
    
    if ( $N ne $var->{"fxdparams::num data points"} ) {
	print $otdr::LOG $otdr::utils::subpre,"!!! WARNING !!! block says number of data points ".
	  "is $N instead of ",$var->{"fxdparams::num data points"},"\n";
    }
    
    ($val,$pos) = get_val( $bufref, $pos, 2 );
    print $otdr::LOG $otdr::utils::subpre,"unknown #1 = $val\n";

    ($val,$pos) = get_val( $bufref, $pos, 4 );
    print $otdr::LOG $otdr::utils::subpre,"num data points again = $val\n";
    
    ($val,$pos) = get_val( $bufref, $pos, 2 );
    print $otdr::LOG $otdr::utils::subpre,"unknown #2 = $val\n";
    
    # print $otdr::LOG $otdr::utils::subpre,"next pos $pos\n";
    
    # this is the adjusted value
    my $dx = $var->{"fxdparams::resolution"};
    
    my $max = 0;
    my $min = 65536;
    
    my @dlist = ();
    
    for(my $i=0; $i<$N; $i++) {
	($val,$pos) = get_val($bufref, $pos, 2);
	push @dlist, $val;
	
	$max = ($max > $val)? $max: $val;
	$min = ($min < $val)? $min: $val;
    }
    my $disp_min = sprintf "%.3f", $min/1000.0;
    my $disp_max = sprintf "%.3f", $max/1000.0;
    
    print $otdr::LOG $otdr::utils::subpre,"before applying offset: max $disp_max dB, min $disp_min dB\n";
    
    open(OUTPUT,">$filename") or die("Can not write to $filename\n");
    my $x = 0;
    
    for(my $i=0; $i<$N; $i++) {
	# convert/scale to dB
	if ( $offset eq 'STV' ) {
	    $val = ($max - $dlist[$i])* 0.001;
	}elsif ( $offset eq 'AFL' ) {
	    $val = ($min - $dlist[$i])* 0.001;
	}else{ # invert
	    $val = -$dlist[$i]*0.001;
	}
	# more work but (maybe) less rounding issues
	$x = $dx * $i * $var->{xscaling} / 1000.0; # output in meters
	print OUTPUT "$x\t$val\n";
    }
    close OUTPUT;
    
    return;
}

# ...............................................
# for Bellcore 2.x
sub _process_datapts2
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    my $filename = shift || "trace.dat";
    
    my ($str,$hex,$count, $val);
    
    # header and '\0'
    ($str,$hex,$count,$pos)= get_string( $bufref, $pos );
    if ( $str ne 'DataPts' ) {
	print $otdr::LOG $otdr::utils::pre," ERROR: should be DataPts; got '$str' instead\n";
	return;
    }
    # my $disp = sprintf "0x%02X", $pos;
    
    # initial 12 bytes
    print $otdr::LOG $otdr::utils::subpre,"[initial 12 byte header follows]\n";
    
    ($val,$pos) = get_val( $bufref, $pos, 4 );
    print $otdr::LOG $otdr::utils::subpre,"num data points = $val\n";
    my $N = $val;
    
    if ( $N ne $var->{"fxdparams::num data points"} ) {
	print $otdr::LOG $otdr::utils::subpre,"!!! WARNING !!! block says number of data points ".
	  "is $N instead of ",$var->{"fxdparams::num data points"},"\n";
    }
    
    ($val,$pos) = get_val( $bufref, $pos, 2 );
    print $otdr::LOG $otdr::utils::subpre,"unknown #1 = $val\n";

    ($val,$pos) = get_val( $bufref, $pos, 4 );
    print $otdr::LOG $otdr::utils::subpre,"num data points again = $val\n";
    
    ($val,$pos) = get_val( $bufref, $pos, 2 );
    print $otdr::LOG $otdr::utils::subpre,"unknown #2 = $val\n";
    
    # print $otdr::LOG $otdr::utils::subpre,"next pos $pos\n";
    
    # this is the adjusted value
    my $dx = $var->{"fxdparams::resolution"};
    
    my $max = 0;
    my $min = 65536;
    
    my @dlist = ();
    
    for(my $i=0; $i<$N; $i++) {
	($val,$pos) = get_val($bufref, $pos, 2);
	push @dlist, $val;
	
	$max = ($max > $val)? $max: $val;
	$min = ($min < $val)? $min: $val;
    }
    my $disp_min = sprintf "%.3f", $min/1000.0;
    my $disp_max = sprintf "%.3f", $max/1000.0;
    
    print $otdr::LOG $otdr::utils::subpre,"before applying offset: max $disp_max dB, min $disp_min dB\n";
    
    open(OUTPUT,">$filename") or die("Can not write to $filename\n");
    my $x = 0;
    
    for(my $i=0; $i<$N; $i++) {
	# convert/scale to dB
	if ( $offset eq 'STV' ) {
	    $val = ($max - $dlist[$i])* 0.001;
	}elsif ( $offset eq 'AFL' ) {
	    $val = ($min - $dlist[$i])* 0.001;
	}else{ # invert
	    $val = -$dlist[$i]*0.001;
	}
	$x = $dx * $i; # more work but (maybe) less rounding issues
	print OUTPUT "$x\t$val\n";
    }
    close OUTPUT;
    
    return;
}

1;
