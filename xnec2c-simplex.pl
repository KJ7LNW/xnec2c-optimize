#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use NEC2;
use NEC2::xnec2c::optimize;
use NEC2::Antenna::Yagi;

use Data::Dumper;

$SIG{__WARN__} = sub { print "\nWarning: $_[0]" . Dumper _build_stack() ; };
$SIG{__DIE__} = sub { print "\nDie: $_[0]" . Dumper _build_stack() ; };

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

die "file not found: $filename_config" if (! -e $filename_config);

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

print "\nPress enter to start\n";
<STDIN>;

print "\n===== Starting Optimization ==== \n";


$xnec2c->optimize();

print "\n===== Done! ==== \n";

$xnec2c->print_vars_result();

print "\n===== $filename_nec ==== \n";
print $xnec2c->print_nec2_final();

exit 0;

## functions

sub _build_stack
{
	my $i = 0;
	my @msg;
	while (my @c = caller($i++)) {
		my @c0 = caller($i);
		my $caller = '';
		$caller = " ($c0[3])" if (@c0);
		push @msg, "  $i. $c[1]:$c[2]:$caller while calling $c[3]";
	}

	return \@msg;
}
