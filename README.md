# pkg-build

This the source for the Racket package: "pkg-build".

This package builds all of the packages in a catalog using one or more
virtual machines.  It is used by pkg-build.racket-lang.org to build
the main package catalog.

## Local builds

### Prerequisites

* Install [VirtualBox] and ensure its `VboxManage` executable can be
  found on your `$PATH`.

* Create a VirtualBox VM, install a Linux distribution (we
  recommend Ubuntu 18.04) in it and:

  1. create a user named `racket`,
  1. ensure that the `racket` user can run `sudo` without a password,
  1. install the OpenSSH server, and add your public key to the
     `racket` user's list of authorized keys,
  1. switch the VM to host-only networking and take note of its IP
     address,
  1. take a snapshot of the VM called `init`,
  1. finally, shut down the VM.

* Install the `pkg-build` package from the root of this repository:

        $ raco pkg install --name pkg-build

### Running a build

Once you've completed all the prerequisites, you can create a local
directory -- preferably somewhere outside of the repository root -- to
hold the state of the build.  In that directory, create a file called
`run.rkt` with the following contents:

```racket
#lang racket/base

(require pkg-build)

(build-pkgs
 #:vms (list (vbox-vm #:name "pkg-build" #:host "192.168.99.100"))
 #:snapshot-url "https://mirror.racket-lang.org/releases/7.4/"
 #:installer-platform-name "{1} Racket | {3} Linux | {3} x64_64 (64-bit), natipkg; built on Debian 7 (Wheezy)")
```
1. Replace "pkg-build" with the name of your VM.
2. Replace "192.168.99.100" with the IP address of your VM.


Run `racket run.rkt` to start a local build of the package catalog at
https://pkgs.racket-lang.org/.


[VirtualBox]: https://www.virtualbox.org/

## Contributing

Contribute to Racket by submitting a [pull request], reporting an
[issue], joining the [development mailing list], or visiting the
IRC or Slack channels.

## License

Racket, including these packages, is free software, see [LICENSE]
for more details.

By making a contribution, you are agreeing that your contribution
is licensed under the [Apache 2.0] license and the [MIT] license.

[MIT]: https://github.com/racket/racket/blob/master/racket/src/LICENSE-MIT.txt
[Apache 2.0]: https://www.apache.org/licenses/LICENSE-2.0.txt
[pull request]: https://github.com/racket/pkg-build/pulls
[issue]: https://github.com/racket/pkg-build/issues
[development mailing list]: https://lists.racket-lang.org
[LICENSE]: LICENSE
