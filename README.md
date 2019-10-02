# pkg-build

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

Replace "192.168.99.100" with the IP address of your VM.

Run `racket run.rkt` to start a local build of the package catalog at
https://pkgs.racket-lang.org/.

## Known Issues

* The `download-installer` procedure does not follow redirects.  This
  means you can't use `download.racket-lang.org` as the snapshot URL,
  instead `mirror.racket-lang.org` must be used.


[VirtualBox]: https://www.virtualbox.org/
