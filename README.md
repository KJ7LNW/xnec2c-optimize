# xnec2c-optimize

xnec2c-optimize is an optimization framework to tune antenna geometries.  It requires
xnec2c v4.3 or later to work with external optimization.

## Getting Started

See `yagi.conf` for an example.   Just run this:

```sh
./xnec2c-simplex.pl yagi.conf 
```

and then open `xnec2c -j NN yagi.nec` where NN is the number of CPUs you
are using. Select File->Optimizer Output. Optimization will then begin.


-Eric, KJ7LNW
