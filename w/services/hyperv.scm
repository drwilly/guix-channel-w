(define-module (w services hyperv)
  #:use-module (w packages hyperv)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:export (hv-fcopy-daemon-service-type
            hv-kvp-daemon-service-type
            hv-vss-daemon-service-type
            %hyperv-integration-services))

(define %hyperv-integration-services
  '(hv-fcopy-daemon-service-type
    hv-kvp-daemon-service-type
    hv-vss-daemon-service-type))

(define hv-fcopy-daemon-shepherd-service
  (list (shepherd-service
         (provision '(fcopy))
         (documentation "Hyper-V Guest Service Interface.")
         (start #~(make-forkexec-contructor
                   (list (string-append #$hyperv-integration-services "/usr/sbin/hv_fcopy_daemon"
                                        "--no-daemon"))))
         (stop #~(make-kill-destructor)))))

(define hv-fcopy-daemon-service-type
  (service-type
   (name 'fcopy)
   (extensions
    (list (service-extension shepherd-root-service-type
                             hv-fcopy-daemon-shepherd-service)))))

(define hv-kvp-daemon-shepherd-service
  (list (shepherd-service
         (provision '(kvp))
         (documentation "Hyper-V Data-Exchange (Key-Value-Pair) Service.")
         (start #~(make-forkexec-contructor
                   (list (string-append #$hyperv-integration-services "/usr/sbin/hv_kvp_daemon"
                                        "--no-daemon"))))
         (stop #~(make-kill-destructor)))))

(define hv-kvp-daemon-service-type
  (service-type
   (name 'kvp)
   (extensions
    (list (service-extension shepherd-root-service-type
                             hv-kvp-daemon-shepherd-service)))))

(define hv-vss-daemon-shepherd-service
  (list (shepherd-service
         (provision '(vss))
         (documentation "Hyper-V Volume Shadow Copy Requestor.")
         (start #~(make-forkexec-contructor
                   (list (string-append #$hyperv-integration-services "/usr/sbin/hv_vss_daemon"
                                        "--no-daemon"))))
         (stop #~(make-kill-destructor)))))

(define hv-vss-daemon-service-type
  (service-type
   (name 'vss)
   (extensions
    (list (service-extension shepherd-root-service-type
                             hv-vss-daemon-shepherd-service)))))
