# pgagroal

`pgagroal` is a high-performance protocol-native connection pool for [PostgreSQL](https://www.postgresql.org).

## Overview

`pgagroal` makes use of

* Process model
* Shared memory model across processes
* [libev](http://software.schmorp.de/pkg/libev.html) for fast network interactions
* [Atomic operations](https://en.cppreference.com/w/c/atomic) is used to keep track of state
* The [PostgreSQL](https://www.postgresql.org) native protocol
  [v3](https://www.postgresql.org/docs/11/protocol-message-formats.html) for its communication

See [Configuration](./doc/CONFIGURATION.md) on how to configure `pgagroal`.

See [Performance](./doc/PERFORMANCE.md) for a performance run.

See [Architecture](./doc/ARCHITECTURE.md) for the architecture of `pgagroal`.

## Tested platforms

* [Fedora](https://getfedora.org/) 28+
* [RHEL](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux) 7.x/8.x with
  [EPEL](https://access.redhat.com/solutions/3358) and
  [DevTools](https://developers.redhat.com/products/developertoolset/overview) 8+

## Compiling the source

`pgagroal` requires

* [gcc 8+](https://gcc.gnu.org) (C17)
* [cmake](https://cmake.org)
* [libev](http://software.schmorp.de/pkg/libev.html)

### Release build

```
git clone https://github.com/agroal/pgagroal.git
cd pgagroal
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
cd src
cp ../../doc/etc/*.conf .
./pgagroal
```

### Debug build

```
git clone https://github.com/agroal/pgagroal.git
cd pgagroal
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Debug ..
make
cd src
cp ../../doc/etc/*.conf .
./pgagroal
```

## Contributing

Contributions to `pgagroal` are managed on [GitHub.com](https://github.com/agroal/pgagroal/)

* [Issue](https://github.com/agroal/pgagroal/issues)
* [Feature request](https://github.com/agroal/pgagroal/issues)
* [Code submission](https://github.com/agroal/pgagroal/pulls)

Contributions are most welcome !

## License

[BSD-3-Clause](https://opensource.org/licenses/BSD-3-Clause)