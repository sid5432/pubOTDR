#!/usr/bin/perl -w
use strict;
use Exporter;
# use FindBin qw($Bin);
# use lib "$Bin/../..";
use otdr::utils qw(get_val get_signed_val get_string get_hexstring);

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( process_fxdparams );

package otdr;

# *LOG = *STDERR;

sub process_fxdparams
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    if ( $var->{flavor} == 1 ) {
	return _process_fxdparams1($bufref, $pos, $var);
    }elsif($var->{flavor} == 2 ) {
	return _process_fxdparams2($bufref, $pos, $var);
    }else{
	
	return;
    }
}

# .................................................
# for Bellcore 1.x
sub _process_fxdparams1
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my $disp = sprintf "0x%02X", $pos;
    
    my ($str,$hex,$count);
    
    # functions to use
    # 'h': get_hexstring
    # 'v': get_val
    # 's': get_signed_val
    # 
    my @plist = (
	["date/time",0,4,'v','','',''], # ............... 0-3 seconds in Unix time
	["unit",4,2,'s','','',''], # .................... 4-5 distance units, 2 char (km,mt,ft,kf,mi)
	["wavelength",6,2,'v',0.1,1,'nm'], # ............ 6-7 wavelength (nm)
	
	# from Andrew Jones
	["acquisition offset",8,4,'i','','',''], # .............. 8-11 acquisition offset; units?
	["number of pulse width entries",12,2,'v','','',''], # .. 12-13 number of pulse width entries
		
	["pulse width",14,2,'v','',0,'ns'],  # .......... 14-15 pulse width (ns)
	["sample spacing", 16,4,'v',1e-8,'','usec'], # .. 16-19 sample spacing (in usec)
	["num data points", 20,4,'v','','',''], # ....... 20-23 number of data points
	["index", 24,4,'v',1e-5,6,''], # ................ 24-27 index of refraction
	["BC", 28,2,'v',-0.1,2,'dB'], # ................. 28-29 backscattering coeff
	["num averages", 30,4,'v','','',''], # .......... 30-33 number of averages
	["range", 34,4,'v',2e-5,6,'km'], # .............. 34-37 range (km)
	
	# from Andrew Jones
	["front panel offset",38,4,'i','','',''], # ................ 38-41
	["noise floor level",42,2,'v','','',''], # ................. 42-43 unsigned
	["noise floor scaling factor",44,2,'i','','',''], # ........ 44-45
	["power offset first point",46,2,'v','','',''], # .......... 46-47 unsigned
	
	["loss thr", 48,2,'v',0.001,3,'dB'], # .......... 48-49 loss threshold
	["refl thr", 50,2,'v',-0.001,3,'dB'], # ......... 50-51 reflection threshold
	["EOT thr",52,2,'v',0.001,3,'dB'], # ............ 52-53 end-of-transmission threshold
    );
    
    my $tmp;
    my $val;
    for(my $i=0; $i<= $#plist; $i++) {
	# print "DEBUG: '$plist[$i][0]', $plist[$i][1], $plist[$i][2]\n";

	if ( $plist[$i][3] eq 'i' ) { # signed int
	    ($val, $tmp) = get_signed_val($bufref, $pos+$plist[$i][1], $plist[$i][2]);
	    $str = "$val";
	}elsif ( $plist[$i][3] eq 'v' ) { # unsigned int
	    ($val, $tmp) = get_val($bufref, $pos+$plist[$i][1], $plist[$i][2]);
	    
	    if ( $plist[$i][0] =~ m/number of pulse width/o and $val > 1 ) {
		die("!!! Cannot deal with multiple number of pulse width entries yet!  Sorry.\n");
	    }
	    
	    if ($plist[$i][4] ne '' ) {
		$val *= $plist[$i][4];
	    }
	    if ( $plist[$i][5] ne '' ) {
		my $fmt = "%.$plist[$i][5]f";
		$str = sprintf $fmt, $val;
	    }else{
		$str = "$val";
	    }
	}elsif( $plist[$i][3] eq 'h' ) {
	    ($str, $tmp) = get_hexstring($bufref, $pos+$plist[$i][1], $plist[$i][2]);
	}elsif( $plist[$i][3] eq 's' ) {
	    my ($lhex,$lcount,$lpos);
	    ($str,$lhex,$lcount,$lpos) = get_string($bufref, $pos+$plist[$i][1], 2);
	    if ( $plist[$i][0] eq 'unit' ) {
		if ( $str eq 'mt' ) {
		    $str .= " (meters)";
		}elsif( $str eq 'mi' ) {
		    $str .= " (miles)";
		}elsif( $str eq 'kf' ) {
		    $str = " (kilo-ft)";
		}
	    }
	}else{
	    # default
	    ($str, $tmp) = get_hexstring($bufref, $pos+$plist[$i][1], $plist[$i][2]);
	}
	
	if ( $i == 0 ) { # unix time
	    my $dtime = localtime( $val );
	    $str = "$dtime ($val sec)";
	}
	
	my $label = "fxdparams::$plist[$i][0]";
	$var->{$label} = $str;
	my $unit = $plist[$i][6];
	
	print $otdr::LOG $otdr::utils::subpre,"$i. $plist[$i][0]: $str $unit\n";
    }
    
    # correction/adjustment:
    print $otdr::LOG "\n",$otdr::utils::subpre,"[adjusted for refractive index]\n";
    my $ior = $var->{"fxdparams::index"};
    my $dx = $var->{"fxdparams::sample spacing"} * $otdr::sol / $ior;
    $var->{"fxdparams::range"} =  $dx * $var->{"fxdparams::num data points"};
    $var->{"fxdparams::resolution"} = $dx*1000.0; # in meters
    
    print $otdr::LOG $otdr::utils::subpre,"resolution = ",($dx*1000.0)," m\n";
    print $otdr::LOG $otdr::utils::subpre,"range      = ",$var->{"fxdparams::range"}," km\n";
    
    return;
}

# ...............................................
# for Bellcore 2.x
sub _process_fxdparams2
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my ($str,$hex,$count);
    
    # header and '\0'
    ($str,$hex,$count,$pos)= get_string( $bufref, $pos );
    if ( $str ne 'FxdParams' ) {
	print $otdr::LOG $otdr::utils::pre," ERROR: should be FxdParams; got '$str' instead\n";
	return;
    }
    my $disp = sprintf "0x%02X", $pos;
    
    # functions to use
    # 'h': get_hexstring
    # 'v': get_val
    # 's': get_signed_val
    # 
    my @plist = (
	# name, start-pos, length (bytes), type, multiplier, precision, units
	#
	# type: display type: 'v' (value) or 'h' (hexidecimal) or 's' (string)
	["date/time",0,4,'v','','',''], # ............... 0-3 seconds in Unix time
	["unit",4,2,'s','','',''], # .................... 4-5 distance units, 2 char (km,mt,ft,kf,mi)
	["wavelength",6,2,'v',0.1,1,'nm'], # ............ 6-7 wavelength (nm)
	
	# from Andrew Jones
	["acquisition offset",8,4,'i','','',''], # .............. 8-11 acquisition offset; units?
	["acquisition offset distance",12,4,'i','','',''], # .... 12-15 acquisition offset distance; units?
	["number of pulse width entries",16,2,'v','','',''], # .. 16-17 number of pulse width entries
	
	
	["pulse width",18,2,'v','',0,'ns'],  # .......... 18-19 pulse width (ns)
	["sample spacing", 20,4,'v',1e-8,'','usec'], # .. 20-23 sample spacing (usec)
	["num data points", 24,4,'v','','',''], # ....... 24-27 number of data points
	
	["index", 28,4,'v',1e-5,6,''], # ................ 28-31 index of refraction
	["BC", 32,2,'v',-0.1,2,'dB'], # ................. 32-33 backscattering coeff
	
	["num averages", 34,4,'v','','',''], # .......... 34-37 number of averages
	
	# from Dmitry Vaygant:
	["averaging time", 38,2,'v',0.1,0,'sec'], # ..... 38-39 averaging time in seconds
	
	["range", 40,4,'v',2e-5,6,'km'], # .............. 40-43 range (km); note x2
	
	# from Andrew Jones
	["acquisition range distance",44,4,'i','','',''], # ........ 44-47
	["front panel offset",48,4,'i','','',''], # ................ 48-51
	["noise floor level",52,2,'v','','',''], # ................. 52-53 unsigned
	["noise floor scaling factor",54,2,'i','','',''], # ........ 54-55
	["power offset first point",56,2,'v','','',''], # .......... 56-57 unsigned
	
	["loss thr", 58,2,'v',0.001,3,'dB'], # .......... 58-59 loss threshold
	["refl thr", 60,2,'v',-0.001,3,'dB'], # ......... 60-61 reflection threshold
	["EOT thr",62,2,'v',0.001,3,'dB'], # ............ 62-63 end-of-transmission threshold
	["trace type",64,2,'s','','',''], # ............. 64-65 trace type (ST,RT,DT, or RF)
	
	# from Andrew Jones
	# ["unknown 3",66,16,'h','','',''], # ............. 66-81 ???
	["X1",66,4,'i','','',''], # ............. 66-69
	["Y1",70,4,'i','','',''], # ............. 70-73
	["X2",74,4,'i','','',''], # ............. 74-77
	["Y2",78,4,'i','','',''], # ............. 78-81
    );
    
    my $tmp;
    my $val;
    for(my $i=0; $i<= $#plist; $i++) {
	# print "DEBUG: '$plist[$i][0]', $plist[$i][1], $plist[$i][2]\n";

	if ( $plist[$i][3] eq 'i' ) { # signed int
	    ($val, $tmp) = get_signed_val($bufref, $pos+$plist[$i][1], $plist[$i][2]);
	    $str = "$val";
	}elsif ( $plist[$i][3] eq 'v' ) { # unsigned int
	    ($val, $tmp) = get_val($bufref, $pos+$plist[$i][1], $plist[$i][2]);
	    
	    if ( $plist[$i][0] =~ m/number of pulse width/o and $val > 1 ) {
		die("!!! Cannot deal with multiple number of pulse width entries yet!  Sorry.\n");
	    }
	    
	    if ($plist[$i][4] ne '' ) {
		$val *= $plist[$i][4];
	    }
	    if ( $plist[$i][5] ne '' ) {
		my $fmt = "%.$plist[$i][5]f";
		$str = sprintf $fmt, $val;
	    }else{
		$str = "$val";
	    }
	}elsif( $plist[$i][3] eq 'h' ) {
	    ($str, $tmp) = get_hexstring($bufref, $pos+$plist[$i][1], $plist[$i][2]);
	}elsif( $plist[$i][3] eq 's' ) {
	    ($str,$hex,$count,$tmp)= get_string( $bufref, $pos+$plist[$i][1], $plist[$i][2]);
	    if ( $plist[$i][0] eq 'unit' ) {
		if ( $str eq 'mt' ) {
		    $str .= " (meters)";
		}elsif( $str eq 'mi' ) {
		    $str .= " (miles)";
		}elsif( $str eq 'kf' ) {
		    $str = " (kilo-ft)";
		}
	    }
	}else{
	    # default
	    ($str, $tmp) = get_hexstring($bufref, $pos+$plist[$i][1], $plist[$i][2]);
	}
	
	if ( $i == 0 ) { # unix time
	    my $dtime = localtime( $val );
	    $str = "$dtime ($val sec)";
	}elsif( $plist[$i][0] eq 'trace type' ) {
	    if ( $str eq 'ST' ) {
		$str .= "[standard trace]";
	    }elsif ( $str eq 'RT' ) {
		$str .= "[reverse trace]";
	    }elsif ( $str eq 'DT' ) {
		$str .= "[difference trace]";
	    }elsif ( $str eq 'RF' ) {
		$str .= "[reference]";
	    }else{
		$str .= "[unknown]";
	    }
	}	
	
	my $label = "fxdparams::$plist[$i][0]";
	$var->{$label} = $str;
	my $unit = $plist[$i][6];
	
	print $otdr::LOG $otdr::utils::subpre,"$i. $plist[$i][0]: $str $unit\n";
    }
    
    # correction/adjustment:
    print $otdr::LOG "\n",$otdr::utils::subpre,"[adjusted for refractive index]\n";
    my $ior = $var->{"fxdparams::index"};
    my $dx = $var->{"fxdparams::sample spacing"} * $otdr::sol / $ior; # in km
    $var->{"fxdparams::range"} =  $dx * $var->{"fxdparams::num data points"};
    $var->{"fxdparams::resolution"} = $dx*1000.0; # in meters
    
    print $otdr::LOG $otdr::utils::subpre,"resolution = ",($dx*1000.0)," m\n";
    print $otdr::LOG $otdr::utils::subpre,"range      = ",$var->{"fxdparams::range"}," km\n";
    
    return;
}

1;
