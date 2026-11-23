(use-modules (gnu)
             (guix build-system trivial)
             (guix build-system gnu)
             (guix build-system copy)
             (guix download)
             (guix git-download)
             (guix licenses)
             (guix packages)
             (guix gexp)
             (guix utils)
             (gnu packages linux)
             (gnu packages base)
             (gnu packages compression)
             (gnu packages parallel)
             (gnu packages admin)
             (gnu system linux-initrd)
             (guix modules)
             (srfi srfi-1)
             (ice-9 match)
             (ice-9 binary-ports)
             (guix build utils))

(use-service-modules cups dbus desktop networking ssh sound xorg)

(define (nonfree uri)
  "Return a nonfree license object."
  (license "nonfree" uri #f))

(define (linux-url version)
  "Return a URL for Linux VERSION."
  (string-append "mirror://kernel.org"
                 "/linux/kernel/v" (version-major version) ".x"
                 "/linux-" version ".tar.xz"))

(define-public (nonguix-extra-linux-options linux-or-version)
  "Return a list containing additional options that nonguix sets by default
for a corrupted linux package of specified version."
  (define linux-version
    (if (package? linux-or-version)
        (package-version linux-or-version)
        linux-or-version))

  (reverse (fold (λ (opt opts)
                   (if (version>=? linux-version (car opt))
                       (cons* (cdr opt) opts)
                       opts))
                 '()
                 '(
                   ;; Driver for MT7612U-based wireless USB 3.0 dongles.
                   ("3.10" . "CONFIG_MT76x2U=m")
                   ;; Enable support for CIK (Sea Islands) asics
                   ("3.10" . "CONFIG_DRM_AMDGPU_CIK=y")
                   ("3.10" . "CONFIG_DRM_AMDGPU_SI=y")
                   ;; Driver for MediaTek mt7921e wireless chipset
                   ("5.15" . "CONFIG_MT7921E=m")
                   ;; Activate driver module for RT1318/RT713 (Lunar Lake)
                   ("6.12" . "CONFIG_SND_SOC_INTEL_USER_FRIENDLY_LONG_NAMES=y")
                   ("6.12" . "CONFIG_SND_SOC_INTEL_SOUNDWIRE_SOF_MACH=m")))))

(define* (corrupt-linux freedo
                        #:key
                        (name "linux")
                        (configs "")
                        (defconfig "nonguix_defconfig")
                        (get-extra-configs nonguix-extra-linux-options)
                        modconfig)
  ;; TODO: This very directly depends on guix internals.
  (define gexp-inputs (@@ (guix gexp) gexp-inputs))
  (define linux-srcarch
    (@@ (gnu packages linux) linux-srcarch))
  (define extract-gexp-inputs
    (compose gexp-inputs force origin-uri))
  (define (origin->input-things origin)
    (map gexp-input-thing (extract-gexp-inputs origin)))
  (define (extract-sources inputs)
    (fold (λ (input sources)
            (if (origin? input)
                (if (string? (origin-uri input))
                    (acons (origin-uri input) (origin-hash input) sources)
                    (append sources
                            (extract-sources (origin->input-things input))))
                sources))
          '()
          inputs))
  (let* ((version (package-version freedo))
         (url (linux-url version))
         (pristine-source (package-source freedo))
         (inputs (map gexp-input-thing (extract-gexp-inputs pristine-source)))
         (sources (extract-sources inputs))
         (hash (or (assoc-ref sources url)
                   (error "fail to find hash for" freedo)))
         (patches
          (delete (@@ (gnu packages linux) %boot-logo-patch)
                  (origin-patches pristine-source))))
    (package
      (inherit
       (customize-linux
        #:name name
        #:linux
        (package
          (inherit freedo)
          (version version)
          (arguments
           (substitute-keyword-arguments (package-arguments freedo)
             ((#:phases phases '%standard-phases)
              #~(modify-phases #$phases
                  (add-before 'configure 'nonguix-configure
                    (λ args
                      (let ((defconfig
                             (format #f "arch/~a/configs/nonguix_defconfig"
                                     #$(linux-srcarch))))
                        (apply (assoc-ref #$phases 'configure) args)
                        (modify-defconfig
                         ".config" '#$(get-extra-configs this-package))
                        (invoke "make" "savedefconfig")
                        (rename-file "defconfig" defconfig)))))))))
        #:source (origin
                   (method url-fetch)
                   (uri url)
                   (hash hash)
                   (patches patches))
        #:configs configs
        #:defconfig defconfig
        #:modconfig modconfig))
      (home-page "https://www.kernel.org/")
      (synopsis "Linux kernel with nonfree binary blobs included")
      (description
       "The unmodified Linux kernel, including nonfree blobs, for running Guix System
on hardware which requires nonfree software to function."))))

(define linux
  (corrupt-linux linux-libre))

(define linux-firmware
  (package
    (name "linux-firmware")
    (version "20261019")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kernel.org/linux/kernel/firmware/"
                                  "linux-firmware-" version ".tar.xz"))
              (sha256
               (base32
                "1jnl1kblhpkrvc0dz9nzplk6qsciwq9z6z4c5sllpizjpasil3d1"))))
    (build-system gnu-build-system)
    (arguments
     (list #:tests? #f
           #:strip-binaries? #f
           #:validate-runpath? #f
           #:make-flags #~(list (string-append "DESTDIR=" #$output))
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'patch-out-check_whence.py
                 (λ _
                   (substitute* "copy-firmware.sh"
                     (("./check_whence.py")
                      "true"))))
               (delete 'configure)
               (replace 'install
                 (λ* (#:key (parallel-build? #t) (make-flags '())
                           #:allow-other-keys)
                   (let ((num-jobs (if parallel-build?
                                       (number->string (parallel-job-count))
                                       "1")))
                     (setenv "ZSTD_CLEVEL" "19")
                     (setenv "ZSTD_NBTHREADS" num-jobs)
                     (apply invoke "make" "install-zst" "-j" num-jobs
                            make-flags)))))))
    (native-inputs (list parallel rdfind zstd))
    (home-page
     "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
    (synopsis "Nonfree firmware blobs for Linux")
    (description "Nonfree firmware blobs for enabling support for various
hardware in the Linux kernel.")
    (license
     (nonfree
      (string-append "https://git.kernel.org/pub/scm/linux/kernel/git/"
                     "firmware/linux-firmware.git/plain/WHENCE")))))

(define (select-firmware keep)
  "Modify linux-firmware copy list to retain only files matching KEEP regex."
  #~(λ _
      (use-modules (ice-9 regex))
      (substitute* "WHENCE"
        (("^(File|RawFile): *([^ ]*)(.*)" _ type file rest)
         (string-append (if (string-match #$keep file) type "Skip") ": " file rest))
        (("^Link: *(.*) *-> *(.*)" _ file target)
         (string-append (if (string-match #$keep target) "Link" "Skip")
                        ": " file " -> " target)))))

(define intel-microcode
  (package
    (name "intel-microcode")
    (version "20250512")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url (string-append
                   "https://github.com/intel/"
                   "Intel-Linux-Processor-Microcode-Data-Files.git"))
             (commit (string-append "microcode-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0da4aj0hpj6xn9vfb0k7mznndv53ihbv3mhjz71skwmy1vbibay5"))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan
           #~(let ((doc (string-append "share/doc/" #$name "-" #$version "/")))
               `(("intel-ucode" "lib/firmware/")
                 ("README.md" ,doc)
                 ("releasenote.md" ,doc)
                 ("security.md" ,doc)))))
    (home-page
     "https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files")
    (synopsis "Processor microcode firmware for Intel CPUs")
    (description "Updated system processor microcode for Intel processors.")
    (license (nonfree "file://license"))))

(define amd-microcode
  (package
    (inherit linux-firmware)
    (name "amd-microcode")
    (arguments
     (cons* #:license-file-regexp "LICENSE.amd-ucode"
            (substitute-keyword-arguments (package-arguments linux-firmware)
              ((#:phases phases #~%standard-phases)
               #~(modify-phases #$phases
                   (add-after 'unpack 'select-firmware
                     #$(select-firmware "^amd-ucode/")))))))
    (synopsis "Processor microcode firmware for AMD CPUs")
    (description "Updated system processor microcode for AMD x86-64 processors.")
    (license
     (nonfree
      (string-append "https://git.kernel.org/pub/scm/linux/kernel/git/"
                     "firmware/linux-firmware.git/plain/LICENSE.amd-ucode")))))

;; Only import Guix/GNU modules; exclude the one that pulls in (gcrypt hash)
(define (import-microcode-module? module)
  "Return true if MODULE is a Guix or GNU module that is safe for the initrd.
   Excludes (guix store deduplication) and everything else (ice-9, srfi, ...)."
  (and (or (eq? (car module) 'guix)
           (eq? (car module) 'gnu))
       (not (equal? module '(guix store deduplication)))))

(define (concatenate-files-gexp)
  #~(define (concatenate-files files result)
      "Make RESULT the concatenation of all of FILES (binary-safe)."
      (call-with-output-file result
        (λ (out)
          (for-each
           (λ (file)
             (call-with-input-file file
               (λ (in)
                 (let loop ()
                   (let ((bv (get-bytevector-some in)))
                     (unless (eof-object? bv)
                       (put-bytevector out bv)
                       (loop)))))
               #:binary #t))
           files))
        #:binary #t)))

(define* (microcode-initrd file-systems
                           #:key
                           (initrd base-initrd)
                           (microcode-packages (list amd-microcode
                                                     intel-microcode))
                           #:allow-other-keys
                           #:rest rest)
  "Build INITRD, extended to include x86 processor microcode from
MICROCODE-PACKAGES."
  (let ((args (strip-keyword-arguments '(#:initrd #:microcode-packages) rest)))
    (combined-initrd (microcode-initrd* microcode-packages)
                     (apply initrd file-systems
                            args))))

(define (microcode-initrd* microcode-packages)
  "Build an uncompressed initrd containing x86 processor microcode."
  (define builder
    (with-imported-modules (source-module-closure
                            '((gnu build linux-initrd)
                              (guix build utils))
                            #:select? import-microcode-module?)
      #~(begin
          (use-modules (gnu build linux-initrd)
                       (guix build utils)
                       (ice-9 binary-ports))
          #$(concatenate-files-gexp)
          (let* ((initrd (string-append #$output "/initrd.cpio"))
                 (dest-dir "kernel/x86/microcode")
                 (amd-bin   (string-append dest-dir "/AuthenticAMD.bin"))
                 (intel-bin (string-append dest-dir "/GenuineIntel.bin")))
            (mkdir-p dest-dir)
            (for-each
             (λ (package)
               (let ((intel-ucode (string-append package
                                                 "/lib/firmware/intel-ucode"))
                     (amd-ucode (string-append package
                                               "/lib/firmware/amd-ucode")))
                 (when (directory-exists? intel-ucode)
                   (concatenate-files (find-files intel-ucode ".*")
                                      intel-bin))
                 (when (directory-exists? amd-ucode)
                   (concatenate-files (find-files amd-ucode
                                                  "^microcode_amd.*\\.bin$")
                                      amd-bin))))
             '#$microcode-packages)
            (mkdir-p #$output)
            (write-cpio-archive initrd "kernel" #:compress? #f)))))
  (file-append (computed-file "microcode-initrd" builder)
               "/initrd.cpio"))

(define (combined-initrd . initrds)
  "Return a combined initrd by concatenating INITRDS."
  (define builder
    (with-imported-modules (source-module-closure
                            '((guix build utils))
                            #:select? import-microcode-module?)
      #~(begin
          (use-modules (guix build utils)
                       (ice-9 binary-ports))
          #$(concatenate-files-gexp)
          (let ((initrd (string-append #$output "/initrd.img"))
                (references
                 (let loop ((lst '#$initrds) (acc '()))
                   (if (null? lst)
                       (reverse acc)
                       (let* ((initrd (car lst))
                              (ref (string-append (dirname initrd) "/references")))
                         (loop (cdr lst)
                               (if (file-exists? ref)
                                   (cons ref acc)
                                   acc))))))
                (new-references
                 (string-append #$output "/references")))
            (mkdir-p #$output)
            (concatenate-files '#$initrds initrd)
            (when (not (null? references))
              (concatenate-files references new-references))))))
  (file-append (computed-file "combined-initrd" builder)
               "/initrd.img"))

(define patchelf-0.19
  (let* ((gcc     (@@ (gnu packages gcc) gcc))
         (binutils (@@ (gnu packages base) binutils))
         (glibc   (@@ (gnu packages base) glibc)))
    (package
      (name "patchelf")
      (version "0.19.0")
      (source
       (origin
         (method url-fetch)
         (uri (string-append "https://github.com/NixOS/patchelf/releases/download/"
                             version "/patchelf-" version ".tar.bz2"))
         (sha256
          (base32 "1x987whhmhh71bpyd2i2r5pgjfkd2cgklzcybf4mf1vkaznd72di"))))
      (build-system gnu-build-system)
      (arguments
       (list #:tests? #f))
      (inputs
       (list (list gcc "lib") glibc))
      (native-inputs
       (list gcc binutils))
      (synopsis "Modify ELF interpreter and RPATH (0.19)")
      (description "PatchELF 0.19, required for --no-clobber-old-sections.")
      (home-page "https://github.com/NixOS/patchelf")
      (license gpl3+)
      (supported-systems '("x86_64-linux")))))

(define firefox-bin
  (let* ((glibc         (@@ (gnu packages base) glibc))
         (gtk+          (@@ (gnu packages gtk) gtk+))
         (gtk+-2        (@@ (gnu packages gtk) gtk+-2))
         (pango         (@@ (gnu packages gtk) pango))
         (cairo         (@@ (gnu packages gtk) cairo))
         (freetype      (@@ (gnu packages fontutils) freetype))
         (fontconfig    (@@ (gnu packages fontutils) fontconfig))
         (dbus          (@@ (gnu packages glib) dbus))
         (pulseaudio    (@@ (gnu packages pulseaudio) pulseaudio))
         (alsa-lib      (@@ (gnu packages linux) alsa-lib))
         (mesa          (@@ (gnu packages gl) mesa))
         (libx11        (@@ (gnu packages xorg) libx11))
         (libxtst       (@@ (gnu packages xorg) libxtst))
         (libxcomposite (@@ (gnu packages xorg) libxcomposite))
         (libxdamage    (@@ (gnu packages xorg) libxdamage))
         (libxext       (@@ (gnu packages xorg) libxext))
         (libxfixes     (@@ (gnu packages xorg) libxfixes))
         (libxrender    (@@ (gnu packages xorg) libxrender))
         (gcc           (@@ (gnu packages gcc) gcc))
         (tar           (@@ (gnu packages base) tar))
         (xz            (@@ (gnu packages compression) xz))
         (patchelf      patchelf-0.19)
         (coreutils     (@@ (gnu packages base) coreutils)))
    (package
      (name "firefox-bin")
      (version "160.0")
      (source
       (origin
         (method url-fetch)
         (uri (string-append "https://ftp.mozilla.org/pub/firefox/releases/"
                             version "/linux-x86_64/en-US/firefox-"
                             version ".tar.xz"))
         (sha256
          (base32 "1kazyc24qdifzcgr8msc4hdnmgwjnl6j3v059i9pi23wfplp9rzx"))))
      (build-system trivial-build-system)
      (arguments
       (list
        #:modules '((guix build utils))
        #:builder
        #~(begin
            (use-modules (guix build utils))
            (let* ((out          #$output)
                   (source       #$(package-source this-package))
                   (tar-bin      (string-append #$tar "/bin/tar"))
                   (patchelf-bin (string-append #$patchelf "/bin/patchelf"))
                   (interpreter  (string-append #$glibc "/lib/ld-linux-x86-64.so.2"))
                   (gcc-lib      #$(gexp-input gcc "lib"))
                   (rpath        (string-join
                                  (list (string-append #$glibc "/lib")
                                        (string-append gcc-lib "/lib")
                                        (string-append #$gtk+ "/lib")
                                        (string-append #$gtk+-2 "/lib")
                                        (string-append #$pango "/lib")
                                        (string-append #$cairo "/lib")
                                        (string-append #$freetype "/lib")
                                        (string-append #$fontconfig "/lib")
                                        (string-append #$dbus "/lib")
                                        (string-append #$pulseaudio "/lib")
                                        (string-append #$alsa-lib "/lib")
                                        (string-append #$mesa "/lib")
                                        (string-append #$libx11 "/lib")
                                        (string-append #$libxtst "/lib")
                                        (string-append #$libxcomposite "/lib")
                                        (string-append #$libxdamage "/lib")
                                        (string-append #$libxext "/lib")
                                        (string-append #$libxfixes "/lib")
                                        (string-append #$libxrender "/lib"))
                                  ":")))
              (setenv "PATH" (string-append #$coreutils "/bin:"
                                            #$tar "/bin:"
                                            #$xz "/bin"))
              (invoke tar-bin "xf" source)
              (chdir "firefox")
              (define executables
                '("firefox" "firefox-bin" "plugin-container" "updater"
                  "crashreporter" "webapprt-stub" "glxtest" "vaapitest"))
              (for-each
               (λ (file)
                 (when (file-exists? file)
                   (invoke patchelf-bin
                           "--no-clobber-old-sections"
                           "--set-interpreter" interpreter
                           file)
                   (invoke patchelf-bin
                           "--no-clobber-old-sections"
                           "--set-rpath" rpath
                           file)))
               executables)
              (for-each
               (λ (file)
                 (when (and (string-suffix? ".so" file)
                            (file-exists? file))
                   (invoke patchelf-bin
                           "--no-clobber-old-sections"
                           "--set-rpath" rpath
                           file)))
               '("libxul.so" "libmozgtk.so" "liblgpllibs.so"
                 "libmozsandbox.so" "libnspr4.so" "libnss3.so"
                 "libnssutil3.so" "libplc4.so" "libplds4.so"
                 "libsmime3.so" "libssl3.so"))
              (mkdir-p (string-append out "/lib"))
              (mkdir-p (string-append out "/bin"))
              (copy-recursively "." (string-append out "/lib/firefox"))
              (symlink (string-append out "/lib/firefox/firefox")
                       (string-append out "/bin/firefox"))
              (mkdir-p (string-append out "/share/applications"))
              (call-with-output-file
                  (string-append out "/share/applications/firefox.desktop")
                (λ (port)
                  (format port "\
[Desktop Entry]
Name=Firefox
Exec=~a/bin/firefox %u
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;
StartupNotify=true
Terminal=false
" out)))))))
      (inputs
       (list glibc
             (list gcc "lib")
             gtk+ gtk+-2 pango cairo freetype fontconfig
             dbus pulseaudio alsa-lib mesa libx11 libxtst libxcomposite libxdamage
             libxext libxfixes libxrender))
      (native-inputs
       (list tar xz patchelf coreutils))
      (supported-systems '("x86_64-linux"))
      (home-page "https://www.mozilla.org/firefox/")
      (synopsis "Mozilla Firefox (official binary)")
      (description "Official Mozilla Firefox binary, patched with patchelf 0.19.")
      (license mpl2.0))))

(operating-system
  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))
  (locale "C.utf8")
  (timezone "Europe/Berlin")
  (keyboard-layout (keyboard-layout "us" "altgr-intl"))
  (host-name "aaliyah")
  (users (cons* (user-account
                  (name "xha")
                  (comment "Xaver Hellauer")
                  (group "users")
                  (home-directory "/home/xha")
                  (supplementary-groups '("wheel" "netdev" "audio" "video" "input")))
                %base-user-accounts))
  (packages (append (list (specification->package "alacritty")
                          (specification->package "alsa-utils")
                          (specification->package "emacs-motif")
                          (specification->package "fvwm3")
                          (specification->package "git")
                          (specification->package "htop")
                          firefox-bin
                          (specification->package "firefox")
                          (specification->package "ratpoison")
                          (specification->package "tmux")
                          (specification->package "vim")
                          (specification->package "zsh")
                          (specification->package "fastfetch-minimal")
                          (specification->package "font-google-noto")
                          (specification->package "font-google-noto-emoji")
                          (specification->package "font-sarasa-gothic"))
                    %base-packages))
  (services
    (cons*
       (simple-service 'nonguix-substitutes guix-service-type
                               (guix-extension
                                 (substitute-urls (list "https://substitutes.nonguix.org"))
                                 (authorized-keys (list (plain-file "non-guix.pub"
              "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))")))))
      (service startx-command-service-type
               (xorg-configuration))
      (simple-service 'guix-artwork
                      profile-service-type
                      %base-packages-artwork)
      fontconfig-file-system-service
      (service dbus-root-service-type)
      (service iwd-service-type
               (iwd-configuration
                 (shepherd-provision '(iwd wireless-daemon networking))
                 (config
                   (iwd-settings
                     (general
                       (iwd-general-settings
                         (enable-network-configuration? #t)))
                     (network
                       (iwd-network-settings
                         (enable-ipv6? #t)
                         (name-resolving-service 'resolvconf)))))))
      (service ntp-service-type)
      (service x11-socket-directory-service-type)
      (service alsa-service-type)
      %base-services))
  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (targets (list "/boot/efi"))
                (keyboard-layout keyboard-layout)))
  (file-systems (cons* (file-system
                         (mount-point "/")
                         (options "subvol=/@guix,compress=zstd:5")
                         (device (uuid
                                  "8627cce6-a6df-4f9d-ad38-4978b04d5716"
                                  'btrfs))
                         (type "btrfs"))
                       (file-system
                         (mount-point "/boot/efi")
                         (device (uuid "A176-94B5"
                                       'fat32))
                         (type "vfat")) %base-file-systems)))
