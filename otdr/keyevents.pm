#!/usr/bin/perl -w
package otdr::keyevents;
use strict;
use Exporter;
use FindBin qw($Bin);
use lib "$Bin/.";
use otdr::utils qw(get_val get_signed_val get_string get_hexstring);

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( process_keyevents );

*LOG = *STDERR;

sub process_keyevents
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my ($str,$hex,$count, $val);
    
    if($var->{flavor} == 1 ) {
	return _process_keyevents1($bufref, $pos, $var);
    }elsif($var->{flavor} == 2 ) {
	return _process_keyevents2($bufref, $pos, $var);
    }
    
    print $otdr::utils::pre," Unrecognized flavor $var->{flavor}\n";
    return;
}

# ...............................................
sub _process_keyevents1
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my $pre = $otdr::utils::pre; # spacers for output formatting
    my $subpre = $otdr::utils::subpre;
    my ($str,$hex,$count, $val);
    
    # number of events
    ($val,$pos) = get_val($bufref, $pos, 2);
    my $nev = $val;
      
    print $subpre,"$nev events\n";
    $var->{num_events} = $nev;
    
    
    my $factor = 2e-5 * $var->{MAGIC_SCALE}/$var->{"fxdparams::index"};
    
    my ($id,$dist,$slope,$splice,$refl);
    my $type;
    my ($end_event,$start_next);
    my ($seg1,$seg2);
    my $ukno;
    my $comments;
    
    for(my $j=0; $j<$nev; $j++) {
	($id,$pos)   = get_val($bufref, $pos, 2);
	($dist,$pos) = get_val($bufref, $pos, 4);
	$dist *= $factor;
	
	($slope,$pos)  = get_signed_val($bufref, $pos, 2);
	$slope *= 0.001;
	
	($splice,$pos) = get_signed_val($bufref, $pos, 2);
	$splice *= 0.001;
	
	($refl,$pos)   = get_signed_val($bufref, $pos, 4);
	$refl *= 0.001;
	
	($type,$hex,$count,$pos) = get_string( $bufref, $pos, 8 );
	
	if ( $type =~ m/(.)(.)9999LS/o ) {
	    my $subtype = $1;
	    my $manual = $2;
	    if ( $manual eq 'A' ) {
		$type .= " {manual}";
	    }else{
		$type .= " {auto}";
	    }
	    
	    if( $subtype eq '1' ) {
		$type .= " reflection";
	    }elsif( $subtype eq '0' ) {
		$type .= " loss/drop/gain";
	    }elsif( $subtype eq '2' ) {
		$type .= " multiple";
	    }else{
		$type .= " unknown '$subtype'";
	    }
		
	}else{
	    $type .= " [unknown type $type]";
	}
	
	($comments,$hex,$count,$pos) = get_string( $bufref, $pos );
	
	print $subpre,"Event $id: type $type\n";
	print $subpre,$subpre," distance: $dist km\n";
	print $subpre,$subpre," slope: $slope dB/km\n";
	print $subpre,$subpre," splice loss: $splice dB\n";
	print $subpre,$subpre," refl loss: $refl dB\n";
	print $subpre,$subpre," comments: $comments\n";
    }
    
    my ($total_loss,$fibstart,$fiblength, $orl, $fibstart2,$fiblength2);
    
    if ( 0 ) {
	my $disp = sprintf "0x%04X", $pos;
	print "DEBUG............. next pos $disp ...........\n";
	my $seg1;
	($seg1,$pos) = get_hexstring($bufref, $pos, 22);
	print "\n\n$seg1\n\n";
	# rewind
	$pos -= 22;
	$disp = sprintf "0x%04X", $pos;
	print "DEBUG............. reset: next pos $disp ...........\n";
    }
    
    ($total_loss,$pos) = get_val($bufref, $pos, 4);
    $total_loss *= 0.001;
    
    ($fibstart,$pos)   = get_hexstring($bufref, $pos, 4);
    # $fibstart *= $factor;
    
    ($fiblength,$pos)  = get_val($bufref, $pos, 4);
    $fiblength *= $factor;
    
    ($orl,$pos)        = get_val($bufref,$pos,2);
    $orl *= 0.001;
    
    ($fibstart2,$pos)  = get_hexstring($bufref, $pos, 4);
    # $fibstart2 *= $factor;
    
    ($fiblength2,$pos) = get_val($bufref, $pos, 4);
    $fiblength2 *= $factor;
    
    print $subpre,"Summary:\n";
    print $subpre,$subpre," total loss: $total_loss dB\n";
    print $subpre,$subpre," ORL: $orl dB\n";
    print $subpre,$subpre," fiber length: $fiblength km (dup $fiblength2 km)\n";
    print $subpre,$subpre," unknown: $fibstart (dup $fibstart2)\n";
    
    return;
}
# ...............................................
sub _process_keyevents2
{
    my $bufref = shift;
    my $pos = shift;
    my $var = shift;
    
    my $pre = $otdr::utils::pre; # spacers for output formatting
    my $subpre = $otdr::utils::subpre;
    my ($str,$hex,$count, $val);
    
    # header and '\0'
    ($str,$hex,$count,$pos)= get_string( $bufref, $pos );
    if ( $str ne 'KeyEvents' ) {
	print $otdr::utils::pre," ERROR: should be KeyEvents; got '$str' instead\n";
	return;
    }
    
    # number of events
    ($val,$pos) = get_val($bufref, $pos, 2);
    my $nev = $val;
      
    print $subpre,"$nev events\n";
    $var->{num_events} = $nev;
    
    my $factor = 2e-5 * $var->{MAGIC_SCALE}/$var->{"fxdparams::index"};
    
    my ($id,$dist,$slope,$splice,$refl);
    my $type;
    my ($end_event,$start_next);
    my ($seg1,$seg2);
    my $ukno;
    my $comments;
    
    for(my $j=0; $j<$nev; $j++) {
	($id,$pos)   = get_val($bufref, $pos, 2);
	
	($dist,$pos) = get_val($bufref, $pos, 4);
	$dist *= $factor;
	
	($slope,$pos)  = get_signed_val($bufref, $pos, 2);
	$slope *= 0.001;
	
	($splice,$pos) = get_signed_val($bufref, $pos, 2);
	$splice *= 0.001;
	
	($refl,$pos)   = get_signed_val($bufref, $pos, 4);
	$refl *= 0.001;
	
	($type,$hex,$count,$pos) = get_string( $bufref, $pos, 8 );
	
	if ( $type =~ m/(.)(.)9999LS/o ) {
	    my $subtype = $1;
	    my $manual = $2;
	    if ( $manual eq 'A' ) {
		$type .= " {manual}";
	    }else{
		$type .= " {auto}";
	    }
	    
	    if( $subtype eq '1' ) {
		$type .= " reflection";
	    }elsif( $subtype eq '0' ) {
		$type .= " loss/drop/gain";
	    }elsif( $subtype eq '2' ) {
		$type .= " multiple";
	    }else{
		$type .= " unknown '$subtype'";
	    }
		
	}else{
	    $type .= " [unknown type $type]";
	}
	
	($seg1,$pos) = get_hexstring($bufref, $pos, 8);
	($seg2,$pos) = get_hexstring($bufref, $pos, 8);
	
	# rewind
	$pos -= 8;
	
	($end_event,$pos)  = get_val($bufref,$pos,4);
	$end_event  *= $factor;
	
	($start_next,$pos) = get_val($bufref,$pos,4);
	$start_next *= $factor;
	
	($ukno,$pos) = get_hexstring($bufref, $pos, 4); # unknown 4 bytes

	($comments,$hex,$count,$pos) = get_string( $bufref, $pos );
	
	print $subpre,"Event $id: type $type\n";
	print $subpre,$subpre," distance: $dist km\n";
	print $subpre,$subpre," slope: $slope dB/km\n";
	print $subpre,$subpre," splice loss: $splice dB\n";
	print $subpre,$subpre," refl loss: $refl dB\n";
	print $subpre,$subpre," end-event: $end_event km\n";
	print $subpre,$subpre," start-next: $start_next km\n";
	
	print $subpre,$subpre," segments: $seg1 | $seg2\n";
	print $subpre,$subpre," (unknown): $ukno\n";
	print $subpre,$subpre," comments: $comments\n";
    }
    
    my ($total_loss,$fibstart,$fiblength, $orl, $fibstart2,$fiblength2);

    my $disp;
    
    ($total_loss,$pos) = get_val($bufref, $pos, 4);
    $total_loss *= 0.001;
    
    ($fibstart,$pos)   = get_signed_val($bufref, $pos, 4);
    $fibstart *= $factor;
    
    ($fiblength,$pos)  = get_val($bufref, $pos, 4);
    $fiblength *= $factor;
    
    ($orl,$pos)        = get_val($bufref,$pos,2);
    $orl *= 0.001;
    
    ($fibstart2,$pos)  = get_signed_val($bufref, $pos, 4);
    $fibstart2 *= $factor;
    
    ($fiblength2,$pos) = get_val($bufref, $pos, 4);
    $fiblength2 *= $factor;
    
    print $subpre,"Summary:\n";
    print $subpre,$subpre," total loss: $total_loss dB\n";
    print $subpre,$subpre," ORL: $orl dB\n";
    print $subpre,$subpre," fiber length: $fiblength km (dup $fiblength2 km)\n";
    print $subpre,$subpre," fiber start: $fibstart km (dup $fibstart2 km) [internal buffer]\n";
    
    return;
}

1;
