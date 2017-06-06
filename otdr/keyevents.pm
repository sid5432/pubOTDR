#!/usr/bin/perl -w
use strict;
use Exporter;
# use FindBin qw($Bin);
# use lib "$Bin/../..";
use otdr::utils qw(get_val get_signed_val get_string get_hexstring);

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( process_keyevents );

package otdr;

# *LOG = *STDERR;

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
    
    print $otdr::LOG $otdr::utils::pre," Unrecognized flavor $var->{flavor}\n";
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
      
    print $otdr::LOG $subpre,"$nev events\n";
    $var->{num_events} = $nev;
    
    
    my $factor = 1e-4 * $otdr::sol / $var->{"fxdparams::index"};
    
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
	
	print $otdr::LOG $subpre,"Event $id: type $type\n";
	print $otdr::LOG $subpre,$subpre," distance: $dist km\n";
	print $otdr::LOG $subpre,$subpre," slope: $slope dB/km\n";
	print $otdr::LOG $subpre,$subpre," splice loss: $splice dB\n";
	print $otdr::LOG $subpre,$subpre," refl loss: $refl dB\n";
	print $otdr::LOG $subpre,$subpre," comments: $comments\n";
    }
    
    my ($total_loss,$loss_start,$loss_finish, $orl, $orl_start,$orl_finish);
    
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
    
    ($total_loss,$pos) = get_signed_val($bufref, $pos, 4); # 00-03: total loss
    $total_loss *= 0.001;

    ($loss_start,$pos) = get_signed_val($bufref, $pos, 4); # 04-07: loss start position
    $loss_start *= $factor;
    
    ($loss_finish,$pos)= get_val($bufref, $pos, 4);        # 08-11: loss finish position
    $loss_finish *= $factor;
    
    ($orl,$pos)        = get_val($bufref,$pos,2);          # 12-13: optical return loss (ORL)
    $orl *= 0.001;
    
    ($orl_start,$pos)  = get_signed_val($bufref, $pos, 4); # 14-17: ORL start position
    $orl_start *= $factor;
    
    ($orl_finish,$pos) = get_val($bufref, $pos, 4);        # 18-21: ORL finish position
    $orl_finish *= $factor;
    
    print $otdr::LOG $subpre,"Summary:\n";
    print $otdr::LOG $subpre,$subpre," total loss: $total_loss dB\n";
    print $otdr::LOG $subpre,$subpre," ORL: $orl dB\n";
    print $otdr::LOG $subpre,$subpre," loss start: $loss_start km\n";
    print $otdr::LOG $subpre,$subpre," loss end: $loss_finish km\n";
    print $otdr::LOG $subpre,$subpre," ORL start: $orl_start km\n";
    print $otdr::LOG $subpre,$subpre," ORL finish: $orl_finish km)\n";
    
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
	print $otdr::LOG $otdr::utils::pre," ERROR: should be KeyEvents; got '$str' instead\n";
	return;
    }
    
    # number of events
    ($val,$pos) = get_val($bufref, $pos, 2);
    my $nev = $val;
      
    print $otdr::LOG $subpre,"$nev events\n";
    $var->{num_events} = $nev;
    
    my $factor = 1e-4 * $otdr::sol / $var->{"fxdparams::index"};
    
    my ($id,$dist,$slope,$splice,$refl);
    my $type;
    my ($end_prev,$start_curr,$end_curr,$start_next);
    my $pkpos;
    my $comments;
    
    for(my $j=0; $j<$nev; $j++) {
	($id,$pos)   = get_val($bufref, $pos, 2); # 00-01: event number
	
	($dist,$pos) = get_val($bufref, $pos, 4); # 02-05: time-of-travel; need to convert to distance
	$dist *= $factor; # convert time to distance

	($slope,$pos)  = get_signed_val($bufref, $pos, 2); # 06-07: slope
	$slope *= 0.001;
	
	($splice,$pos) = get_signed_val($bufref, $pos, 2); # 08-09: splice loss
	$splice *= 0.001;
	
	($refl,$pos)   = get_signed_val($bufref, $pos, 4); # 10-13: reflection loss
	$refl *= 0.001;
	
	($type,$hex,$count,$pos) = get_string( $bufref, $pos, 8 ); # 14-21: event type
	
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
	
	($end_prev,$pos)  = get_val($bufref,$pos,4); # 22-25: end of previous event
	$end_prev  *= $factor;
	
	($start_curr,$pos) = get_val($bufref,$pos,4); # 26-29: start of current event
	$start_curr *= $factor;
		
	($end_curr,$pos) = get_val($bufref, $pos, 4); # 30-33: end of current event
	$end_curr *= $factor;
	
	($start_next,$pos) = get_val($bufref, $pos, 4); # 34-37: start of next event
	$start_next *= $factor;
	
	($pkpos,$pos) = get_val($bufref, $pos, 4); # 38-41: peak point of event
	$pkpos *= $factor;
	
	($comments,$hex,$count,$pos) = get_string( $bufref, $pos );
	
	print $otdr::LOG $subpre,"Event $id: type $type\n";
	print $otdr::LOG $subpre,$subpre," distance: $dist km\n";
	print $otdr::LOG $subpre,$subpre," slope: $slope dB/km\n";
	print $otdr::LOG $subpre,$subpre," splice loss: $splice dB\n";
	print $otdr::LOG $subpre,$subpre," refl loss: $refl dB\n";
	print $otdr::LOG $subpre,$subpre," end of previous event: $end_prev km\n";
	print $otdr::LOG $subpre,$subpre," start of current event: $start_curr km\n";
	print $otdr::LOG $subpre,$subpre," end of current event: $end_curr km\n";
	print $otdr::LOG $subpre,$subpre," start of next event: $start_next km\n";
	print $otdr::LOG $subpre,$subpre," peak point of event: $pkpos km\n";
	
	print $otdr::LOG $subpre,$subpre," comments: $comments\n";
    }
    
    my ($total_loss,$loss_start,$loss_finish, $orl, $orl_start,$orl_finish);

    my $disp;
    
    ($total_loss,$pos) = get_signed_val($bufref, $pos, 4); # 00-03: total loss
    $total_loss *= 0.001;
    
    ($loss_start,$pos) = get_signed_val($bufref, $pos, 4); # 04-07: loss start position
    $loss_start *= $factor;
    
    ($loss_finish,$pos)= get_val($bufref, $pos, 4);        # 08-11: loss finish position
    $loss_finish *= $factor;
    
    ($orl,$pos)        = get_val($bufref,$pos,2);          # 12-13: optical return loss (ORL)
    $orl *= 0.001;
    
    ($orl_start,$pos)  = get_signed_val($bufref, $pos, 4); # 14-17: ORL start position
    $orl_start *= $factor;
    
    ($orl_finish,$pos) = get_val($bufref, $pos, 4);        # 18-21: ORL finish position
    $orl_finish *= $factor;
    
    print $otdr::LOG $subpre,"Summary:\n";
    print $otdr::LOG $subpre,$subpre," total loss: $total_loss dB\n";
    print $otdr::LOG $subpre,$subpre," ORL: $orl dB\n";
    print $otdr::LOG $subpre,$subpre," loss start: $loss_start km\n";
    print $otdr::LOG $subpre,$subpre," loss end: $loss_finish km\n";
    print $otdr::LOG $subpre,$subpre," ORL start: $orl_start km\n";
    print $otdr::LOG $subpre,$subpre," ORL finish: $orl_finish km\n";
    
    return;
}

1;
