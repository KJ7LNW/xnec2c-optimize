#!/usr/bin/perl
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Library General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# 
#  Copyright (C) 2021- by Eric Wheeler, KJ7LNW.  All rights reserved.
#
#  The official website and doumentation for xnec2c-optimizer is available here:
#    https://www.xnec2c.org/
#

use strict;
use warnings;

use lib 'lib';

use Getopt::Long qw(:config bundling);

use POSIX;

use NEC2;
use NEC2::xnec2c::optimize;
use NEC2::Antenna::Yagi;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

my %optimizer_opts;
my %opts;
my $xnec2c_pid;

#$SIG{__WARN__} = sub { print "\nWarning: $_[0]" . Dumper _build_stack() ; };
$SIG{__DIE__} = sub { if ($^S) { die $_[0] }; print "\nDie: $_[0]" . Dumper _build_stack() ; };


GetOptions(
	# cmdline tool options
	"batch|b" => \$opts{batch},
	"no-exec|n" => \$opts{no_exec},

	# optimzer options
	"fuzz-count|z=s" => \$optimizer_opts{fuzz_count},
	"fuzz-range-pct|Z=s" => \$optimizer_opts{fuzz_range},
	"fuzz-ignore=s" => \$optimizer_opts{fuzz_ignore},
) or usage();

if (!@ARGV)
{
	usage();
}

my $filename_config = $ARGV[0];
my $filename_nec = $ARGV[0];
my $filename_save = $ARGV[0];

$filename_nec =~ s/\.conf$//;
$filename_nec .= ".nec";

my $filename_nec_csv = "$filename_nec.csv";

$filename_save =~ s/\.conf$//;
$filename_save =  $filename_save . strftime("-%F_%H-%M-%S.save", localtime);

die "file not found: $filename_config" if (! -e $filename_config);

my $config = do($filename_config);
die $@ if $@;

if ($ARGV[1])
{
	my $load = do($ARGV[1]);
	die $@ if $@;
	foreach my $var (keys(%$load))
	{
		$config->{vars}{$var}{values} = $load->{$var}->{values};
	}
}

my $xnec2c = NEC2::xnec2c::optimize->new(
	filename_nec => $filename_nec, 
	%$config,
	%optimizer_opts);

$xnec2c->print_vars_initial();

print "===== Writing NEC2 output to $filename_nec =====\n\n";

start_xnec2c();

$xnec2c->save_nec_initial();

print $xnec2c->print_nec2_initial();

if (!$opts{batch})
{
	print "\nPress enter to start\n";
	<STDIN>;
}

print "\n===== Starting Optimization ==== \n";

my $result = $xnec2c->optimize();

if (open(my $save, ">", $filename_save))
{
	print $save Dumper($result);
	close($save);
	print "Saved state to $filename_save\n";
}
else
{
	warn "$filename_save: $!";
}

print "\n===== Done! ==== \n";


$xnec2c->print_goal_status;
$xnec2c->print_vars_result();

print "\n===== $filename_nec ==== \n";
$xnec2c->save_nec_result();
print $xnec2c->print_nec2_result();

if ($opts{batch} && !$opts{no_exec})
{
	kill(15, $xnec2c_pid);
}

exit 0;

## functions

sub usage
{
	print "usage: $0 [options] config-file.conf [saved-state-file.save]\n"
		. "\n"
		. "  --no-exec|-n          Do not auto-start/stop xnec2c\n"
		. "\n"
		. "Fuzzing options are useful for optimizing an antenna that is less sensitive to\n"
		. "error.  It randomly changes optimization variables by a percentage and returns\n"
		. "the worst value as a result.  The optimizer will then work to find the place\n"
		. "where dimensional error affects the design the least:\n"
		. "\n"
		. "  --fuzz-count|-z       N           Try N random values\n"
		. "  --fuzz-range-pct|-Z   percent     Randomize +/-% of the specified value\n"
		. "  --fuzz-ignore         var1,...    Do not randomize the specified variables\n"
		. "                                    example: wire_rad,wire_segments\n"
		. "\n"
		;
	exit 1;
}

sub start_xnec2c
{
	my $ncpus = `grep -c processor /proc/cpuinfo`; chomp $ncpus;
	my @xnec2c = (qw/xnec2c -j /, $ncpus, qw/--optimize --write-csv/, $filename_nec_csv, $filename_nec);
	print "Opening xnec2c: " . join(" ", @xnec2c) . "\n";

	if ($opts{no_exec})
	{
		print "Auto-starting xnec2c is disabled with \`-n\`.  Run the command above if necessary.\n";
		return;
	}

	$xnec2c_pid = fork();

	$SIG{CHLD} = sub {
		my $kid;
		do {
			    $kid = waitpid(-1, WNOHANG);
			    my $rc = $? >> 8;
			    my $sig = ($? & 0xff);

			    if ($kid == $xnec2c_pid)
			    {
				    if (($rc != 0 && $rc != 2) || $sig)
				    {
					    warn "\n\n==== xnec2c exited (rc=$rc sig=$sig)?  Restarting...";
					    sleep 1;
					    start_xnec2c();
				    }
				    else
				    {
					    warn "\n\n==== xnec2c closed gracefully (ie, you closed it), aborting optimization.";
					    exit 0;
				    }
			    }
		} while $kid > 0;
	};

	if (!$xnec2c_pid)
	{
		exec(@xnec2c) or die "Unable to start xnec2c: $!";
		exit(1);
	}

	sleep 1;
	if (!kill(0, $xnec2c_pid))
	{
		die "xnec2c does not appear to have loaded.";
	}
}

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
