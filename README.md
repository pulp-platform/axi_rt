# A real-time extension for AMBA AXI4 protocol
[![CI status](https://github.com/pulp-platform/axi_rt/actions/workflows/gitlab-ci.yml/badge.svg?branch=master)](https://github.com/pulp-platform/axi_rt/actions/workflows/gitlab-ci.yml?query=branch%3Amaster)
[![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/pulp-platform/axi_rt?color=blue&label=current&sort=semver)](CHANGELOG.md)
[![SHL-0.51 license](https://img.shields.io/badge/license-SHL--0.51-green)](LICENSE)

This repository provides a modular real-time extension for AXI4-based memory systems. AXI-RT is part
of the [PULP (Parallel Ultra-Low-Power) platform](https://pulp-platform.org/). It is independent of
the specific AXI4 implementation used. However, it is primarily intended to be used with our
[AXI4+ATOP implementation](https://github.com/pulp-platform/axi).

## License
iDMA is released under Solderpad v0.51 (SHL-0.51) see [`LICENSE`](LICENSE):

## Contributing
We are happy to accept pull requests and issues from any contributors. See [`CONTRIBUTING.md`](CONTRIBUTING.md)
for additional information.

## Getting Started

The IP can be reconfigured using the `axirt.mk` make fragment. The provided makefile gives
a reference on how to invoke the fragment.

``` bash
make axirt_regs

```
