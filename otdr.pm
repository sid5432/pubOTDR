#!/usr/bin/perl -w
use strict;

package otdr;

# use otdr::utils qw(get_val get_string get_hexstring);
use otdr::cksum qw(process_cksum);
use otdr::genparams qw(process_genparams);
use otdr::supparams qw(process_supparams);
use otdr::fxdparams qw(process_fxdparams);
use otdr::datapts qw(process_datapts);
use otdr::keyevents qw(process_keyevents);

my $pre    = "MAIN: ";
my $subpre = "    : ";
my $div    = ("-"x80)."\n";

# redefine
$otdr::utils::pre = $pre;
$otdr::utils::subpre = $subpre;

# -----------------------------------------------
sub parse
{
    my $filename = shift;
    my $output = shift || $filename;
    my $var = shift; # stash to save everything
    my $dump = shift || "no";
    
    my @arr = split /\//, $output;
    my $logfile;
    
    if ( $output eq $filename or $output eq "" ) {
	$output = $logfile = $arr[$#arr];
	$output =~ s/\.sor$/\-trace\.dat/oi;
	$logfile =~ s/\.sor$/\-log\.dat/oi;
    }
    
    # get data
    my $buffer;
    {
	local $/;
	
	open(DATA, $filename) or die("Cannot read $filename\n");
	binmode DATA, ":raw";
	
	$buffer = <DATA>;
	close DATA;
    }

    my @buffer = split //, $buffer;
    
    # extra scaling factor of distance (for old AFL data)
    $var->{xscaling} = 1.0;
    
    # get header
    my ($str,$hex,$count,$pos);
    $pos = 0; # index/position in the buffer
    
    ($str,$hex,$count,$pos)= get_string( \@buffer, $pos );
    
    my $disp = sprintf "0x%X", $pos;
    
    if( $str eq 'Map' ) {
	print $otdr::LOG $pre,"bellcore 2.x version; continue\n";
	# print LOG "bellcore 2.x version; continue\n";
	$var->{flavor} = 2;
    }else{ # assume it is Bellcore 1.x
	print $otdr::LOG $pre,"bellcore 1.x version\n";
	$var->{flavor} = 1;
	# reset to position 0
	$pos = 0;
    }
    
    # -------------------------------------------------------
    my ($version, $bsize);
    ($version, $bsize, $pos) = process_block_header(\@buffer, $pos, $var);
    
    $disp = sprintf "0x%X", $pos;
    print $otdr::LOG $pre,"Version $version, block size $bsize bytes; next position $disp\n";
    
    # get number of blocks to follow
    my $bnum;
    ($bnum,$pos) = get_val(\@buffer, $pos, 2);
    $bnum--;
    
    $disp = sprintf "0x%X", $pos;
    print $otdr::LOG $pre,"$bnum blocks to follow; next position $disp\n";
    
    print $otdr::LOG $div;
    print $otdr::LOG $pre,"BLOCKS:\n";
    
    # -------------------------------------------------------
    # part 1: get block locations
    my @blocklist = ();
    
    my ($tmp,$tmpstr);
    my $prev = $bsize;
    
    for(my $i=0; $i<$bnum; $i++) {
	($str,$hex,$count,$pos)= get_string( \@buffer, $pos );
	# ($hex,$tmp)= get_hexstring( \@buffer, $pos, 6 );
	
	($version, $bsize, $pos) = process_block_header(\@buffer, $pos, $var);
	# print $pre,"$str block: version $version, block size $bsize bytes (from $hex)\n";
	my $spos = sprintf "0x%02X", $prev;
	print $otdr::LOG $pre,"$str block: version $version, block size $bsize bytes, start at pos $spos\n";
	
	my $ref = {};
	$ref->{name} = $str;
	$ref->{bsize} = $bsize;
	$ref->{start} = $prev;
	
	push @blocklist, $ref;
	$prev += $bsize;
    }
    
    $disp = sprintf "0x%X", $pos;
    print $otdr::LOG $div,"\n",$pre,"next position $disp\n",$div,"\n";
    
    # ---------------------------------------------------------------------
    # part 2: process contents of selected blocks
    foreach my $block ( @blocklist ) {
	my $name = $block->{name};
	my $bsize = $block->{bsize};
	$pos = $block->{start};
	my $disp = sprintf "0x%02X", $pos;
	print $otdr::LOG "\n$pre $name block: $bsize bytes, start pos $disp ($pos)\n";
	
	if ( $name eq 'GenParams' ) {
	    process_genparams(\@buffer, $pos, $var);
	}elsif( $name eq 'SupParams' ) {
	    process_supparams(\@buffer, $pos, $var);
	}elsif( $name eq 'FxdParams' ) {
	    process_fxdparams(\@buffer, $pos, $var);
	}elsif( $name eq 'DataPts' ) {
	    process_datapts(\@buffer, $pos, $var, $output);
	}elsif( $name eq 'KeyEvents' ) {
	    process_keyevents(\@buffer, $pos, $var);
	}elsif( $name eq 'Cksum' ) {
	    process_cksum(\@buffer, $pos, $var);
	    if ( $var->{calc_checksum} ) {
		calc_cksum(\@buffer, $var);
	    }
	}
    }
    
    # ..............................
    # grand summary
    if ( $dump =~ m/^yes/oi ) {
	print $otdr::LOG "\n",$div;
	print $otdr::LOG $pre,"SUMMARY:\n";
	
	foreach my $item (sort keys %{$var}) {
	    print $otdr::LOG $pre,"$item: $var->{$item}\n";
	}
    }
    
    return;
}

# ==============================================================
sub process_block_header
{
    # process block header; return:
    #  - version number
    #  - size of block (number of bytes)
    #  - next position
    my $bufref = shift;
    my $start = shift;
    my $var = shift;
    
    my ($version,$bsize);
    my $pos = $start;
    ($version,$pos) = get_val($bufref, $start, 2);
    
    $version *= 0.01;
    
    ($bsize,$pos)   = get_val($bufref, $pos, 4);
    $version = sprintf "%0.2f", $version;
    
    return ($version, $bsize, $pos);
}

1;
