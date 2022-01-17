(define-module (w packages dwm-w)
  #:use-module (gnu packages)
  #:use-module (gnu packages suckless)
  #:use-module (guix packages))

(define-public dwm-w
  (package
    (inherit dwm)
    (name "dwm-w")
    (source
     (origin (inherit (package-source dwm))
             (patches (search-patches
                       "dwm-w-0001-botbar.patch"
                       "dwm-w-0002-MODKEY.patch"
                       "dwm-w-0003-X-TERM-LAUNCH.patch"
                       "dwm-w-0004-TAGKEYS.patch"
                       "dwm-w-0005-shiftview.patch"
                       "dwm-w-0006-keys.patch"))))))
