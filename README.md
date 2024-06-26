# xnec2c-optimize

xnec2c-optimize is an optimization framework to tune antenna geometries with 
[xnec2c](https://www.xnec2c.org).

**Why tune our antenna?  High gain and low VSWR, of course!**   

1. [Before and after graphs](#examples)
2. [Getting Started](#getting-started)
3. [Writing NEC2 files with Perl](#writing-nec2-files-with-perl)

# Examples

## Optimization

### Before:
  - 9.3 - 10.9 dB gain.
  - Huge 23.31 VSWR at 148 MHz, lets fix that.
![before xnec2c-optimize](https://github.com/KJ7LNW/xnec2c-optimize/blob/master/examples/yagi-before-xnec2c-optimize.png?raw=true)

### After: 
  - **10.81 - 11.3 dB gain!**
  - **1.25 VSWR, hurray!**  (Note that the graph scale changed)
![after xnec2c-optimize](https://github.com/KJ7LNW/xnec2c-optimize/blob/master/examples/yagi-after-xnec2c-optimize.png?raw=true)

## Writing NEC2 files with Perl

From the [2m dipole example](https://github.com/KJ7LNW/xnec2c-optimize/blob/master/examples/dipole-2m.pl):

```perl
use lib 'lib';

use NEC2;

my $nec = NEC2->new(comment => "half-wave 2-meter dipole");

my $ns = 21; # number of segments

$nec->add(
        GW( tag => 1, ns => $ns, z2 => 1),
        EX( ex_tag => 1, ex_seg => int($ns/2) ),
        RP,
        NH,
        NE,
        FR(mhz_min => 140, mhz_max => 148, n_freq => 10),
        );

$nec->save('dipole-2m.nec');

print $nec;
```

# Getting Started

1. Install the latest version of xnec2c from here: https://www.xnec2c.org/
   - xnec2c v4.4.12 or later is recommended.
   
2. Install the following perl modules with `cpanm` using these commands:
   - Ubuntu: `sudo apt install cpanminus build-essential`
   - CentOS: 
       ```
       yum install perl-App-cpanminus
       yum groupinstall "Development tools"
       ```

3. Install the dependencies with this command:

       cpanm PDL::Opt::Simplex::Simple PDL::IO::CSV Linux::Inotify2 Time::HiRes Math::Vector::Real Math::Matrix Math::Trig

4. See `yagi.conf` for an example to get started.   Just run this:

       ./xnec2c-simplex.pl ./examples/yagi.conf

## More detail

Now `xnec2c-simplex` does most of the work below automatically, so here is more information if you need it:


Open `xnec2c -j NN examples/yagi.nec` where `NN` is the number of CPUs you
have available on your system. 
 - From the main window: select View->Frequency Plots
   - From the Frequency Data Plots window: Enable a graph, like VSWR.  Configure whatever you would like to see during optimization.
   - Click the triangular "Play" button to run a frequency sweep. This setting must be active in order for the optimizer loop to function.
 - From the main window: 
   - Click "File->Optimization Settings->After calculation, write \<file\>.csv".
   - Click "File->Optimization Settings->Reload and write data on .NEC file
changes".
 - Optimization will then begin!

See also: https://www.xnec2c.org/#Optimization

-Eric, KJ7LNW
