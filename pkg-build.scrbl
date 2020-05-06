#lang scribble/manual
@(require (for-label racket/base
                     pkg-build))

@title{Pkg-Build: Building and Testing All Racket Packages}

The @racketmodname[pkg-build] library supports building all packages
from a given catalog and using a given snapshot (i.e., installer plus
snapshot's packages). The build of each package is isolated through a
virtual machine, using either Docker or VirtualBox, and the result is
a set of built packages, a set of documentation, and package test
results. For example, @racketmodname[pkg-build] is used to drive
@url{https://pkg-build.racket-lang.org/} and generate the content of
@url{https://docs.racket-lang.org/}.

To successfully build, a package must
@;
@itemlist[

  @item{install without error;}

  @item{correctly declare its dependencies (but incorrect declaration
        may work, anyway, if the build order happens to accommodate);}
    
  @item{depend on packages that build successfully on their own;}

  @item{refer only to other packages in the snapshot and catalog
       (and, in particular, must not use PLaneT packages);}

  @item{build without special system libraries.}

]
@;
A successful build does not require that its declared dependencies are
complete if the needed packages end up installed, anyway, but the
declared dependencies are checked. Even when a build is unsuccessful,
any documentation that is built along the way is extracted, if
possible.

@section{Building Packages with Docker}

First, install @hyperlink["https://www.docker.com/"]{Docker}. As long
as @exec{docker} is in your path, that may be all you need, because
suitable starting images @tt{mflatt/pkg-build-deps} and/or
@tt{mflatt/pkg-build-deps:min} can be downloaded automatically by
Docker. See @secref["starting-image"] for more information about the
content of a suitable starting image.

In the @filepath{pkg-build} package sources, see the
@filepath{examples/docker} directory for an example use of
@racket[build-pkgs] with Docker.

@section{Building Packages with VirtualBox}

First, install @hyperlink["https://www.virtualbox.org/"]{VirtualBox}
and ensure that @exec{VBoxManage} is in your path.

You will need to create a suitable VirtualBox virtual machine
containing a Linux distribution (we recommend any recent version of
Ubuntu). See @secref["starting-image"] for more information about the
content of a suitable starting image. With those dependencies in
place, you will need to configure the virtual machine:
@;
@itemlist[

 @item{Create a @tt{racket} user.}

 @item{Ensure that the @tt{racket} user can run @tt{sudo} without a password.}

 @item{Install the OpenSSH server, and add your public key from
       @filepath{~/.ssh/id_rsa.pub} on your host to the @tt{racket}
       user's list of authorized keys in
       @filepath{~/.ssh/authorized_keys} on the virtual machine.}

 @item{Switch the virtual machine to host-only networking and take
       note of its IP address.}

 @item{Take a snapshot of the virtual machine called @tt{init}.}

 @item{Shut down the virtual machine.}

]

In the @filepath{pkg-build} package sources, see the
@filepath{examples/vbox} directory for an example use of
@racket[build-pkgs] with VirtualBox.

@section[#:tag "starting-image"]{Starting Image Requirements}

The @racket[build-pkgs] function expects a Docker image or VirtualBox
machine with just Linux installed. The installation can be minimal,
but CA certificates and timezone information are recommended. (Even
though network access in the virtual machine should be disabled, basic
configuration is helpful to some libraries.)

Some Racket packages may try to use a C compiler or run tests that
need an GUI context (i.e., an X11 server). To support those packages,
consider including @tt{gcc} and having an X11 server set up. If you
are interested in distinguishing packages that have minimal system
dependencies from those that require more, @racket[build-pkgs] allows
you to specify ``full'' and ``minimal'' starting variants.

See the @filepath{examples/docker/pkg-build-deps} and
@filepath{examples/docker/pkg-build-deps-min} directories of the
@filepath{pkg-build} package source for @filepath{Dockerfile}s that
create suitable starting images.


@section[#:tag "work-dir"]{Work Directory Content}

The @racket[build-pkgs] function needs a work directory where it will
assemble packages and results. The generated content of the work
directory can be used as a catalog of built packages plus web-friendly
files that report build and test results.

If the work directory content persists across calls to
@racket[build-pkgs], then @racket[build-pkgs] will incrementally
rebuild changed packages and other packages that depends on them.
However, a work directory must be reused only when the configuration
supplied to @racket[build-pkgs] does not change.

The work directory will include the following files and directories,
most of which are output, some of which record state for the purpose
of incremental builds, and very few of which are treated as extra
inputs:

@itemlist[

 @item{@filepath{installer/} --- Holds an installer downloaded
       from a snapshot site.}

 @item{@filepath{install-uuids.rktd} --- Holds a mapping of @tech{VM}
        names to IDs for prepared Docker containers or VirtualBox
        snapshots.}

 @item{@filepath{install-list.rktd} --- A list of packages found in
       the installation.}

 @item{@filepath{install-adds.rkt} --- A table of documentation,
       libraries, etc. in the installation, which is used to detect
       conflicts.}

 @item{@filepath{install-doc.tgz} --- A copy of installation's
       documentation.}

 @item{@filepath{server/archive} --- Archived packages from the
       snapshot site plus additional specified catalogs.}

 @item{@filepath{state.sqlite} --- Records the state of
       @filepath{server/archive} for incremental updates.}

 @item{@filepath{all-pkgs.rktd} --- A list of available package at
       most recent build, which is used to avoid re-building packages
       that will fail again due to missing dependencies.}

 @item{@filepath{force-pkgs.rktd} --- A list of packages to force a
       rebuild; this file is an input, and it is deleted after it is
       used.}

 @item{@filepath{server/built} --- Built packages. For each package
       @italic{P}, this directory contains one of the following:

       @itemlist[

           @item{@filepath{pkgs/@italic{P}.orig-CHECKSUM} (same as the
                 checksum in the archived catalog),
                 @filepath{pkgs/@italic{P}.zip} (built package), and
                 @filepath{pkgs/@italic{P}.zip.CHECKSUM} (built
                 package's checksum) --- An up-to-date package that
                 successfully built.

                 Additional files:

                 @itemlist[

                   @item{@filepath{docs/@italic{P}-adds.rktd} --- a
                   listing of documentation, executables, etc.}

                   @item{@filepath{success/@italic{P}.txt} --- records success}

                   @item{@filepath{install/@italic{P}.txt} --- records installation}

                   @item{@filepath{install/@italic{P}.txt} --- records dependency-checking failure}

                   @item{@filepath{test-success/@italic{P}.txt}
                         or @filepath{test-fail/@italic{P}.txt} --- records @exec{raco test} result}

                   @item{possibly @filepath{min-fail/@italic{P}.txt} --- records failure on minimal-host attempt}

                 ]}

           @item{@filepath{pkgs/@italic{P}.orig-CHECKSUM} (same as the
                 checksum in the archived catalog) and
                 @filepath{fail/@italic{P}.txt} --- An up-to-date
                 package that failed to build.
                 An @filepath{install/@italic{P}.txt} file may
                 nevertheless report installation success in the sense that
                 @exec{raco pkg install} failed only in its @exec{raco setup} step.}

           @item{@filepath{archive-fail/@italic{P}.orig-CHECKSUM} --- Archiving failure.}

         ]}

   @item{@filepath{dumpster/} --- Saved builds of failed packages if
         the package at least installs (and failure was in the
         @exec{raco setup} step), because maybe the attempt built some
         documentation.}

   @item{@filepath{doc/} --- Unpacked documentation with non-conflicting
         packages installed.}

   @item{@filepath{all-doc.tgz} --- The same content as
         @filepath{doc/}, but still packed.}

   @item{@filepath{summary.rktd} ---A summary of build results as a
         hash table mapping each package name to another hash table
         with the following keys:

         @itemlist[
           @item{@racket['success-log] --- @racket[#f] or relative path}
           @item{@racket['failure-log] --- @racket[#f] or relative path}
           @item{@racket['dep-failure-log] --- @racket[#f] or relative path}
           @item{@racket['test-success-log] --- @racket[#f] or relative path}
           @item{@racket['test-failure-log] --- @racket[#f] or relative path}
           @item{@racket['min-failure-log] --- @racket[#f] or relative path}
           @item{@racket['docs] --- a list of elements, each one of
                 @itemlist[
                   @item{@racket[(list 'docs/none _name)]}
                   @item{@racket[(list 'docs/main _name _path)]}
                 ]}
           @item{@racket['conflict-log] --- @racket[#f], a relative path, or
                 @racket[(list 'conflicts/indirect _path)]}
           ]}

   @item{@filepath{index.html} (and @filepath{robots.txt}, etc.) --- A summary of results in
         web-page form.}

   @item{@filepath{site.tgz} or @filepath{site.tar} --- All files meant to populate a
         web site, including a @filepath{doc/} directory of documentation and a
         @filepath{server/built/catalog/} catalog of built packages that are in
         @filepath{server/built/pkgs/}. The packed form @filepath{site.tgz} is
         created unless @racket[#:compress-site?] is provided as @racket[#f].}

]

Using this information, the @racket[build-pkgs] rebuilds a package is
if its checksum changes or if one of its declared dependencies
changes.

@section{Package-Building API}

@defmodule[pkg-build]

The @racket[build-pkgs] function drive a package build, but it relies
on a set of @deftech{VMs} that are created by @racket[docker-vm] or
@racket[vbox-vm].

@defproc[(build-pkgs
          [#:work-dir work-dir path-string? (current-directory)]
          [#:snapshot-url snapshot-url string?]
          [#:installer-platform-name installer-platform-name string?]
          [#:vms vms (listof vm?)]
          [#:pkg-catalogs pkg-catalogs (listof string?) (list "https://pkgs.racket-lang.org/")]

          [#:pkgs-for-version pkgs-for-version string? (version)]
          [#:extra-packages extra-packages (listof string?) null]

          [#:only-packages only-packages (or/c #f (listof string?)) #f]
          [#:only-sys+subpath only-sys+subpath (or/c #f (cons string? string?)) null]

          [#:steps steps (listof symbol?) (steps-in 'download 'summary)]

          [#:timeout timeout real? 600]

          [#:on-empty-pkg-updates on-empty-pkg-updates (-> any) void]
         
          [#:install-doc-list-file install-doc-list-file (or/c #f path-string?) #f]

          [#:run-tests? run-tests? any/c t]

          [#:built-at-site? built-at-site? any/c #f]

          [#:site-url site-url (or/c #f string?) #f]
          [#:site-starting-point site-starting-point (or/c #f string?) #f]
          [#:compress-site? compress-site? any/c #t]

          [#:summary-omit-pkgs summary-omit-pkgs (listof string?) null]

          [#:max-build-together max-build-together exact-positive-integer? 1]

          [#:server-port server-port (or/c #f (integer-in 1 65535)) 18333])
         void?]{

Builds packages by
@;
@itemlist[

 @item{using @racket[work-dir] as the @seclink["work-dir"]{work directory};}

 @item{downloading initial packages from @racket[snapshot-url],
       which can be something like @racket["https://mirror.racket-lang.org/releases/7.6/"];}

 @item{using @racket[installer-platform-name] to locate an installer at @racket[snapshot-url],
       where the name is something like
       @racket["{1} Racket | {3} Linux | {3} x64_64 (64-bit), natipkg; built on Debian 8 (Jessie)"];
       this name should be one of the entries in @filepath{installers/table.rktd} relative
       to @racket[snapshot-url], and it should be a @tt{natipkg} option consistent with
       the @tech{VMs} specified by @racket[vms];
       if a minimal installer is used and package tests will be run, include
       @racket["compiler-lib"] in @racket[extra-packages];}

 @item{running the @tech{VMs} machines specified by @racket[vms], which is
       a list of results from @racket[docker-vm] and/or
       @racket[vbox-vm];}

 @item{installing additional packages from @racket[pkg-catalogs]
       individually in @tech{VMs}.}

]

Additional configuration options:

@itemlist[

 @item{@racket[pkgs-for-version] --- The Racket version to use in
        queries to archived catalogs. This version should be
        consistent with @racket[snapshot-url].}

 @item{@racket[extra-packages] --- Extra packages to install within an
       installation so that they're treated like packages that are included in
       the installer. These should be built packages (normally from
       the snapshot site), or else the generated built packages will
       not work right (especially when using multiple @tech{VMs}).}

 @item{@racket[only-packages] --- When not @racket[#f], specifies a
       subset of packages available from @racket[pkg-catalogs] to be
       built and recorded in a catalog. Any dependencies of a
       specified package are also included.}

 @item{@racket[only-sys+subpath] --- When not @racket[#f] and when
       @racket[only-packages] is not @racket[#f], considers only
       dependencies for the indicated specific platform. The platform is described
       by @racket[cons]ing a symbol matching the result of
       @racket[(system-type)] to a string matching the result of
       @racket[(system-library-subpath #f)].}

 @item{@racket[steps] --- Steps to perform the package-build process.
       The possible steps, in order, are

       @itemlist[

        @item{@racket['download]: download installer from snapshot
              site.}

        @item{@racket['archive]: archive catalogs byt downloading
              all packages to the work directory.}

        @item{@racket['install]: run the installer to set up each @tech{VM}.}

        @item{@racket['build]: build packages that have changed.}

        @item{@racket['docs]: extract and assemble documentation.}

        @item{@racket['summary]: summarize the results as a web page.}

        @item{@racket['site]: assemble web-friendly pieces to an archive.}

       ]

       You can skip steps at the beginning if you know that they're already
       done, and you can skip tests at the end if you don't want them,
       but any included steps must be contiguous and in order.}

   @item{@racket[timeout] --- Timeout in seconds for any one package
         or step.}

   @item{@racket[on-empty-pkg-updates] --- A thunk that is called in the
         case that no packages need to be rebuilt.}

   @item{@racket[install-doc-list-file] --- If not @racket[#f], save a
         list of files in the original installation's @filepath{doc}
         directory to the specified file as part of the
         @racket['install] step.}

   @item{@racket[run-tests?] --- Determines whether each package's
         tests are run after building the package.}

   @item{@racket[built-at-site?] --- Determines whether to include a
         catalog of built packages in an assembled site.}

   @item{@racket[site-url] --- The URL where the assemble site will be
         made available (for, e.g., showing help about the catalog).}

   @item{@racket[site-starting-point] --- Text for help to describes
         the starting point, where @racket[#f] means ``the current
         release.''}

   @item{@racket[compress-site?] --- Selects whether the
         @racket['site] step produces @filepath{site.tgz} (if true) or
         @filepath{site.tar} (otherwise).}

  @item{@racket[summary-omit-pkgs] --- A list of packages to omit from
        the build summary.}

   @item{@racket[max-build-together] --- Number of packages to build
         at once in a single @tech{VM}. Building more than one package
         at a time can be faster, but it is not recommended: building
         multiple packages risks success when a build should have
         failed due to missing dependencies, and it risks corruption
         due to broken or nefarious packages.}

   @item{@racket[server-port] --- A TCP port to use for serving
         packages from the build machine to VirtualBox @tech{VMs}.
         This server is not started if @racket[vms] contains only
         Docker @tech{VMs}.}

]}

@defproc[(vm? [v any/c]) boolean?]{

Recognizes a @tech{VM} crreated by @racket[docker-vm] or @racket[vbox-vm].}


@defproc[(docker-vm
          [#:name name string?]
          [#:from-image from-image string?]
          [#:dir dir string? "/home/root/"]
          [#:env env (listof (cons/c string? string?)) null]
          [#:shell shell (listof string?) '("/bin/sh" "-c")]
          [#:minimal-variant minimal-variant (or/c #f vm?) #f])
         vm?]{

Creates a @tech{VM} that specifies a Docker image and container. The
given @racket[name] will be used to name a new image (replacing any
existing @racket[name] image) that is built starting with
@racket[from-image] and that holds the Racket installation.
@margin-note*{At the time of writing, @racket["mflatt/pkg-build-deps"]
and/or @racket["mflatt/pkg-build-deps:min"] is suitable as
@racket[from-image].} The given @racket[name] is also used for a
container that is an instance of the image; the container is created
fresh (replacing any existing @racket[name] container) for each
package to build.

The @racket[dir] argument specifies a working directory within the
Docker container.

The @racket[env] argument specifies environment variable settings that
prefix every command.

The @racket[shell] argument determines the shell command that is used
to run shell-command strings in the container.

The @racket[minimal-variant] argument, if not @racket[#f], specifies a
@tech{VM} to try before this one. If installation fails with the
@racket[minimal-variant] @tech{VM}, it is tried again with this one.
Tests run in this @tech{VM}, however, instead of
@racket[minimal-variant].}

@defproc[(vbox-vm
          [#:name name string?]
          [#:host host string?]
          [#:user user string? "racket"]
          [#:ssh-key ssh-key (or/c #f path-string?) #f]
          [#:dir dir string? "/home/racket/build-pkgs"]
          [#:env env (listof (cons/c string? string?)) null]
          [#:shell shell (listof string?) '("/bin/sh" "-c")]
          [#:init-shapshot init-snapshot string? "init"]
          [#:installed-shapshot installed-snapshot string? "installed"]
          [#:minimal-variant minimal-variant (or/c #f vm?) #f])
         vm?]{

Creates a @tech{VM} that specifies a VirtualBox virtual machine with
the given @racket[name]. The @racket[host] string specifies the IP
address of the machine to access it using @exec{ssh}, and
@racket[user] is the user for that @exec{ssh}. You must configure the
virtual machine and the host's SSH settings so that @exec{ssh} works
without a password. The @racket[ssh-key] argument can name a file
containing private key to use for @exec{ssh} as @racket[user].

The @racket[dir] argument specifies a working directory within the
virtual machine.

The @racket[env] argument specifies environment variable settings that
prefix every command.

The @racket[shell] argument determines the shell command that is used
to run shell-command strings in the virtual machine.

The @racket[init-snapshot] string names a snapshot that exists as the
starting point in the virtual machine, so that it can be reset to a
state before any Racket installation. You must configure the virtual
machine to have this snapshot.

The @racket[installed-snapshot] string names a snapshot that will be
created by @racket[build-pkgs] after it installs Racket in the virtual
machine. If a snapshot using this name already exists, it may be
replaced.

The @racket[minimal-variant] argument, if not @racket[#f], specifies a
@tech{VM} to try before this one. If installation fails with the
@racket[minimal-variant] @tech{VM}, it is tried again with this one.
Tests run in this @tech{VM}, however, instead of
@racket[minimal-variant].}

@defproc[(steps-in [start symbol?] [end symbol?]) (listof symbol?)]{

A helper to generate a @racket[#:steps] argument to @racket[build-pkgs]
that has steps @racket[start] through @racket[end] inclusive. See
@racket[build-pkgs] for the allowed step symbols.}
