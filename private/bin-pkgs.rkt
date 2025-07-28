#lang racket/base

(provide main-dist-bin-pkgs)

(define main-dist-bin-pkgs
  (list "com-win32-i386" "com-win32-x86_64"
        "db-ppc-macosx" "db-win32-i386" "db-win32-x86_64" "db-win32-arm64"
        "db-x86_64-linux-natipkg" "db-aarch64-linux-natipkg"
        "draw-i386-macosx" "draw-i386-macosx-2" "draw-i386-macosx-3"
        "draw-ppc-macosx" "draw-ppc-macosx-2" "draw-ppc-macosx-3"
        "draw-win32-i386" "draw-win32-i386-2" "draw-win32-i386-3"
        "draw-win32-x86_64" "draw-win32-x86_64-2" "draw-win32-x86_64-3"
        "draw-win32-arm64-3"
        "draw-x86_64-macosx" "draw-x86_64-macosx-2" "draw-x86_64-macosx-3"
        "draw-aarch64-macosx-3"
        "draw-x86_64-linux-natipkg-2" "draw-x86_64-linux-natipkg-3"
        "draw-ttf-x86_64-linux-natipkg" "draw-x11-x86_64-linux-natipkg"
        "draw-aarch64-linux-natipkg-2" "draw-aarch64-linux-natipkg-3"
        "draw-ttf-aarch64-linux-natipkg" "draw-x11-aarch64-linux-natipkg"
        "gui-i386-macosx" "gui-ppc-macosx" "gui-win32-i386"
        "gui-win32-x86_64" "gui-x86_64-macosx"
        "gui-x86_64-linux-natipkg" "gui-aarch64-linux-natipkg"
        "math-i386-macosx" "math-ppc-macosx" "math-win32-i386"
        "math-win32-x86_64" "math-x86_64-macosx"
        "math-x86_64-linux-natipkg" "math-aarch64-linux-natipkg"
        "racket-win32-i386" "racket-win32-i386-2" "racket-win32-i386-3"
        "racket-win32-x86_64" "racket-win32-x86_64-2" "racket-win32-x86_64-3"
        "racket-win32-arm64-3"
	"racket-x86_64-macosx-2" "racket-x86_64-macosx-3" "racket-x86_64-macosx-4"
        "racket-i386-macosx-2" "racket-i386-macosx-3"
	"racket-ppc-macosx-2" "racket-ppc-macosx-3"
        "racket-aarch64-macosx-3" "racket-aarch64-macosx-4"
        "racket-x86_64-linux-natipkg-2""racket-x86_64-linux-natipkg-3"
        "racket-aarch64-linux-natipkg-3"))
