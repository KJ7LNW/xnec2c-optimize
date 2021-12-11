# xnec2c-optimize

xnec2c-optimize is an optimization framework to tune antenna geometries.  It requires
[xnec2c](https://www.xnec2c.org) v4.3 or later to work with external optimization.

## Getting Started

1. Install the latest version of xnec2c from here: https://www.xnec2c.org/

2. Install the following perl modules with something like `cpanm PDL`:

   - PDL
   - PDL::IO::CSV
   - Linux::Inotify2
   - Math::Round
   - Time::HiRes


3. See `yagi.conf` for an example to get started.   Just run this:

```sh
./xnec2c-simplex.pl yagi.conf 
```

and then open `xnec2c -j NN yagi.nec` where `NN` is the number of CPUs you
have available on your system. Select File->Optimizer Output. Optimization will then begin.

-Eric, KJ7LNW
