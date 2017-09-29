fixed: a library for fixed-point arithmetic
===========================================

This is a fork of Go's [fixed point library][gofixed], optimized for FPGAs running on the Reconfigure.io platform.

It currently provides only Q26:6 and Q52:12 precision¹ types. If you need other precisions, open an issue or a pull request.

¹ See the Wikipedia page on the [Q number format][q] for information on this notation.

[q]: https://en.wikipedia.org/wiki/Q_(number_format)
[gofixed]: https://godoc.org/golang.org/x/image/math/fixed
