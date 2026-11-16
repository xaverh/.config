(use-modules (gnu)
             (gnu system nss)
             (gnu system pam)
             (rnrs lists)
             (gnu services databases)
             (gnu packages linux)
             (gnu packages compression)
             (gnu packages parallel)
             (gnu packages cpio)
             (guix packages)
             (guix download)
             (guix git-download)
             (guix gexp)
             (guix build-system gnu)
             (guix build-system copy)
             (guix build-system binary)
             (guix licenses)
             (ice-9 match)
             (srfi srfi-1))

(use-service-modules desktop networking ssh xorg mcron cups sysctl virtualization sound)

(use-package-modules android bootloaders ccache certs cups databases
                     emacs emacs-xyz fonts geo ghostscript gnome gnupg guile guile-xyz linux nano
                     ntp python python-xyz ratpoison scanner screen ssh suckless tex
                     version-control vim wm xfce xorg gnuzilla)

;; ---------- licenses ----------
(define (nonfree uri)
  (license "Nonfree" uri
           "This is a nonfree license. Check the URI for details."))

;; ---------- kernel helpers (from nonguix) ----------
(define (linux-url version)
  (string-append "mirror://kernel.org/linux/kernel/v"
                 (version-major version) ".x/linux-" version ".tar.xz"))

(define (nonguix-extra-linux-options linux-or-version)
  (define linux-version
    (if (package? linux-or-version)
        (package-version linux-or-version)
        linux-or-version))
  (reverse (fold (lambda (opt opts)
                   (if (version>=? linux-version (car opt))
                       (cons* (cdr opt) opts)
                       opts))
                 '()
                 '(("3.10" . "CONFIG_MT76x2U=m")
                   ("3.10" . "CONFIG_DRM_AMDGPU_CIK=y")
                   ("3.10" . "CONFIG_DRM_AMDGPU_SI=y")
                   ("5.15" . "CONFIG_MT7921E=m")
                   ("6.12" . "CONFIG_SND_SOC_INTEL_USER_FRIENDLY_LONG_NAMES=y")
                   ("6.12" . "CONFIG_SND_SOC_INTEL_SOUNDWIRE_SOF_MACH=m")))))

(define* (corrupt-linux freedo
                        #:key
                        (name "linux")
                        (configs "")
                        (defconfig "nonguix_defconfig")
                        (get-extra-configs nonguix-extra-linux-options)
                        modconfig)
  (define gexp-inputs (@@ (guix gexp) gexp-inputs))
  (define linux-srcarch (@@ (gnu packages linux) linux-srcarch))
  (define extract-gexp-inputs (compose gexp-inputs force origin-uri))
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
                    (lambda args
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
       "The unmodified Linux kernel, including nonfree blobs."))))

(define linux (corrupt-linux linux-libre))   ; current latest, same as nonguix

;; ---------- firmware ----------
(define (select-firmware keep)
  #~(lambda _
      (use-modules (ice-9 regex))
      (substitute* "WHENCE"
        (("^(File|RawFile): *([^ ]*)(.*)" _ type file rest)
         (string-append (if (string-match #$keep file) type "Skip") ": " file rest))
        (("^Link: *(.*) *-> *(.*)" _ file target)
         (string-append (if (string-match #$keep target) "Link" "Skip")
                        ": " file " -> " target)))))

(define linux-firmware
  (package
    (name "linux-firmware")
    (version "20261019")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kernel.org/linux/kernel/firmware/"
                                  "linux-firmware-" version ".tar.xz"))
              (sha256 (base32 "1jnl1kblhpkrvc0dz9nzplk6qsciwq9z6z4c5sllpizjpasil3d1"))))
    (build-system gnu-build-system)
    (arguments
     (list #:tests? #f
           #:strip-binaries? #f
           #:validate-runpath? #f
           #:make-flags #~(list (string-append "DESTDIR=" #$output))
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'patch-out-check_whence.py
                 (lambda _
                   (substitute* "copy-firmware.sh"
                     (("./check_whence.py") "true"))))
               (delete 'configure)
               (replace 'install
                 (lambda* (#:key (parallel-build? #t) (make-flags '())
                           #:allow-other-keys)
                   (let ((num-jobs (if parallel-build?
                                       (number->string (parallel-job-count))
                                       "1")))
                     (setenv "ZSTD_CLEVEL" "19")
                     (setenv "ZSTD_NBTHREADS" num-jobs)
                     (apply invoke "make" "install-zst" "-j" num-jobs
                            make-flags)))))))
    (native-inputs (list parallel rdfind zstd))
    (home-page "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
    (synopsis "Nonfree firmware blobs for Linux")
    (description "Nonfree firmware blobs.")
    (license (nonfree "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/WHENCE"))))

(define iwlwifi-firmware
  (package
    (inherit linux-firmware)
    (name "iwlwifi-firmware")
    (arguments
     (cons* #:license-file-regexp "LICENCE.iwlwifi_firmware"
            (substitute-keyword-arguments (package-arguments linux-firmware)
              ((#:phases phases #~%standard-phases)
               #~(modify-phases #$phases
                   (add-after 'unpack 'select-firmware
                     #$(select-firmware "^intel/iwlwifi/")))))))
    (synopsis "Nonfree firmware for Intel wifi chips")
    (description "Firmware for Intel Wi-Fi (iwlwifi).")
    (license (nonfree "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/LICENCE.iwlwifi_firmware"))))

;; ---------- microcode ----------
(define intel-microcode
  (package
    (name "intel-microcode")
    (version "20250512")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files.git")
             (commit (string-append "microcode-" version))))
       (file-name (git-file-name name version))
       (sha256 (base32 "0da4aj0hpj6xn9vfb0k7mznndv53ihbv3mhjz71skwmy1vbibay5"))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan
           #~(let ((doc (string-append "share/doc/" #$name "-" #$version "/")))
               `(("intel-ucode" "lib/firmware/")
                 ("README.md" ,doc)
                 ("releasenote.md" ,doc)
                 ("security.md" ,doc)))))
    (home-page "https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files")
    (synopsis "Processor microcode firmware for Intel CPUs")
    (description "Updated Intel microcode.")
    (license (nonfree "file://license"))))

;; ---------- microcode initrd ----------
(define (concatenate-files files result)
  (define (dump file port)
    (put-bytevector port
                    (call-with-input-file file get-bytevector-all)))
  (call-with-output-file result
    (lambda (port)
      (for-each (cut dump <> port) files))))

(define (microcode-initrd* microcode-packages)
  (define builder
    (with-imported-modules '((guix build utils)
                             (gnu build linux-initrd))
      #~(begin
          (use-modules (guix build utils)
                       (gnu build linux-initrd)
                       (ice-9 binary-ports)
                       (srfi srfi-1)
                       (srfi srfi-26))
          (let* ((initrd (string-append #$output "/initrd.cpio"))
                 (dest-dir "kernel/x86/microcode")
                 (intel-bin (string-append dest-dir "/GenuineIntel.bin")))
            (mkdir-p dest-dir)
            (for-each
             (lambda (package)
               (let ((intel-ucode (string-append package "/lib/firmware/intel-ucode")))
                 (when (directory-exists? intel-ucode)
                   (concatenate-files (find-files intel-ucode ".*") intel-bin))))
             '#$microcode-packages)
            (mkdir-p #$output)
            (write-cpio-archive initrd "kernel" #:compress? #f)))))
  (file-append (computed-file "microcode-initrd" builder)
               "/initrd.cpio"))

(define* (microcode-initrd file-systems
                           #:key (initrd base-initrd)
                           (microcode-packages (list intel-microcode))
                           #:allow-other-keys
                           #:rest rest)
  (let ((args (strip-keyword-arguments '(#:initrd #:microcode-packages) rest)))
    (combined-initrd (microcode-initrd* microcode-packages)
                     (apply initrd file-systems args))))

(define (combined-initrd . initrds)
  (define builder
    (with-imported-modules '((guix build utils))
      #~(begin
          (use-modules (guix build utils)
                       (ice-9 binary-ports)
                       (srfi srfi-1)
                       (srfi srfi-26))
          (let ((initrd (string-append #$output "/initrd.img")))
            (mkdir-p #$output)
            (concatenate-files '#$initrds initrd)))))
  (file-append (computed-file "combined-initrd" builder)
               "/initrd.img"))

;; ---------- Google Chrome ----------
(define google-chrome-stable
  (package
    (name "google-chrome-stable")
    (version "157.0.8103.38-1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://dl.google.com/linux/chrome/deb/pool/main/g/"
                    name "/" name "_" version "_amd64.deb"))
              (sha256 (base32 "17b2vgp4k6xlmm36s1lw6fz7as3gnvg8jif01kswz8ixq1yjfax6"))))
    (build-system binary-build-system)
    (arguments
     (list #:substitutable? #f
           #:install-plan
           #~'(("opt/" "/share")
               ("usr/share/" "/share"))
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'fix-paths
                 (lambda _
                   (substitute* "opt/google/chrome/google-chrome"
                     (("CHROME_WRAPPER") "WRAPPER"))
                   (substitute* "usr/share/applications/google-chrome.desktop"
                     (("^Exec=[^ ]*") (string-append "Exec=" #$output "/bin/google-chrome")))))
               (add-after 'install 'install-wrapper
                 (lambda _
                   (let* ((bin (string-append #$output "/bin"))
                          (exe (string-append bin "/google-chrome"))
                          (target (string-append #$output "/share/google/chrome/google-chrome")))
                     (mkdir-p bin)
                     (symlink target exe)
                     (wrap-program exe
                       '("CHROME_WRAPPER" = ("chrome")))))))))
    (inputs (list bzip2 curl flac font-liberation gdk-pixbuf gtk harfbuzz
                  libexif libglvnd libpng libva libxscrnsaver opus pciutils
                  pipewire qtbase-5 qtbase snappy util-linux xdg-utils wget))
    (supported-systems '("x86_64-linux"))
    (synopsis "Freeware web browser")
    (description "Google Chrome.")
    (home-page "https://www.google.com/chrome/")
    (license (nonfree "https://www.google.com/intl/en/chrome/terms/"))))

;; setup custom sudo rules so some clearly specified commands can be
;; run without password, ALWAYS use absolute filenames here! To
;; continue working when I install a tool as user, I setup sudo-rules
;; for both the system-tools and my user-tools.
(define %sudoers-specification
  (plain-file "sudoers" "
root ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
%wheel ALL=(ALL) NOPASSWD: /run/current-system/profile/bin/cpupower
%wheel ALL=(ALL) NOPASSWD: /run/current-system/profile/bin/mount --bind /run/user/1000/intellij/caches /home/MYSELF/.IntelliJIdea2019.3/system/caches
%wheel ALL=(ALL) NOPASSWD: /run/current-system/profile/bin/mount --bind /run/user/1000/intellij/index /home/MYSELF/.IntelliJIdea2019.3/system/index
%wheel ALL=(ALL) NOPASSWD: /run/current-system/profile/bin/umount /home/MYSELF/.IntelliJIdea2019.3/system/caches
%wheel ALL=(ALL) NOPASSWD: /run/current-system/profile/bin/umount /home/MYSELF/.IntelliJIdea2019.3/system/index
%wheel ALL=(ALL) NOPASSWD: /run/current-system/profile/bin/umount
%wheel ALL=(ALL) NOPASSWD: /home/MYSELF/.guix-profile/bin/mount --bind /run/user/1000/intellij/caches /home/MYSELF/.IntelliJIdea2019.3/system/caches
%wheel ALL=(ALL) NOPASSWD: /home/MYSELF/.guix-profile/bin/mount --bind /run/user/1000/intellij/index /home/MYSELF/.IntelliJIdea2019.3/system/index
%wheel ALL=(ALL) NOPASSWD: /home/MYSELF/.guix-profile/bin/umount /home/MYSELF/.IntelliJIdea2019.3/system/caches
%wheel ALL=(ALL) NOPASSWD: /home/MYSELF/.guix-profile/bin/umount /home/MYSELF/.IntelliJIdea2019.3/system/index
%wheel ALL=(ALL) NOPASSWD: /home/MYSELF/.guix-profile/bin/umount
"))

;; cron format: minute hour day-of-month month day-of-week
;; TODO: migrate crons to clearer syntax:   #~(job '(next-hour '(3)) (string-append #$btrfs-progs "/bin/btrfs scrub start -c 3 /")))
(define cpupower-powersave-job
  ;; Set the governor to powersave every minute, except for the time
  ;; between 3 and 5 to permit rebuilding. This reduces my
  ;; power-consumption from 120W to 30W.
  #~(job "* 0-2,5-23 * * *"            ;Vixie cron syntax
         "cpupower frequency-set -g powersave -u 1200000")) ;; use powersave governor with a maximum frequency of 1200MHz

(define lift-nofile-limit-job
  ;; Lift the maximum open files restriction for all processes every 30 minutes
  #~(job "0-59/30 * * * *"            ;Vixie cron syntax
         "for i in $(pgrep .); do sudo prlimit --pid $i --nofile=1000000:1000000; done"))

(define renice-guix-daemon-job
  ;; renice guix-daemon to prevent competing with work
  #~(job "* 7 * * *" "sleep 300; pgrep guix-daemon | xargs renice -n 10"))

(define guix-reconfigure-job
  ;; gc (remove packages older than 2 months, keep at least 500G free), pull and update every day at 03:05
  #~(job "5 3 * * *"            ;Vixie cron syntax
         "guix gc --optimize -d 2m && guix gc -F 500G && guix pull && guix system reconfigure -k /etc/config.scm"))

(define guix-release-throttle-job
  ;; release CPU throttle at 3:00, just before guix reconfigure starts
  #~(job "0 3 * * *"            ;Vixie cron syntax
         "cpupower frequency-set -g powersave -u 6000000"))

(define arnebab-org-publish-job
  ;; gc (publish my website every day at 02:00
  #~(job "* 2 * * *"            ;Vixie cron syntax
         "su - MYSELF bash -c 'cd ~/Schreibtisch/arnebab-org && make && hg push sr.ht && hg push'"))

(operating-system
 (host-name "fluss")
 (timezone "Europe/Berlin")
 (locale "de_DE.utf8")
 (sudoers-file %sudoers-specification)
 (hosts-file
  ;; Create a /etc/hosts file with aliases for "localhost"
  ;; and "mymachine", as well as for Facebook servers.
  (plain-file "hosts"
              (string-append (local-host-aliases host-name)
                             ;; block facebook, just
                             ;; because I can
                             %facebook-host-aliases
                             "
# prevent connection to repo.maven.apache.org to avoid leaking build information
127.0.0.1 repo.maven.apache.org\n")))

 (keyboard-layout (keyboard-layout "de"))  ;keyboard-layout for the console
 ;; Use the UEFI variant of GRUB with the EFI System
 ;; Partition mounted on /boot/efi.
 (bootloader (bootloader-configuration
              (bootloader grub-efi-bootloader)
              (target "/boot/efi")
              (keyboard-layout keyboard-layout))) ;; for grub

 ;; Assume the target root file system is labelled "my-root",
 ;; and the EFI System Partition has UUID 1234-ABCD.
 (file-systems (append (list
                        (file-system
                         (device (file-system-label "wurzel"))
                         (mount-point "/")
                         (type "ext4"))
                        (file-system
                         (device (uuid "D632-E42D" 'fat))
                         (mount-point "/boot/efi")
                         (type "vfat"))
                        (file-system
                         (device (file-system-label "stamm"))
                         (mount-point "/home")
                         (type "ext4"))
                        (file-system
                         (device (file-system-label "blattwerk"))
                         (mount-point "/mnt/blattwerk")
                         (type "ext4"))
                        (file-system
                         (device (file-system-label "schatten"))
                         (mount-point "/mnt/schatten")
                         (type "ext4"))
                        ;; does not work:
                        ;;                      (file-system
                        ;;                       (device "none")
                        ;;                       (mount-point "/run/user/1000")
                        ;;                       (type "tmpfs")
                        ;;              (options "defaults,size=8G"))
                        )
                       %base-file-systems))
 (swap-devices (list "/swapfiles/swapfile1"
                     ;; swapfile2 is for interactive emergency use in
                     ;; case I run OOM, for example when working
                     ;; while chromium is being built
                     "/swapfiles/swapfile3"
                     "/swapfiles/swapfile4"))

 (users (append (list
                 (user-account
                  (name "SHARED")
                  (comment "OUR_NAME")
                  (group "users")
                  (supplementary-groups '("netdev"
                                          "audio" "video"
                                          "lpadmin" "kvm" "lp"
                                          "cdrom" "disk"
                                          "scanner" "adbusers"))
                  (home-directory "/home/SHARED"))
                 (user-account
                  (name "MYSELF")
                  (comment "ME_AND_MYSELF")
                  (group "users")
                  (supplementary-groups '("wheel" "netdev"
                                          "audio" "video"
                                          "lpadmin" "kvm" "fuse" "lp"
                                          "cdrom" "disk"
                                          "scanner" "adbusers"))
                  (home-directory "/home/MYSELF"))
                 )
                %base-user-accounts))

 (groups (append (list (user-group (name "fuse")) (user-group (name "cdrom")) (user-group (name "scanner")) (user-group (name "adbusers"))) %base-groups))

 ;; Setup installed packages in the base-system (available to all users)
 (packages (append (list
                    xfce ;fallback window manager
                    nss-certs ;for HTTPS access
                    nano emacs emacs-guix guile-wisp mercurial ;because that should always be at hand
                    vim ;some tools expect it to be there
                    gvfs ;for user mounts
                    openssh ;so that gnome ssh access works
                    gpgme ;for the symlink from /usr/bin/gpgme-json
                    cpupower ;for the cpu throttle cron jobs
                    cups foomatic-filters hplip sane-backends ijs ghostscript ;print and scan
                    ntp openntpd python-dbus fuse
                    ccache ;speed up compiles on fast disks
                    postgresql ;; had to be be installed in the system for the postgres service
                    google-chrome-stable
                    ;; lots of fonts from package fonts.scm
                    font-adobe-source-code-pro font-adobe-source-han-sans
                    font-adobe-source-sans-pro font-adobe-source-serif-pro
                    font-anonymous-pro font-anonymous-pro-minus font-awesome
                    font-bitstream-vera font-blackfoundry-inria font-cantarell
                    font-cns11643 font-cns11643-swjz font-comic-neue font-culmus
                    font-dejavu font-dosis font-dseg font-fantasque-sans font-fira-code
                    font-fira-mono font-fira-sans font-fontna-yasashisa-antique
                    font-gnu-freefont font-gnu-freefont-ttf font-gnu-unifont font-go
                    font-google-material-design-icons font-google-noto font-google-roboto
                    font-hack font-hermit font-ibm-plex font-inconsolata font-iosevka
                    font-iosevka-aile font-iosevka-etoile font-iosevka-slab
                    font-iosevka-sparkle font-iosevka-term font-iosevka-term-slab
                    font-ipa-mj-mincho font-jetbrains-mono font-lato font-liberation
                    font-linuxlibertine font-lohit font-meera-inimai font-mononoki
                    font-mplus-testflight font-open-dyslexic font-opendyslexic
                    font-public-sans font-rachana font-sarasa-gothic font-sil-andika
                    font-sil-charis font-sil-gentium font-tamzen font-terminus
                    font-tex-gyre font-ubuntu font-un font-vazir font-wqy-microhei
                    font-wqy-zenhei
                    ;; lots of fonts from package xorg.scm
                    font-adobe100dpi font-adobe75dpi font-cronyx-cyrillic font-dec-misc
                    font-isas-misc font-micro-misc font-misc-cyrillic font-misc-ethiopic
                    font-misc-misc font-mutt-misc font-schumacher-misc
                    font-screen-cyrillic font-sony-misc font-sun-misc font-util
                    font-winitzki-cyrillic font-xfree86-type1
                    )
                   %base-packages))

 ;; Setup services
 (services (append
            (list
             ; login to temporary hurd-vm via sudo herd start childhurd && ssh root@localhost -p 10022
             (service hurd-vm-service-type
                      (hurd-vm-configuration
                       (disk-size (* 5000 (expt 2 20))) ;5G
                       (memory-size 1024)))             ;1024MiB
             (pam-limits-service
              (list ;; release all max open files limits
               (pam-limits-entry "*" 'hard 'nofile 250000)
               (pam-limits-entry "*" 'soft 'nofile 250000)
               (pam-limits-entry "MYSELF" 'hard 'nofile 250000)
               (pam-limits-entry "MYSELF" 'soft 'nofile 250000)))
             (service gnome-desktop-service-type)
             (dropbear-service (dropbear-configuration
                                (port-number 22)))
             (service mcron-service-type
                      (mcron-configuration
                       (jobs (list cpupower-powersave-job
                                   lift-nofile-limit-job
                                   renice-guix-daemon-job
                                   guix-reconfigure-job
                                   guix-release-throttle-job
                                   arnebab-org-publish-job))))

             ;; TODO: add /usr/bin/env
             ;; (service special-files-service-type
             ;;            `(("/usr/bin/env" ,(file-append (canonical-package coreutils) "/bin/env"))))
             (service cups-service-type
                      (cups-configuration
                       (web-interface? #t)
                       (extensions
                        (list cups-filters hplip))))
             (set-xorg-configuration
              (xorg-configuration ;set keyboard-layout for Xorg
               (keyboard-layout keyboard-layout)))
             (postgresql-service #:extension-packages (list postgis))
             (simple-service 'custom-udev-rules udev-service-type (list sane-backends android-udev-rules)))
            (modify-services %desktop-services
                             (ntp-service-type config =>
                                               (ntp-configuration
                                                (allow-large-adjustment? #t)))
                             (alsa-service-type config => ;disable routing alsa over pulse, because that broke audacity.
                                                (alsa-configuration
                                                 (pulseaudio? #f)))
                             (sysctl-service-type config =>
                                                  (sysctl-configuration
                                                   (settings (append '(("fs.file-max" . "500000")
                                                                       ("fs.inotify.max_user_watches" . "524288"))
                                                                     %default-sysctl-settings)))))))

 ;; Allow resolution of '.local' host names with mDNS.
 (name-service-switch %mdns-host-lookup-nss)

 ;; non-libre kernel + early microcode + wifi firmware
 (kernel linux)
 (initrd microcode-initrd)
 (firmware (cons* iwlwifi-firmware %base-firmware)))
