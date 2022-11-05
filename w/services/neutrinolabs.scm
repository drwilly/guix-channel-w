(define-module (w services neutrinolabs)
  #:use-module (w packages neutrinolabs)
  #:use-module (gnu packages xorg)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system pam)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:export (xrdp-configuration
            xrdp-configuration?
            xrdp-service-type))

(define (enum values)
  (lambda (value)
    (unless (memq value values)
      (error "invalid value" value values))
    (symbol->string value)))

(define-record-type* <xrdp-configuration> xrdp-configuration
  make-xrdp-configuration
  xrdp-configuration?
  this-xrdp-configuration
  (xrdp xrdp-configuration-xrdp
        (default xrdp))
  (port xrdp-configuration-port
        (default "3389"))
  (security-layer xrdp-configuration-security-layer
                  (sanitize (enum '(tls rdp negotiate)))
                  (default 'negotiate))
  (crypt-level xrdp-configuration-crypt-level
               (sanitize (enum '(none low medium high)))
               (default 'high))
  (xorg xrdp-configuration-xorg
        (default xorg-server))
  ;; This is an "escape hatch" to provide configuration that isn't yet
  ;; supported by this configuration record.
  (extra-content xrdp-configuration-extra-content
                 (default "")))

(define-syntax ini-file-clause
  (syntax-rules ()
    ((_ config (prop getter))
     (string-append prop "=" (getter config) "\n"))
    ((_ config str)
     (string-append str "\n"))))
(define-syntax-rule (ini-file config file clause ...)
  (plain-file file (string-append (ini-file-clause config clause) ...)))
(define (truefalse x)
  (match x
    (#t "true")
    (#f "false")
    (_ (error "expected #t or #f, instead got:" x))))

(define (xrdp-configuration-file config)
  (ini-file
   config "xrdp.ini"
   "[Globals]"
   "ini_version=1"           ; xrdp.ini file version number
   "fork=true"               ; fork a new process for each incoming connection
   "; ports to listen on, number alone means listen on all interfaces"
   "; 0.0.0.0 or :: if ipv6 is configured"
   "; space between multiple occurrences"
   "; ALL specified interfaces must be UP when xrdp starts, otherwise xrdp will fail to start"
   ";"
   "; Examples:"
   ";   port=3389"
   ";   port=unix://./tmp/xrdp.socket"
   ";   port=tcp://.:3389                           127.0.0.1:3389"
   ";   port=tcp://:3389                            *:3389"
   ";   port=tcp://<any ipv4 format addr>:3389      192.168.1.1:3389"
   ";   port=tcp6://.:3389                          ::1:3389"
   ";   port=tcp6://:3389                           *:3389"
   ";   port=tcp6://{<any ipv6 format addr>}:3389   {FC00:0:0:0:0:0:0:1}:3389"
   ";   port=vsock://<cid>:<port>"
   ("port" xrdp-configuration-port)

   "; 'port' above should be connected to with vsock instead of tcp"
   "; use this only with number alone in port above"
   "; prefer use vsock://<cid>:<port> above"
   "use_vsock=false"

   "; regulate if the listening socket use socket option tcp_nodelay"
   "; no buffering will be performed in the TCP stack"
   "tcp_nodelay=true"

   "; regulate if the listening socket use socket option keepalive"
   "; if the network connection disappear without close messages the connection will be closed"
   "tcp_keepalive=true"

   "; set tcp send/recv buffer (for experts)"
   "#tcp_send_buffer_bytes=32768"
   "#tcp_recv_buffer_bytes=32768"

   ("security_layer" xrdp-configuration-security-layer)

   "; minimum security level allowed for client for classic RDP encryption"
   "; use tls_ciphers to configure TLS encryption"
   ("crypt_level" xrdp-configuration-crypt-level)

   "; X.509 certificate and private key"
   "; openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 365"
   "certificate="
   "key_file="

   "; set SSL protocols"
   "; can be comma separated list of 'SSLv3', 'TLSv1', 'TLSv1.1', 'TLSv1.2', 'TLSv1.3'"
   "ssl_protocols=TLSv1.2, TLSv1.3"
   "; set TLS cipher suites"
   "#tls_ciphers=HIGH"

   "; concats the domain name to the user if set for authentication with the separator"
   "; for example when the server is multi homed with SSSd"
   "#domain_user_separator=@"

   "; The following options will override the keyboard layout settings."
   "; These options are for DEBUG and are not recommended for regular use."
   "#xrdp.override_keyboard_type=0x04"
   "#xrdp.override_keyboard_subtype=0x01"
   "#xrdp.override_keylayout=0x00000409"

   "; Section name to use for automatic login if the client sends username"
   "; and password. If empty, the domain name sent by the client is used."
   "; If empty and no domain name is given, the first suitable section in"
   "; this file will be used."
   "autorun="

   "allow_channels=true"
   "allow_multimon=true"
   "bitmap_cache=true"
   "bitmap_compression=true"
   "bulk_compression=true"
   "#hidelogwindow=true"
   "max_bpp=32"
   "new_cursors=true"
   "; fastpath - can be 'input', 'output', 'both', 'none'"
   "use_fastpath=both"
   "; when true, userid/password *must* be passed on cmd line"
   "#require_credentials=true"
   "; when true, the userid will be used to try to authenticate"
   "#enable_token_login=true"
   "; You can set the PAM error text in a gateway setup (MAX 256 chars)"
   "#pamerrortxt=change your password according to policy at http://url"

   ";"
   "; colors used by windows in RGB format"
   ";"
   "blue=009cb5"
   "grey=dedede"
   "#black=000000"
   "#dark_grey=808080"
   "#blue=08246b"
   "#dark_blue=08246b"
   "#white=ffffff"
   "#red=ff0000"
   "#green=00ff00"
   "#background=626c72"

   ";"
   "; configure login screen"
   ";"

   "; Login Screen Window Title"
   "#ls_title=My Login Title"

   "; top level window background color in RGB format"
   "ls_top_window_bg_color=009cb5"

   "; width and height of login screen"
   ";"
   "; The default height allows for about 5 fields to be comfortably displayed"
   "; above the buttons at the bottom. To display more fields, make <ls_height>"
   "; larger, and also increase <ls_btn_ok_y_pos> and <ls_btn_cancel_y_pos>"
   "; below"
   ";"
   "ls_width=350"
   "ls_height=430"

   "; login screen background color in RGB format"
   "ls_bg_color=dedede"

   "; optional background image filename. BMP format is always supported,"
   "; but other formats will be supported if xrdp is build with imlib2"
   "; The transform can be one of the following:-"
   ";     none  : No transformation. Image is placed in bottom-right corner"
   ";             of the screen."
   ";     scale : Image is scaled to the screen size. The image aspect"
   ";             ratio is not preserved."
   ";     zoom  : Image is scaled to the screen size. The image aspect"
   ";             ratio is preserved by clipping the image."
   "#ls_background_image="
   "#ls_background_transform=none"

   "; logo"
   "; full path to file or file in shared folder. BMP format is always supported,"
   "; but other formats will be supported if xrdp is build with imlib2"
   "; For transform values, see 'ls_background_transform'. The logo width and"
   "; logo height are ignored for a transform of 'none'."
   "ls_logo_filename="
   "#ls_logo_transform=none"
   "#ls_logo_width=240"
   "#ls_logo_height=140"
   "ls_logo_x_pos=55"
   "ls_logo_y_pos=50"

   "; for positioning labels such as username, password etc"
   "ls_label_x_pos=30"
   "ls_label_width=65"

   "; for positioning text and combo boxes next to above labels"
   "ls_input_x_pos=110"
   "ls_input_width=210"

   "; y pos for first label and combo box"
   "ls_input_y_pos=220"

   "; OK button"
   "ls_btn_ok_x_pos=142"
   "ls_btn_ok_y_pos=370"
   "ls_btn_ok_width=85"
   "ls_btn_ok_height=30"

   "; Cancel button"
   "ls_btn_cancel_x_pos=237"
   "ls_btn_cancel_y_pos=370"
   "ls_btn_cancel_width=85"
   "ls_btn_cancel_height=30"

   "[Logging]"
   "; Note: Log levels can be any of: core, error, warning, info, debug, or trace"
   "LogFile=xrdp.log"
   "LogLevel=INFO"
   "EnableSyslog=true"
   "#SyslogLevel=INFO"
   "#EnableConsole=false"
   "#ConsoleLevel=INFO"
   "#EnableProcessId=false"

   "[LoggingPerLogger]"
   "; Note: per logger configuration is only used if xrdp is built with"
   "; --enable-devel-logging"
   "#xrdp.c=INFO"
   "#main()=INFO"

   "[Channels]"
   "; Channel names not listed here will be blocked by XRDP."
   "; You can block any channel by setting its value to false."
   "; IMPORTANT! All channels are not supported in all use"
   "; cases even if you set all values to true."
   "; You can override these settings on each session type"
   "; These settings are only used if allow_channels=true"
   "rdpdr=true"
   "rdpsnd=true"
   "drdynvc=true"
   "cliprdr=true"
   "rail=true"
   "xrdpvr=true"
   "tcutils=true"

   "; for debugging xrdp, in section xrdp1, change port=-1 to this:"
   "#port=/tmp/.xrdp/xrdp_display_10"


   ";"
   "; Session types"
   ";"

   "; Some session types such as Xorg, X11rdp and Xvnc start a display server."
   "; Startup command-line parameters for the display server are configured"
   "; in sesman.ini. See and configure also sesman.ini."
   "[Xorg]"
   "name=Xorg"
   "lib=libxup.so"
   "username=ask"
   "password=ask"
   "ip=127.0.0.1"
   "port=-1"
   "code=20"

   "[Xvnc]"
   "name=Xvnc"
   "lib=libvnc.so"
   "username=ask"
   "password=ask"
   "ip=127.0.0.1"
   "port=-1"
   "#xserverbpp=24"
   "#delay_ms=2000"
   "; Disable requested encodings to support buggy VNC servers"
   "; (1 = ExtendedDesktopSize)"
   "#disabled_encodings_mask=0"
   "; Use this to connect to a chansrv instance created outside of sesman"
   "; (e.g. as part of an x11vnc console session). Replace '0' with the"
   "; display number of the session"
   "#chansrvport=DISPLAY(0)"

   "; Generic VNC Proxy"
   "; Tailor this to specific hosts and VNC instances by specifying an ip"
   "; and port and setting a suitable name."
   "[vnc-any]"
   "name=vnc-any"
   "lib=libvnc.so"
   "ip=ask"
   "port=ask5900"
   "username=na"
   "password=ask"
   "#pamusername=asksame"
   "#pampassword=asksame"
   "#pamsessionmng=127.0.0.1"
   "#delay_ms=2000"

   "; Generic RDP proxy using NeutrinoRDP"
   "; Tailor this to specific hosts by specifying an ip and port and setting"
   "; a suitable name."
   "[neutrinordp-any]"
   "name=neutrinordp-any"
   "; To use this section, you should build xrdp with configure option"
   "; --enable-neutrinordp."
   "lib=libxrdpneutrinordp.so"
   "ip=ask"
   "port=ask3389"
   "username=ask"
   "password=ask"
   "; Uncomment the following lines to enable PAM authentication for proxy"
   "; connections."
   "#pamusername=ask"
   "#pampassword=ask"
   "#pamsessionmng=127.0.0.1"
   "; Currently NeutrinoRDP doesn't support dynamic resizing. Uncomment"
   "; this line if you're using a client which does."
   "#enable_dynamic_resizing=false"
   "; By default, performance settings requested by the RDP client are ignored"
   "; and chosen by NeutrinoRDP. Uncomment this line to allow the user to"
   "; select performance settings in the RDP client."
   "#perf.allow_client_experiencesettings=true"
   "; Override any experience setting by uncommenting one or more of the"
   "; following lines."
   "#perf.wallpaper=false"
   "#perf.font_smoothing=false"
   "#perf.desktop_composition=false"
   "#perf.full_window_drag=false"
   "#perf.menu_anims=false"
   "#perf.themes=false"
   "#perf.cursor_blink=false"
   "; By default NeutrinoRDP supports cursor shadows. If this is giving"
   "; you problems (e.g. cursor is a black rectangle) try disabling cursor"
   "; shadows by uncommenting the following line."
   "#perf.cursor_shadow=false"
   "; By default, NeutrinoRDP uses the keyboard layout of the remote RDP Server."
   "; If you want to tell the remote the keyboard layout of the RDP Client,"
   "; by uncommenting the following line."
   "#neutrinordp.allow_client_keyboardLayout=true"
   "; The following options will override the remote keyboard layout settings."
   "; These options are for DEBUG and are not recommended for regular use."
   "#neutrinordp.override_keyboardLayout_mask=0x0000FFFF"
   "#neutrinordp.override_kbd_type=0x04"
   "#neutrinordp.override_kbd_subtype=0x01"
   "#neutrinordp.override_kbd_fn_keys=12"
   "#neutrinordp.override_kbd_layout=0x00000409"

   "; You can override the common channel settings for each session type"
   "#channel.rdpdr=true"
   "#channel.rdpsnd=true"
   "#channel.drdynvc=true"
   "#channel.cliprdr=true"
   "#channel.rail=true"
   "#channel.xrdpvr=true"))

(define (sesman-configuration-file config)
  (ini-file
   config "sesman.ini"
   "[Globals]"
   "ListenAddress=127.0.0.1"
   "ListenPort=3350"
   "EnableUserWindowManager=true"
   "; Give in relative path to user's home directory"
   "UserWindowManager=startwm.sh"
   "; Give in full path or relative path to /etc/xrdp"
   "DefaultWindowManager=startwm.sh"
   "; Give in full path or relative path to /etc/xrdp"
   "ReconnectScript=reconnectwm.sh"

   "[Security]"
   "AllowRootLogin=true"
   "MaxLoginRetry=4"
   "TerminalServerUsers=tsusers"
   "TerminalServerAdmins=tsadmins"
   "; When AlwaysGroupCheck=false access will be permitted"
   "; if the group TerminalServerUsers is not defined."
   "AlwaysGroupCheck=false"
   "; When RestrictOutboundClipboard=all clipboard from the"
   "; server is not pushed to the client."
   "; In addition, you can control text/file/image transfer restrictions"
   "; respectively. It also accepts comma separated list such as text,file,image."
   "; To keep compatibility, some aliases are also available:"
   ";   true: an alias of all"
   ";   false: an alias of none"
   ";   yes: an alias of all"
   "RestrictOutboundClipboard=none"
   "; When RestrictInboundClipboard=all clipboard from the"
   "; client is not pushed to the server."
   "; In addition, you can control text/file/image transfer restrictions"
   "; respectively. It also accepts comma separated list such as text,file,image."
   "; To keep compatibility, some aliases are also available:"
   ";   true: an alias of all"
   ";   false: an alias of none"
   ";   yes: an alias of all"
   "RestrictInboundClipboard=none"

   "[Sessions]"
   ";; X11DisplayOffset - x11 display number offset"
   "; Type: integer"
   "; Default: 10"
   "X11DisplayOffset=10"

   ";; MaxSessions - maximum number of connections to an xrdp server"
   "; Type: integer"
   "; Default: 0"
   "MaxSessions=50"

   ";; KillDisconnected - kill disconnected sessions"
   "; Type: boolean"
   "; Default: false"
   "; if 1, true, or yes, every session will be killed within DisconnectedTimeLimit"
   "; seconds after the user disconnects"
   "KillDisconnected=false"

   ";; DisconnectedTimeLimit (seconds) - wait before kill disconnected sessions"
   "; Type: integer"
   "; Default: 0"
   "; if KillDisconnected is set to false, this value is ignored"
   "DisconnectedTimeLimit=0"

   ";; IdleTimeLimit (seconds) - wait before disconnect idle sessions"
   "; Type: integer"
   "; Default: 0"
   "; Set to 0 to disable idle disconnection."
   "IdleTimeLimit=0"

   ";; Policy - session allocation policy"
   "; Type: enum [ 'Default' | 'UBD' | 'UBI' | 'UBC' | 'UBDI' | 'UBDC' ]"
   "; 'Default' session per <User,BitPerPixel>"
   "; 'UBD' session per <User,BitPerPixel,DisplaySize>"
   "; 'UBI' session per <User,BitPerPixel,IPAddr>"
   "; 'UBC' session per <User,BitPerPixel,Connection>"
   "; 'UBDI' session per <User,BitPerPixel,DisplaySize,IPAddr>"
   "; 'UBDC' session per <User,BitPerPixel,DisplaySize,Connection>"
   "Policy=Default"

   "[Logging]"
   "; Note: Log levels can be any of: core, error, warning, info, debug, or trace"
   "LogFile=xrdp-sesman.log"
   "LogLevel=INFO"
   "EnableSyslog=true"
   "#SyslogLevel=INFO"
   "#EnableConsole=false"
   "#ConsoleLevel=INFO"
   "#EnableProcessId=false"

   "[LoggingPerLogger]"
   "; Note: per logger configuration is only used if xrdp is built with"
   "; --enable-devel-logging"
   "#sesman.c=INFO"
   "#main()=INFO"

   ";"
   "; Session definitions - startup command-line parameters for each session type"
   ";"

   "[Xorg]"
   "; Specify the path of non-suid Xorg executable. It might differ depending"
   "; on your distribution and version. Find out the appropreate path for your"
   "; environment."
   "param=Xorg"
   "; Leave the rest paramaters as-is unless you understand what will happen."
   "param=-config"
   "param=xrdp/xorg.conf"
   "param=-noreset"
   "param=-nolisten"
   "param=tcp"
   "param=-logfile"
   "param=.xorgxrdp.%s.log"

   "[Xvnc]"
   "param=Xvnc"
   "param=-bs"
   "param=-nolisten"
   "param=tcp"
   "param=-localhost"
   "param=-dpi"
   "param=96"

   "[Chansrv]"
   "; drive redirection"
   "; See sesman.ini(5) for the format of this parameter"
   "#FuseMountName=/run/user/%u/thinclient_drives"
   "#FuseMountName=/media/thinclient_drives/%U/thinclient_drives"
   "FuseMountName=thinclient_drives"
   "; this value allows only the user to acess their own mapped drives."
   "; Make this more permissive (e.g. 022) if required."
   "FileUmask=077"
   "; Can be used to disable FUSE functionality - see sesman.ini(5)"
   "#EnableFuseMount=false"
   "; Uncomment this line only if you are using GNOME 3 versions 3.29.92"
   "; and up, and you wish to cut-paste files between Nautilus and Windows. Do"
   "; not use this setting for GNOME 4, or other file managers"
   "#UseNautilus3FlistFormat=true"

   "[ChansrvLogging]"
   "; Note: one log file is created per display and the LogFile config value "
   "; is ignored. The channel server log file names follow the naming convention: "
   "; xrdp-chansrv.${DISPLAY}.log"
   ";"
   "; Note: Log levels can be any of: core, error, warning, info, debug, or trace"
   "LogLevel=INFO"
   "EnableSyslog=true"
   "#SyslogLevel=INFO"
   "#EnableConsole=false"
   "#ConsoleLevel=INFO"
   "#EnableProcessId=false"

   "[ChansrvLoggingPerLogger]"
   "; Note: per logger configuration is only used if xrdp is built with"
   "; --enable-devel-logging"
   "#chansrv.c=INFO"
   "#main()=INFO"

   "[SessionVariables]"
   "PULSE_SCRIPT=/etc/xrdp/pulse/default.pa"))

(define (xrdp-shepherd-service config)
  (list (shepherd-service
         (documentation "XRDP server.")
         (requirement '(syslogd loopback)) ; seems right
         (provision '(xrdp))
         (start #~(make-forkexec-constructor
                   (list #$(file-append xrdp "/sbin/xrdp")
                         "--nodaemon"
                         "--config" #$(xrdp-configuration-file config))))
         (stop #~(make-kill-destructor)))
        (shepherd-service
         (documentation "XRDP sesman server.")
         (requirement '(xrdp))
         (provision '(xrdp-sesman))
         (start #~(make-forkexec-constructor
                   (list #$(file-append xrdp "/sbin/xrdp-sesman")
                         "--nodaemon"
                         "--config" "/home/w/etc/xrdp/sesman.ini")))
         (stop #~(make-kill-destructor)))))

(define (xrdp-pam-services config)
  "Return a list of <pam-services> for xrdp with CONFIG."
  (list (unix-pam-service
         "xrdp-sesman"
         #:login-uid? #t)))

(define xrdp-service-type
  (service-type (name 'xrdp)
                (description "Run the XRDP server, @command{xrdp}.")
                (extensions
                 (list (service-extension shepherd-root-service-type
                                          xrdp-shepherd-service)
                       (service-extension pam-root-service-type
                                          xrdp-pam-services)
                       ;; (service-extension activation-service-type
                       ;;                    xrdp-activation)
                       ))
                ;; (compose concatenate)
                ;; (extend TODO?)
                (default-value (xrdp-configuration))))

(define (test)
  "Run (test) to run test. :-)"
  ;; (scm->ini
  ;;  (current-output-port))
  (xrdp-configuration-file (xrdp-configuration)))
