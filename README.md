# xnec2c-optimize

xnec2c-optimize is an optimization framework to tune antenna geometries with 
[xnec2c](https://www.xnec2c.org).

**Why tune our antenna?  High gain and low VSWR, of course!**   

1. [Before and after graphs](#examples)
2. [Getting Started](#getting-started)

# Examples

## Before:
  - 9.3 - 10.9 dB gain.
  - Huge 23.31 VSWR at 148 MHz, lets fix that.
![before xnec2c-optimize](https://github.com/KJ7LNW/xnec2c-optimize/blob/master/examples/yagi-before-xnec2c-optimize.png?raw=true)

## After: 
  - **10.81 - 11.3 dB gain!**
  - **1.25 VSWR, hurray!**  (Note that the graph scale changed)
![after xnec2c-optimize](https://github.com/KJ7LNW/xnec2c-optimize/blob/master/examples/yagi-after-xnec2c-optimize.png?raw=true)

# Getting Started

1. Install the latest version of xnec2c from here: https://www.xnec2c.org/
   - xnec2c v4.3 or later to work with external optimization.
   
2. Install the following perl modules with `cpanm` using these commands:
   - Ubuntu: `sudo apt install cpanminus build-essential`
   - CentOS: 
       ```
       yum install perl-App-cpanminus
       yum groupinstall "Development tools"
       ```

3. Install the dependencies with this command:

       cpanm PDL::Opt::Simplex::Simple PDL::IO::CSV Linux::Inotify2 Time::HiRes


4. See `yagi.conf` for an example to get started.   Just run this:

       ./xnec2c-simplex.pl examples/yagi.conf 

and then open `xnec2c -j NN examples/yagi.nec` where `NN` is the number of CPUs you
have available on your system. 
 - From the main window: select View->Frequency Plots
   - From the Frequency Data Plots window: Enable a graph, like VSWR.  Configure whatever you would like to see during optimization.
 - From the main window: select File->Optimizer Output. 
 - Optimization will then begin!

-Eric, KJ7LNW
