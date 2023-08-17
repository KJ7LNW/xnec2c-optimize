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

use POSIX;

use NEC2;
use NEC2::xnec2c::optimize;
use NEC2::Antenna::Yagi;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

#$SIG{__WARN__} = sub { print "\nWarning: $_[0]" . Dumper _build_stack() ; };
$SIG{__DIE__} = sub { if ($^S) { die $_[0] }; print "\nDie: $_[0]" . Dumper _build_stack() ; };

if (!@ARGV)
{
	print "usage: $0 config-file.conf [saved-state-file.save]\n";
	exit 1;
}

my $filename_config = $ARGV[0];
my $filename_nec = $ARGV[0];
my $filename_nec_csv = $ARGV[0];
my $filename_save = $ARGV[0];

$filename_nec =~ s/\.conf$//;
$filename_nec .= ".nec";

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
