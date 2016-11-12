#!/usr/bin/perl -w
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin";
use otdr;

my $version = "2016-11-06a";

# -----------------------------------------------
my $USAGE = "USAGE: $0 src_file dest_file fiberid\n";
my $srcfile = shift or die($USAGE);
my $destfile = shift or die($USAGE);
my $fiberid = shift or die($USAGE);

my $var = {};
$var->{new_fiberid} = $fiberid;

# $otdr::LOG = *STDERR;
$otdr::LOG = *STDOUT;

print $otdr::LOG "* Version $version\n\n";

# $var->{calc_checksum} = 1;
otdr::parse( $srcfile, '', $var,'no','yes');

# -----------------------------------------------
print $otdr::LOG "\n* Rewriting SOR file with new fiber ID '$fiberid' into file $destfile\n";

# replace with new fiber id;
# split the new fiber id string into characters (bytes)

my @idlist = split '', $var->{new_fiberid};
splice @{$var->{buffer}}, $var->{insertion_point}, $var->{insertion_origcount}, @idlist;

# ------ adjust block size of GenParams block -------------------------
my $add = length($var->{new_fiberid}) - $var->{insertion_origcount};

my $block = $var->{blocklist}->[0];
my $name = $block->{name};
my $bsize = $block->{bsize};

if ( $name eq 'GenParams' ) {
    my $newsize = $add + $bsize;
    # print STDERR "* Modify block size from $bsize to $newsize\n";
    # 4 bytes
    my $bint = pack("N", $newsize);
    my @arr = reverse unpack("C4", $bint);
    
    my $hpos = 2 + $block->{header_pos};
    $var->{buffer}->[$hpos]   = chr($arr[0]);
    $var->{buffer}->[$hpos+1] = chr($arr[1]);
    $var->{buffer}->[$hpos+2] = chr($arr[2]);
    $var->{buffer}->[$hpos+3] = chr($arr[3]);
}else{
    die( "!!!! Wrong block $name\n" );
}

# remove last two bytes; note that these were reversed from the original
# when we performed the checksum earlier in parse()
pop @{$var->{buffer}};
pop @{$var->{buffer}};

my $newval = otdr::calc_cksum( $var->{buffer}, $var, 'No');
my $b1 = $newval % 256; # lsb
my $b2 = int($newval / 256); # msb

# -------------- dump new file ---------------------------
open(DATA,">$destfile") or die("Cannot write to file $destfile\n");
binmode DATA, ":raw";
print DATA @{$var->{buffer}};
print DATA chr($b1),chr($b2);
close(DATA);

exit;

