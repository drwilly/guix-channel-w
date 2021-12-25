(define-module (w packages neutrinolabs)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages assembly)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages image)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages xorg))

(define-public xrdp
  (package
    (name "xrdp")
    (version "0.9.17")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/neutrinolabs/xrdp/releases/download/"
                    "v" version "/" "xrdp-" version ".tar.gz"))
              (sha256
               (base32
                "0zm7cbi0nhdlbfrisw4ikik00pwhmlq3p5jkg87vc58gdpfi7fan"))))
    (build-system gnu-build-system)
    (arguments
     '(#:configure-flags
       '("--enable-strict-locations"
         "--localstatedir=/var"
         ;; auth backend
         "--enable-pam"
         "--enable-pam-config=unix"
                                        ; "--enable-pamuserpass"
                                        ; "--enable-kerberos"
         ;; neutrinordp
                                        ; "--enable-neutrinordp"
         "--enable-jpeg"
                                        ; "--enable-tjpeg"
         ;; misc
         "--enable-ipv6"
         "--enable-vsock")))
    (native-inputs
     (list pkg-config
           nasm
           xz
           check))
    (inputs
     (list openssl
           pulseaudio
           libx11
           libxfixes
           libxrandr
                                        ; fuse
           libjpeg-turbo
           linux-pam))
    (synopsis "Remote Desktop Protocol server")
    (description "xrdp provides a graphical login to remote machines using Microsoft Remote Desktop Protocol (RDP).")
    (home-page "http://xrdp.org")
    (license license:asl2.0)))

(define-public xorgxrdp
  (package
   (name "xorgxrdp")
   (version "0.2.18")
   (source (origin
            (method url-fetch)
            (uri (string-append
                  "https://github.com/neutrinolabs/xorgxrdp/releases/download/"
                  "v" version "/" "xorgxrdp-" version ".tar.gz"))
            (sha256
             (base32
              "0g6rmrdxh6vpyyk9437qlk8dzll646w5ja3jv2jrg7n3vws8kps5"))))
   (build-system gnu-build-system)
   (arguments
    '(#:configure-flags
      '("--enable-strict-locations"
        "--localstatedir=/var"
        ;; "--enable-glamor"
        )))
   (native-inputs
    (list pkg-config
          nasm
          xdpyinfo))
   (inputs
    (list xrdp
          xorg-server
          libxfont2))
   (synopsis "Xorg drivers for xrdp")
   (description "xorgxrdp is a collection of modules to be used with a pre-existing X.Org install to make the X server to act like X11rdp.")
   (home-page "http://xrdp.org")
   (license license:asl2.0)))
