#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use NEC2;
use NEC2::xnec2c::optimize;
use NEC2::Antenna::Yagi;


use Data::Dumper;

if (!@ARGV)
{
	print "usage: $0 config-file.conf\n";
	exit 1;
}

my $filename_config = $ARGV[0];
my $filename_nec = $ARGV[0];
my $filename_nec_csv = $ARGV[0];

$filename_nec =~ s/\.conf$//;
$filename_nec .= ".nec";

my $config = do($filename_config);
die $@ if $@;

my $xnec2c = NEC2::xnec2c::optimize->new(
	filename_nec => $filename_nec, 
	%$config);

$xnec2c->print_vars_initial();



print "===== Writing NEC2 output to $filename_nec =====\n\n";

my $ncpus = `grep -c processor /proc/cpuinfo`; chomp $ncpus;
print "Open \`xnec2c -j $ncpus $filename_nec\` and select File->Optimizer Output. Optimization will then begin.\n";

$xnec2c->save_nec_initial();

print $xnec2c->print_nec2_initial();


print "\n===== Starting Optimization ==== \n";


$xnec2c->optimize();

print "\n===== Done! ==== \n";

$xnec2c->print_vars_result();

print "\n===== $filename_nec ==== \n";
print $xnec2c->print_nec2_final();

exit 0;

#####################################################################
#                                                           Functions

# Globals for the functions:
my $log_count = 0;





