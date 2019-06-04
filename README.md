# Flatten

[![Build Status](https://travis-ci.org/rafaqz/Flatten.jl.svg?branch=master)](https://travis-ci.org/rafaqz/Flatten.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/dpf055yo50y21g1v?svg=true)](https://ci.appveyor.com/project/rafaqz/flatten-jl)
[![codecov.io](http://codecov.io/github/rafaqz/Flatten.jl/coverage.svg?branch=master)](http://codecov.io/github/rafaqz/Flatten.jl?branch=master)
[![Coverage Status](https://coveralls.io/repos/rafaqz/Flatten.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/rafaqz/Flatten.jl?branch=master)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/Flatten.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://rafaqz.github.io/Flatten.jl/latest)

Flatten.jl converts data between nested and flat structures, using `flatten()`,
`reconstruct()` and `update!()` functions. This facilitates building modular,
compostable code while still providing access to differentiation, solvers and
optimisers that require flat vectors of parameters. Importantly it's also type-stable 
and _very_ fast.

See [the documentation](https://rafaqz.github.io/Flatten.jl/stable) for details.
