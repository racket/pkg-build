# pkg-build example

This example demonstrates how one might use VirtualBox and Vagrant to
run a local package build.

## Prerequisites

1. About 10GB of free disk space.
1. [VirtualBox] and [Vagrant].
1. An SSH public key at `~/.ssh/id_rsa.pub`.  This key will be copied
   into each of the virtual machines so that the build script can SSH
   into them.

## First-time Setup

1. From the root of this repository, run `raco pkg install --name
   pkg-build` to install (and link) the `pkg-build` package globally.
1. From the `example` directory, run `provision.sh` to create the VMs.

Two Virtual Machines will be created by the `provision.sh` script.
You can control the number of VMs that you want to use by editing the
`Vagrantfile`.  If you do change the number of VMs, then you'll also
have to update `provision.sh` and `build.rkt` accordingly.

## Building

Run `racket build.rkt` to start a build.


[VirtualBox]: https://www.virtualbox.org/
[Vagrant]: https://www.vagrantup.com/
