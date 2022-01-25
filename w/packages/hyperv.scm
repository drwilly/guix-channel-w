(define-module (w packages hyperv)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix utils)
  #:use-module (gnu packages gawk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages python))

(define-public hyperv-integration-services
  (package
    (name "hyperv-integration-services")
    (source linux-libre-source)
    (version linux-libre-version)
    (build-system gnu-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (delete 'configure))
       #:tests? #f
       #:make-flags
       (let* ((out (assoc-ref %outputs "out"))
              (cflags (string-append "-DKVP_SCRIPTS_PATH='\"" out "/libexec/hypervkvpd/\"'")))
         `("-C" "tools/hv/"
           "sbindir=/sbin"
           "libexecdir=/libexec"
           ,(string-append "DESTDIR=" out)
           ,(string-append "CFLAGS=" cflags)))))
    (inputs (list iproute gawk python))
    (synopsis "Hyper-V Integration Services")
    (description "Hyper-V Integration Services allow the virtual machine to communicate with the Hyper-V host.")
    (home-page "https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/reference/integration-services")
    (license license:gpl2)))
