;;; Emacs configuration

;; Emacs package support
;;
;; package-initialize may not be necessary in emacs 27. See
;; https://github.com/emacs-mirror/emacs/blob/emacs-27/etc/NEWS
(when (>= emacs-major-version 23)
  (require 'package)
  (setq package-enable-at-startup nil)
  (setq package-archives
               '(("gnu" . "https://elpa.gnu.org/packages/")
                 ("melpa" . "https://melpa.org/packages/")))
  (package-initialize)

  (unless (package-installed-p 'use-package)
    (package-refresh-contents)
    (package-install 'use-package))
  (eval-when-compile
    (require 'use-package))
  )

;; Report package setup times and record statistics
(setq use-package-verbose t)
(setq use-package-compute-statistics t)


;;; TODO: Try benchmark-init package. https://github.com/dholm/benchmark-init-el
;;; TODO: Other packages to try:
;;;         * artist-mode


;;; Set up font
;;;
;;; In emacs 23, Ubuntu 12.04, emacs no longer respects the settings
;;; in .Xresources.
;;;
;;; Set font to Terminus. Using the TTF version for now. The bolded
;;; doesn't look nice at the small size I prefer, but the xfont
;;; version doesn't have bold (perhaps there's some way to set emacs
;;; to use the bold font version explicitly), and is missing in the
;;; newest Debian packages.
;;;
;;; The xfont version, on Ubuntu 20.04.1 at least, is refered to by
;;; the full name:
;;; Terminus:pixelsize=18:foundry=xos4:weight=normal:slant=normal:width=normal:spacing=110:scalable=fals
;;;
;;; Recently, Debian changed the name of the font from "Terminus" to
;;; "Terminus (TTF)"
(require 'cl-extra)
;;; TODO: Switch this from ignore-error to with-demoted-errors
;;; TODO: Use fontspecs rather than font strings? Maybe?
(cl-some (lambda (font) (ignore-errors
                            (progn (set-frame-font font nil t) t)))
         '("Terminus (TTF)-9" "Terminus-9"))


;;;
;;; Set up path
;;;

;; Add go mode here first, so my local stuff overrides it

(require 'cl)

(setq load-path
 (append
  (remove-if-not 'file-directory-p '("/usr/lib/go/misc/emacs"
                                     "/usr/lib/google-golang/misc/emacs/"))
  load-path)
)

; Backport Emacs23 user-emacs-directory variable to older versions
(unless (boundp 'user-emacs-directory)
  (defvar user-emacs-directory "~/.emacs.d/"
    "Directory beneath which additional per-user Emacs-specific files are placed. Various programs in Emacs store information in this directory. Note that this should end with a directory separator. See also 'locate-user-emacs-file'. [backported]"))


(defvar ajf-site-start-dirs '("site-start.local.d" "site-start.d")
  "List of directories to load init files from.

Load files with names of the form
[0-9][0-9]<foo>.elc? (i.e. the usual naming convention).
Directories are listed in order of preference, so files in
later directories can be hidden with files in earlier
directories.")

;;; Load modularized config

;; Get full paths to directories
(let ((ajf-site-start-paths
       (remove-if-not 'file-directory-p
		      (mapcar
		       (lambda (site-start-dir)
			 (concat user-emacs-directory site-start-dir))
		       ajf-site-start-dirs))
       ))

  (if (fboundp 'debian-run-directories)
      ;; On Debian, there's a function that's already written
      (apply 'debian-run-directories ajf-site-start-paths)

    ;; Otherwise, we roll our own function
    ;;
    ;; This is very procedural. :-(
    (let ((basenames (list))
          (site-start-paths ajf-site-start-paths))
      ;; Build list of (unique) filenamess
      (dolist (site-start-dir site-start-paths)
        (dolist (site-start-file
                 (directory-files
                  site-start-dir nil "^[0-9][0-9].*\\.elc?$" t))
          (let ((basename (file-name-sans-extension site-start-file)))
            (cl-pushnew basename basenames)
            )
          )
        )
      (setq basenames (sort basenames 'string<))
      ;; Add site directories to load path, and then load
      (setq load-path (append site-start-paths load-path))
      (dolist (basename basenames)
        (message "loading %s" basename)
        (load basename nil))
      ;; Remove added items from load-path
      (dolist (site-start-dir site-start-paths)
        (setq load-path (remq site-start-dir load-path))
        )
      )
    )
  )

;; Set up custom load paths
;;
;; First look under ~/.emacs.d/emacs-<version>/site-lisp and children
;; Then look under ~/.emacs.d/site-lisp and children
;; Finally, original load-path
(defconst ajf-config-dir (concat user-emacs-directory
                                 (convert-standard-filename "site-lisp/")))

(mapc (lambda (path-directory)
	(let ((default-directory path-directory))
	  (setq load-path
		(append
		 (let ((load-path (copy-sequence load-path))) ;; Shadow
		   (append
		    (copy-sequence
		     (normal-top-level-add-to-load-path '(".")))
		    (when (file-directory-p default-directory)
                     (normal-top-level-add-subdirs-to-load-path))))
		 load-path)
		)
	  )
	)
      (list ajf-config-dir
	    (concat user-emacs-directory
		    (convert-standard-filename
		     (format "emacs-%d/site-lisp" emacs-major-version))
		    )
	    )
      )

;; (setq load-path (append
;; 		 (list ;ajf-config-dir
;; ;; 		       (concat ajf-config-dir "/color-theme-6.6.0")
;; 		       (concat ajf-config-dir "/cedet/common")
;; ;; 		       (concat ajf-config-dir "/ecb")
;; ;; ;;                                              "~/.elisp/cedet/eieio"
;; ;; ;;                                              "~/.elisp/cedet/semantic"
;; 		       )
;;                  load-path)
;;       )

;; Missing package handling
;;
;; Taken from <http://www.mygooglest.com/fni/dot-emacs.html>

(defvar missing-packages-list nil
  "List of packages that `try-require' can't find.")

;; attempt to load a feature/library, failing silently
(defun try-require (feature)
  "Attempt to load a library or module. Return true if the
library given as argument is successfully loaded. If not, instead
of an error, just add the package to a list of missing packages."
  (condition-case err
      ;; protected form
      (progn
        (message "Checking for library `%s'..." feature)
        (if (stringp feature)
            (load-library feature)
          (require feature))
        (message "Checking for library `%s'... Found" feature))
    ;; error handler
    (file-error  ; condition
     (progn
       (message "Checking for library `%s'... Missing" feature)
       (add-to-list 'missing-packages-list feature 'append))
     nil)))



(use-package auto-package-update
             :ensure t
             :config
             (setq auto-package-update-prompt-before-update t
                   ; Would be nice to delete, but doesn't play well
                   ; when packages were first installed in deb
                   ; packages.
                   ;auto-package-update-delete-old-versions t
                   auto-package-update-interval 4)
             (auto-package-update-maybe)
  )

;; ;;; load cedet
;; ; First we need to load the correct version of cedet libraries overloading
;; ; debian's default
;; ;; (load-library "inversion")
;; ;(unload-feature 'ecb)
;; (unload-feature 'ecb-autoloads)
;; (unload-feature 'cedet)
;; (unload-feature 'inversion)
;; ;(unload-feature 'eieio)
;; (load-library "eieio")   ; can't be reloaded!!!  AAAGGHHH!!!
;; (load-file "~/.elisp/cedet/common/cedet.el")
;; (load-library "semantic")
;; (load-library "semantic-fw")
;; (load-library "senator")
;; (load-library "semantic-decorate-mode")
;; (load-library "semantic-ia")
;; ;(semantic-load-enable-minimum-features)

;; ;;
;; ;; Color themes
;; ;;
(if (>= emacs-major-version 24)
    (progn (message "Need to upgrade to deftheme/color-theme-modern")
           ;; Themes I like:
           ;;   deeper-blue
           ;;   tango-dark
           ;;   misterioso
           ;;   doom-sourcerer
           ;; Need to install color-theme-modern and try to set up those
           ;; themes. See load-theme function and custom-safe-themes variable.
           ;;
           ;; Other themes:
           ;;   nord (Ugly buttons in customize buffers)
           ;;   modus-vivendi
           ;;     https://gitlab.com/protesilaos/modus-themes
           ;;   sanityinc-tomorrow-eighties, sanityinc-tomorrow-night
           ;;     https://github.com/purcell/color-theme-sanityinc-tomorrow
           ;;   darktooth
           ;;     https://github.com/emacsfodder/emacs-theme-darktooth
           ;;   ample-flat
           ;;     https://github.com/jordonbiondo/ample-theme
           ;;   sanityinc-tomorrow-eighties
           ;;     https://github.com/purcell/color-theme-sanityinc-tomorrow
           ;;   afternoon-theme
           ;;     https://github.com/osener/emacs-afternoon-theme
           ;;   doom-material, doom-nord, doom-opera, doom-sourcerer
           ;;     https://github.com/hlissner/emacs-doom-themes/tree/screenshots
           ;;   odersky
           ;;     https://github.com/owainlewis/emacs-color-themes
           ;;   material
           ;;     https://melpa.org/#/material-theme
           (load-theme 'deeper-blue))
    (progn
      (message "Setting up color theme")
      (when (try-require 'color-theme)
        (eval-after-load "color-theme"
          '(progn
             (color-theme-initialize)
             )
          )
        ;; (require 'color-theme-autoloads "color-theme-autoloads")
        (when (require 'color-theme-hober2 "color-theme-hober2" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-hober2 "Hober2"
                                            "Edward O'Connor <ted@oconnor.cx>")
                       )
          )
        (when (require 'color-theme-inkpot "color-theme-inkpot" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-inkpot "Inkpot" "From EmacsWiki")
                       )
          )
        (when (require 'color-theme-tango "color-theme-tango" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-tango "Tango" "danranx@gmail.com")
                       )
          )
        (when (require 'color-theme-blackboard "color-theme-blackboard" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-blackboard "Blackboard" "jdhuntington@gmail.com")
                       )
          )
        ;; ;; Something in zenburn changes the foreground color of the buffer
        ;; ;; name in the mode-line when loaded, even if not the current
        ;; ;; color-theme
        ;; (require 'zenburn "zenburn")
        ;; (add-to-list 'color-themes
        ;; 	     '(zenburn "Zenburn" "Daniel Brockman <daniel@brockman.se>")
        ;; 	     )
        (when (require 'color-theme-desert "color-theme-desert" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-desert
                         "Desert"
                         "Sergei Lebedev <superbobry@gmail.com>")
                       )
          )
        (when (require 'color-theme-twilight "color-theme-twilight" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-twilight
                         "Twilight"
                         "Marcus Crafter <crafterm@redartisan.com>")
                       )
          )
        (when (require 'color-theme-monokai "monokai-theme" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-monokai
                         "Monokai"
                         "Operator <rectifier04@gmail.com>")
                       )
          )
        (when (require 'color-theme-molokai "color-theme-molokai" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-molokai
                         "Molokai"
                         "Adam Lloyd <adam@alloy-d.net>")
                       )
          )
        (when (require 'color-theme-anothermonokai "anothermonokai" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-anothermonokai
                         "AnotherMonokai"
                         "https://github.com/stafu/AnotherMonokai")
                       )
          )
        (when (require 'color-theme-billc "color-theme-billc" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-billc
                         "BillC"
                         "Bill Clementson <billclem@gmail.com>")
                       )
          )
        (when (require 'color-theme-tangotango "color-theme-tangotango" 'noerror)
          (add-to-list 'color-themes
                       '(color-theme-tangotango
                         "TangoTango"
                         "Julian Barnier <julien@nozav.org")
                       )
          )
        ;; My current prefered color theme
					;(color-theme-desert)
        (color-theme-tango)
        )
      )
    )

;;; Doom modeline

(defun ajf-font-family-available-p (font-family)
  (find-font (font-spec :family font-family)))

(defun ajf--all-the-icons-font-installed-p (family-name)
  (when (functionp 'all-the-icons--family-name)
    (ajf-font-family-available-p
     (funcall (all-the-icons--family-name family-name))
     )
    )
  )

(defun ajf--all-the-icons-installed-p ()
  (when (functionp 'all-the-icons--family-name)
    (every #'ajf--all-the-icons-font-installed-p
           all-the-icons-font-families)))

(use-package all-the-icons
  :config
  (unless (ajf--all-the-icons-installed-p)
    (when (y-or-n-p "Install fonts for all-the-icons? ")
      (all-the-icons-install-fonts))))

(use-package nerd-icons
  :config
  (unless (ajf-font-family-available-p nerd-icons-font-family)
    (when (y-or-n-p "Install font nerd-icons? ")
      (nerd-icons-install-fonts)))
  )

(defun ajf-nerd-icons-setup-p ()
  (and (boundp 'nerd-icons-font-family)
       (ajf-font-family-available-p nerd-icons-font-family))
  )


(use-package doom-modeline
  :after nerd-icons
  :if (or (ajf-nerd-icons-setup-p)
          (not (message "Not loading doom-modeline because the nerd-icon font is not installed")))
  :config (doom-modeline-mode))


;;; Quiet startup

;; Shut off startup message
(setq inhibit-startup-message t)

;; Leave the scratch buffer empty
(setq initial-scratch-message nil)

;; Shortcut to kill current buffer
(global-set-key (kbd "C-x K") 'kill-current-buffer)


;;;
;;; Define frame title
;;;
;(setq frame-title-format '(buffer-file-name "%f" ("%b")))
;; Put buffer name, status, and filename in frame (window) title
;; (setq frame-title-format '("%b %*%* "
;;                            (buffer-file-name
;;                             ("[" buffer-file-name "]")
;;                             )
;;                            )
;;       )
;; ; Try 2: Add emacs process number (doesn't work)
;; (setq frame-title-format '(buffer-file-name
;;                            (format "%%b %%*%%* (%f) [%d]" (emacs-pid))
;;                            ((format "%%b %%*%%* [%d]" (emacs-pid)))))
;; ; Try 3: Try just the process id
;; (setq frame-title-format (format "%%b %%*%%* [%d]" (emacs-pid)))
; Random try
;(setq frame-title-format "%*%b ")
;; (setq icon-title-format frame-title-format)

;; On OSX, get path from shell, not default.
;; https://melpa.org/#/exec-path-from-shell
;; https://github.com/purcell/exec-path-from-shell
;;
;; TODO: Reorder shell config files to not require interactive loading
;; to set PATH. (See https://github.com/purcell/exec-path-from-shell)
(message "windows-system == %s" window-system)
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns))
  :config (exec-path-from-shell-initialize))


(when (try-require 'projectile)
  (projectile-global-mode)
  (setq projectile-enable-caching t)
  (if (< emacs-major-version 24)
  ; Backport remote-file-name-inhibit-cache from files.el in Emacs 24
  ; http://lists.gnu.org/archive/html/emacs-diffs/2010-10/msg00035.html
      (defcustom remote-file-name-inhibit-cache 10
        "Whether to use the remote file-name cache for read access.

When `nil', always use the cached values.
When `t', never use them.
A number means use them for that amount of seconds since they were
cached.

File attributes of remote files are cached for better performance.
If they are changed out of Emacs' control, the cached values
become invalid, and must be invalidated.

In case a remote file is checked regularly, it might be
reasonable to let-bind this variable to a value less then the
time period between two checks.
Example:

  \(defun display-time-file-nonempty-p \(file)
    \(let \(\(remote-file-name-inhibit-cache \(- display-time-interval 5)))
      \(and \(file-exists-p file)
           \(< 0 \(nth 7 \(file-attributes \(file-chase-links file)))))))"
        :group 'files
        :version "24.1"
        :type `(choice
                (const   :tag "Do not inhibit file name cache" nil)
                (const   :tag "Do not use file name cache" t)
                (integer :tag "Do not use file name cache"
                         :format "Do not use file name cache older then %v seconds"
                         :value 10)))
    )
)

(require 'uniquify)
(setq uniquify-buffer-name-style 'post-forward)
;; from <http://trey-jackson.blogspot.com/2008/01/emacs-tip-11-uniquify.html>
;(setq uniquify-ignore-buffers-re "^\\*") ; don't muck with special buffers

;; Always show buffer name, even if there's only one frame
(setq frame-title-format "%b")


;;; Functions to easily set frame/window width
;;;
;;; from <http://dse.livejournal.com/67732.html>
(defun fix-frame-width (width)
  "Set the frame's width to 80 (or prefix arg WIDTH) columns wide."
  (interactive "P")
  (if window-system
      (set-frame-width (selected-frame) (or width 80))
    (error "Cannot resize frame width of text terminal")))
(defun fix-window-width (width)
  "Set the window's width to 80 (or prefix arg WIDTH) columns wide."
  (interactive "P")
  (enlarge-window (- (or width 80) (window-width)) 'horizontal))
(defun fix-width (width)
  "Set the window's or frame's with to 80 (or prefix arg WIDTH)."
  (interactive "P")
  (condition-case nil
      (fix-window-width width)
    (error
     (condition-case nil
         (fix-frame-width width)
       (error
        (error "Cannot resize window or frame horizontally"))))))


;; ;; Text zooming
;; ;; taken from <http://emacs-fu.blogspot.com/2008/12/zooming-inout.html>
;; (defun text-zoom (n)
;;   "with positive n, increase the font size, otherwise decrease it"
;;   (set-face-attribute 'default (selected-frame) :height
;; 		      (+ (face-attribute 'default :height)
;; 			 (* (if (> n 0) 1 -1) 10))))
;; ; Should I change the interactive code to prompt for a size?
;; (defun text-zoom-in (n)
;;   "increase font size"
;;   (interactive "P")
;;   (text-zoom (or n 1)))
;; (defun text-zoom-out (n)
;;   "decrease font size"
;;   (interactive "P")
;;   (text-zoom (- 0 (or n 1))))

;;; zoom-frm
;;;
;;; https://www.emacswiki.org/emacs/zoom-frm.el
;;;
;;; TODO: Update to newest version of zoom-frm.
(use-package zoom-frm
  ;; autoloads annotated in zoom-frm.el
  ;;
  ;; There's probably a better/cleaner way to do this, but zoom-frm is
  ;; from emacswiki.org not a package archive.
  ;;
  ;; TODO: Clean this up. This list was taken from commands marked
  ;; autoload in the newest version of zoom-frm.el, but I'm still
  ;; including the old version in my repo. And not all the commands
  ;; that can be autoloaded are marked as such. (See comments in
  ;; newest zoom-frm.el.). To be honest, these might be unnecesary
  ;; because the decorations might be enough. (But I think autoloads
  ;; only get registered via the package mechanics, and I'm not
  ;; install zoom-frm as a package, just as a file in the load-path.)
  :commands (toggle-zoom-frame
             zoom-all-frames-in
             zoom-all-frames-out
             zoom-frm-in
             zoom-frm-out
             zoom-frm-unzoom
             zoom-in
             zoom-out
             zoom-in/out
             )
  :init
  ; TODO: Try moving to :map
  (define-key ctl-x-map [(control ?+)] 'zoom-in/out)
  (define-key ctl-x-map [(control ?-)] 'zoom-in/out)
  (define-key ctl-x-map [(control ?=)] 'zoom-in/out)
  (define-key ctl-x-map [(control ?0)] 'zoom-in/out)
  ; TODO: Try moving to :bind
  (global-set-key (if (boundp 'mouse-wheel-down-event)
                      (vector (list 'control mouse-wheel-down-event))
                    [C-mouse-wheel])   ; Emacs 20, 21
                  'zoom-in)
  (global-set-key (if (boundp 'mouse-wheel-down-event)
                      (vector (list 'control 'meta mouse-wheel-down-event))
                    [C-M-mouse-wheel])   ; Emacs 20, 21
                  'zoom-all-frames-in)
  (when (boundp 'mouse-wheel-up-event)
    (global-set-key (vector (list 'control mouse-wheel-up-event))
                    'zoom-out)
    (global-set-key (vector (list 'control 'meta mouse-wheel-up-event))
                    'zoom-all-frames-out))
;; (global-set-key [S-mouse-1]    'zoom-frm-in)
;; (global-set-key [C-S-mouse-1]  'zoom-frm-out)
;; ;; Get rid of `mouse-set-font' or `mouse-appearance-menu'
;; (global-set-key [S-down-mouse-1] nil)
)

(use-package windmove
  :config
  ;; The default keybindings use shift as a modifier, but shift-arrow is
  ;; currently used to select-and-move. That command can also be done by C-space
  ;; <arrow>, so maybe I should stick with the default shift-arrow for windmove.
  (windmove-default-keybindings 'meta)
  (setq windmove-wrap-around t))

;;; Set up emacs-server
(server-start)
(add-hook 'server-switch-hook
          (lambda nil
            (let ((server-buf (current-buffer)))
              (bury-buffer)
              (switch-to-buffer-other-frame server-buf))))


;; Don't store duplicates in kill ring
(setq kill-do-not-save-duplicates t)

;;; Use C-w to delete previous word, unless a region is selected
(defun backward-kill-word-or-kill-region (&optional arg)
  (interactive "p")
  (if (region-active-p)
      (kill-region (region-beginning) (region-end))
    (backward-kill-word arg)))

(global-set-key (kbd "C-w") 'backward-kill-word-or-kill-region)

;;; Use C-c r to revert an unchanged buffer
;;; See https://www.emacswiki.org/emacs/RevertBuffer#toc1 for versions
;;; that allow reverting of buffers even if modified.
(global-set-key (kbd "C-c r")
                (lambda ()
                  (interactive)
                  (if (not (buffer-modified-p))
                      (progn (revert-buffer :ignore-auto :noconfirm)
                             (message "Reverted buffer"))
                    (error "The buffer has been modified"))
                  )
                )


(use-package revert-buffer-all
  :commands revert-buffer-all)


;;;;; SKIPPING Pymacs

;; ido Mode
; Check help for ido-find-file function for tips on how to use
(ido-mode)
(setq ido-enable-flex-matching t)
;; ido-everywhere allows ido completion in vc-git-grep, but at the
;; cost of overriding the file open gui. I rarely use the latter
;; though. https://emacs.stackexchange.com/a/45447 (Maybe try
;; ido-completing-read-plus or, instead of ido, ivy or helm.)
;; (Also consider ido's vertical and grid modes.)
(setq ido-everywhere t)
(setq ido-default-file-method 'selected-window)
(setq ido-default-buffer-method 'selected-window)

;; icomplete Mode
(icomplete-mode 99)

;;; recentf
;;;
;;; Configuration taken from
;;; https://www.masteringemacs.org/article/find-files-faster-recent-files-package
(require 'recentf)
;; There might be an ivy-recentf or counsel-recentf instead?
;; https://github.com/abo-abo/swiper/issues/624
(global-set-key (kbd "C-x C-r") 'ido-recentf-open)
(recentf-mode t)
(setq recentf-max-saved-items 50)
(defun ido-recentf-open ()
  "Use `ido-completing-read' to \\[find-file] a recent file"
  (interactive)
  (if (find-file (ido-completing-read "Find recent file: " recentf-list))
      (message "Opening file...")
    (message "Aborting")))

;;; ivy
(use-package ivy
             ;; :diminish or :delight? Both? Neither seem to be
             ;; installed, but yet ivy is not shown in the list of
             ;; minor-modes presented by doom-modeline.
             :diminish ivy-mode
             :config
             (ivy-mode)

             ;; Make ivy play well with icomplete
             ;; https://github.com/abo-abo/swiper/issues/1287
             (defun ivy-complete (f &rest r)
               (icomplete-mode -1)
               (unwind-protect
                   (apply f r)
                 (icomplete-mode 99)))
             (advice-add 'ivy-read :around #'ivy-complete)
)

;;; Swiper
(use-package swiper
             :after ivy
             :bind (("C-s" . swiper-isearch)
                    ("C-r" . swiper-isearch-backward)
                    :map swiper-map
                    ("C-r" . ivy-previous-line-or-history)))



;; If available, use counsel-yank-pop.
;;
;; Ideally it would have thse properties:
;;   1. Show selected yank text in buffer, like browse-kill-ring
;;      does.
;;   2. Mark the difference between selections in the list. With
;;      multi-line snippets, it's hard to know where the snippets
;;      end before selecting. It does look like there is an option
;;      for that, but I fear it will take up too much room.
;;
;; Also, try the configuration from
;; http://pragmaticemacs.com/emacs/counsel-yank-pop-with-a-tweak/
;; to set up ivy-next-line. Need to switch to use-package first.
;; (And it looks like it remaps M-y to ivy-next-line in every ivy
;; completion minibuffer.)
(use-package counsel
             :after ivy
             :bind
             ;; There are other useful commands in the key bindings suggested in
             ;; the docs, but the non-counsel versions aren't currently bound to
             ;; keys, and I can't think of good key bindings at the
             ;; moment. Examples:
             ;;   counsel-set-variable
             ;;     shows description of variable
             ;;   counsel-load-theme
             ;;     disables all current themes before loading the
             ;;     selected theme
             ;; See https://oremacs.com/swiper/#global-key-bindings
             ;;
             ;; TODO: These bindings should not be set here. By doing
             ;; so, if ivy is installed, and counsel is not, these
             ;; bindings break from the default. (Makes sense, but not
             ;; ideal when setting up a new machine.) Instead, they
             ;; should be set up in a config after loading, or some
             ;; other more complicated conditional logic that checks
             ;; if it can be loaded each time: if not, run the
             ;; default; if so, run counsel version and drop the check
             ;; in the future.
             (("M-y" . counsel-yank-pop)
              ("C-x b" . counsel-switch-buffer)
              ("M-x" . counsel-M-x)
              ("C-h f" . counsel-describe-function)
              ("C-h v" . counsel-describe-variable)))

;; If counsel is not available, try browse-kill-ring.
;;
;; (This only works if the feature isn't installed, not if the feature
;; doesn't load. I'm not sure if there's a way to check for that.
(use-package browse-kill-ring
             :unless (package-installed-p 'counsel)
             :config (browse-kill-ring-default-keybindings))


;;; Amx
(use-package amx
             :config (amx-mode))


;;; ivy-rich
(use-package ivy-rich
  :after ivy
  :config
  (ivy-rich-mode 1)
  (setcdr (assq t ivy-format-functions-alist) #'ivy-format-function-line)
  )


;;; nerd-icons-ivy-rich
;;;
;;; Although nerd-icons-ivy-rich-mode depends on ivy-rich, for
;;; performance it should be enabled before ivy-rich-mode. I don't
;;; understand exactly why.
;;; https://github.com/seagle0128/nerd-icons-ivy-rich
;;; This does not do that though, to keep the dependency logic simple
;;; and explicit.
(use-package nerd-icons-ivy-rich
  :after (nerd-icons ivy-rich)
  :if (or (ajf-nerd-icons-setup-p)
          (not (message "Not loading nerd-icons-ivy-rich because the nerd-icon font is not installed")))
  :config
  (nerd-icons-ivy-rich-mode 1)
  )


;;; Which Key
;;;
;;; TODO: Bind `which-key-show-top-level' and/or `which-key-show-major-mode' (and/or
;;; `discover-my-major') to a key, perhaps C-h C-M (aka C-h RET))
;;
;; TODO: Try to write a which-key-sort-order function that groups but
;; ignores modifier. Something like: a A C-a M-a C-M-a ... b B C-b M-b
(use-package which-key
             :diminish which-key-mode
             :config
             (which-key-mode)
             (which-key-setup-side-window-right-bottom))


;;; ivy-xref
;;; https://github.com/alexmurray/ivy-xref
(use-package ivy-xref
             :after ivy
             :config
             ;; xref initialization is different in Emacs 27
             ;; - there are two different variables which can
             ;; be set rather than just one
             (when (>= emacs-major-version 27)
               (setq xref-show-definitions-function #'ivy-xref-show-defs))
             ;; Necessary in Emacs <27. In Emacs 27 it will affect all xref-based
             ;; commands other than xref-find-definitions
             ;; (e.g. project-find-regexp) as well
             (setq xref-show-xrefs-function #'ivy-xref-show-xrefs)
             )


(use-package re-builder
  :config
  ;; Run query-replace-regexp from re-builder.
  ;; From: https://www.emacswiki.org/emacs/ReBuilder
  ;;       https://emacs.stackexchange.com/a/899
  (defun reb-query-replace (to-string)
    "Replace current RE from point with `query-replace-regexp'."
    (interactive
     (progn (barf-if-buffer-read-only)
            (list (query-replace-read-to (reb-target-binding reb-regexp)
                                         "Query replace" t))))
    (with-current-buffer reb-target-buffer
      (query-replace-regexp (reb-target-binding reb-regexp) to-string)))
  )


;;;;; SKIPPING longlines

; Show column numbers
(line-number-mode t)
(column-number-mode t)

; linum -- Shows line numbers for each buffer line
; activate with M-x linum-mode
; doesn't play nice with my fix-window-width
(try-require 'linum)

; Don't use tab characters
(setq-default indent-tabs-mode nil)


;; Use one space after periods when rewrapping paragraphs. (I switched my style
;; years ago. I don't know if is the best idea, but I've given in to
;; convention.)
(setq sentence-end-double-space nil)


;; Use goto-address-mode for urls
(use-package goto-address-mode
  :hook
  (text-mode . goto-address-mode)
  (prog-mode . goto-address-mode)

  ;; Should I be using customize-set-variable or use-package's :custom? setq is
  ;; faster.
  :init
  (setq goto-address-url-face 'underline)
  ;(customize-set-variable 'goto-address-url-face 'underline)
  )


;; Clean up unused buffers at 4 AM
(use-package midnight
             :config (midnight-delay-set 'midnight-delay "4:00am"))

;; Colors
(global-font-lock-mode t)

(transient-mark-mode t)
(when (>= emacs-major-version 24)
  (electric-pair-mode 1)
  ;; If multiple lines, don't put trailing parentheses on separate line.
  ;; Ideally this would depend on the pairing (so braces get their own line)
  ;; and perhaps mode, but that's beyond my emacs-foo for now.
  (setq electric-pair-open-newline-between-pairs nil)
  )


;; Better searching with ack
(autoload 'ack-and-a-half-same "ack-and-a-half" nil t)
(autoload 'ack-and-a-half "ack-and-a-half" nil t)
(autoload 'ack-and-a-half-find-file-same "ack-and-a-half" nil t)
(autoload 'ack-and-a-half-find-file "ack-and-a-half" nil t)
(defalias 'ack 'ack-and-a-half)
(defalias 'ack-same 'ack-and-a-half-same)
(defalias 'ack-find-file 'ack-and-a-half-find-file)
(defalias 'ack-find-file-same 'ack-and-a-half-find-file-same)
(setq ack-and-a-half-arguments '("--nopager"))


;;; Deadgrep
;;
;; Need to hack to get it to accept custom args, in particular for an ignore
;; file in a nonstandard location.
(defvar ripgrep-ignore-path
  ;; Default from RIPGREP_CONFIG_PATH variable
  ;;
  ;; I store an ignore file for ripgrep in the same directory as the ripgrep
  ;; conf file.
  (let ((ripgrep-config-path (getenv "RIPGREP_CONFIG_PATH")))
    (if ripgrep-config-path
        (format "%s/../ignore" ripgrep-config-path))
    )
  )

(use-package deadgrep
  :config
  (advice-add 'deadgrep--arguments :filter-return
              (lambda (args)
                (if ripgrep-ignore-path
                    (push (format "--ignore-file=%s" ripgrep-ignore-path)
                          args))))
  )


(use-package fzf
  ;; TODO: Configure to not use entire monorepo at work for the
  ;; default directory. It might be better done by customize
  ;; projectile.
  )


;; ;; Strip trailing whitespace when saving certain filetypes
;; ;; Using whitespace mode from
;; ;; <http://www.splode.com/~friedman/software/emacs-lisp/src/whitespace.el>
;; ; use require, so I can append python mode always-nuke list
;; ;(autoload 'nuke-trailing-whitespace "whitespace" nil t)
;; (require 'whitespace)
;; ;; (add-to-list 'nuke-trailing-whitespace-always-major-modes
;; ;;              'python-mode)
;; (setq nuke-trailing-whitespace-always-major-modes
;;       (delete 'c++-mode nuke-trailing-whitespace-always-major-modes))
;; (add-hook 'mail-send-hook 'nuke-trailing-whitespace)
;; (add-hook 'write-file-hooks 'nuke-trailing-whitespace)
;; ;; Should make this a toggle function instead (what about third option)...
;; (defun off-nuke-trailing-whitespace ()
;;   (interactive)
;;   (setq nuke-trailing-whitespace-p nil))

;; Use ws-butler to delete whitespace only on modified lines
;; https://github.com/lewang/ws-butler
(use-package ws-butler
             :config
             (setq ws-butler-keep-whitespace-before-point nil)
             (ws-butler-global-mode)
             )

;;; Make files that begin with shebang lines executable
(add-hook 'after-save-hook
          'executable-make-buffer-file-executable-if-script-p)


;; Function to highlight lines longer that run over 80 columns
(defun show-overlong-lines ()
  (interactive)
  (font-lock-add-keywords
   nil
   '(("^[^\n]\\{80\\}\\(.*\\)$" 1 font-lock-warning-face t))))

;; Highlight matching parentheses
(show-paren-mode t)
;; From <http://www.emacswiki.org/emacs/ShowParenMode>
;; <https://web.archive.org/web/20170708083009/https://www.emacswiki.org/emacs/ShowParenMode>
(defadvice show-paren-function (after show-matching-paren-offscreen activate)
  "If the matching paren is offscreen, show the matching line in the echo area.  Has no effect if the character before point is not of the syntax class ')'."
  (interactive)
  ;; Only call `blink-matching-open' if the character before point
  ;; is a close parentheses type character.  Otherwise, there's not
  ;; really any point, and `blink-matching-open' would just echo
  ;; "Mismatched parentheses", which gets really annoying.
  (let ((cb (char-before (point))))
          (if (and cb
                   (char-equal (char-syntax cb) ?\) ))
              (blink-matching-open))
    )
  )


;;; idle-highlight-mode
;;;
;;; Updated version of old idle-highlight-mode
;;; https://gitlab.com/ideasman42/emacs-idle-highlight-mode
;;; https://www.reddit.com/r/emacs/comments/pweeeb/ann_idlehighlightmode_fast_symbolatpoint/
;;;
;;; ":if (locate-library ...)" is to handle idle-highlight not being installed.
;;; (https://github.com/jwiegley/use-package/issues/591). A better way would be
;;; to have some sort of hook wrapper that doesn't return failure if the
;;; library fails to load.
(use-package idle-highlight-mode
  :if (locate-library "idle-highlight-mode")
  :hook prog-mode)


;;; Delete softtabs
(defun backward-delete-whitespace-to-column ()
  "delete back to the previous column of whitespace, or just one
   char if that's not possible. This emulates vim's softtabs
   feature."
  (interactive)
  (if indent-tabs-mode
      (call-interactively 'backward-delete-char-untabify)
    ;; let's get to work
    (let ((movement (% (current-column) tab-width))
          (p (point)))
      ;; brain freeze, should be easier to calculate goal
      (when (= movement 0) (setq movement tab-width))
      (if (save-excursion
            (backward-char movement)
            (string-match "^\\s-+$" (buffer-substring-no-properties (point) p)))
          (delete-region (- p movement) p)
        (call-interactively 'backward-delete-char-untabify)))))

(global-set-key (kbd "<DEL>") 'backward-delete-whitespace-to-column)


;; Glasses mode settings
(setq glasses-separate-parentheses-p nil)
;(setq glasses-separator "")
;(setq glasses-face 'bold)
(setq glasses-original-separator "") ; keep originally underscored
                                     ; stuff underscored
(setq glasses-separator "_")
(setq glasses-face 'italic)


;; ediff settings
(use-package ediff
  :config
  ; Don't put help/command buffer in a separate frame.
  (setq ediff-window-setup-function #'ediff-setup-windows-plain)
  (setq ediff-split-window-function
        (lambda (&optional arg)
          (if (> (frame-width) 140)
              (split-window-horizontally arg)
            (split-window-vertically arg))))

  ;; ediff hooks to restore original window layout
  ;; https://emacs.stackexchange.com/questions/7482/restoring-windows-and-layout-after-an-ediff-session
  (defvar ajf-ediff-last-windows nil)
  (defun ajf-store-pre-ediff-winconfig ()
    (setq ajf-ediff-last-windows (current-window-configuration)))
  (defun ajf-restore-pre-ediff-winconfig ()
    (set-window-configuration ajf-ediff-last-windows))
  (add-hook 'ediff-before-setup-hook #'ajf-store-pre-ediff-winconfig)
  (add-hook 'ediff-quit-hook #'ajf-restore-pre-ediff-winconfig)

  ;; Use git diff on windows, simply because it's likely to be there.
  (when (eq (window-system) 'w32)
    (let ((git-bin-dir
           (file-name-as-directory "C:\\Program Files\\Git\\usr\\bin")))
      (when (file-directory-p git-bin-dir)
        (setq ediff-cmp-program (concat git-bin-dir "cmp.exe"))
        (setq ediff-diff-program (concat git-bin-dir "diff.exe"))
        (setq ediff-diff3-program (concat git-bin-dir "diff3.exe"))
        )
      )
    )
  )


;; Automatic smerge mode
(use-package smerge-mode
             :init (defun sm-try-smerge ()
                     (save-excursion
                       (goto-char (point-min))
                       (when (re-search-forward "^<<<<<<< " nil t)
                         (smerge-mode 1))))
             (add-hook 'find-file-hook 'sm-try-smerge t)
             :custom-face
             (smerge-base ((t (:extend t :background "#505000"))))
             (smerge-lower ((t (:extend t :background "#224422"))))
             (smerge-refined-added ((t (:inherit smerge-refined-change :background "#335533"))))
)


;; Imenu-list
(use-package imenu-list
  :commands (imenu-list-minor-mode imenu-smart-list-toggle)
  :config
  (setq imenu-list-focus-after-activation t)
  )


;; ibuffer nerd icons
(use-package nerd-icons-ibuffer
  :after nerd-icons
  :if (or (ajf-nerd-icons-setup-p)
          (not (message "Not loading nerd-icons-ibuffer because the nerd-icon font is not installed")))
  :hook (ibuffer-mode . nerd-icons-ibuffer-mode)
  )


;; Flycheck
(use-package flycheck
             :config (global-flycheck-mode)
             (setq flycheck-idle-change-delay 4))


;; flyspell
(add-hook 'prog-mode-hook 'flyspell-prog-mode)
(add-hook 'text-mode-hook 'flyspell-mode)

(use-package flyspell-correct
  :after flyspell
  :bind (:map flyspell-mode-map ("C-;" . flyspell-correct-wrapper)))

(use-package flyspell-correct-ivy
  :after (flyspell-correct ivy))

;; Put a2ps in the File menu
;;
;; Need to use `load` and not `require` or `use-package` because a2ps
;; doesn't "provide" a2ps-print.
;;
;; TODO: Debian installs a2ps-print.el in /usr/share/emacs/site-lisp/a2ps
;; but that is not in the load-path.
(if (load "a2ps-print" 'noerror)
    (progn (setq a2ps-switches '("-C"))
             ;; TODO: Ubuntu/Debian puts this in the menu already...
             ;; Need to check the load-history variable to see if it's
             ;; already been loaded, or can check the menu.
             (easy-menu-add-item nil
                                 '("file") ["a2ps Buffer" a2ps-buffer "--"]
                                 "separator-window"))
  (message "Unable to load a2ps-print")
  )


;; ;; ;; dsvn is supposedly faster than psvn for large trees, but it has
;; ;; ;; less features
;; ;; (autoload 'svn-status "dsvn" nil t)
;; ;; (require 'dsvn)
;; (require 'psvn)

;; ;; Set colors for diffs
;; ; Need to set some other faces as well eventually...
;; (custom-set-faces
;;  '(diff-added ((t (:foreground "MediumSeaGreen"))) 'now)
;;  '(diff-removed ((t (:foreground "firebrick"))) 'now)
;;  '(diff-function-face ((t (:foreground "MediumOrchid"))) 'now)
;; )

;; (setq vc-svn-diff-switches "--extensions=-up")

;; ;;;;; SKIPPING CEDET
;; (load-file (concat ajf-config-dir "/cedet/common/cedet.el"))
;; (semantic-load-enable-code-helpers)

;; emacs code browser
(when (try-require 'semantic/analyze)
  (provide 'semantic-analyze)
  (provide 'semantic-ctxt)
  (provide 'semanticdb)
  (provide 'semanticdb-find)
  (provide 'semanticdb-mode)
  (provide 'semantic-load)
)

;; stickyfunc-enhance
;; https://github.com/tuhdo/semantic-stickyfunc-enhance
(when (try-require 'stickyfunc-enhance)
  (add-to-list 'semantic-default-submodes 'global-semantic-stickyfunc-mode))

;(add-to-list 'load-path "~/ecb-2.40")
;(require 'ecb)
;; need to activate semantic mode first...
(require 'ecb-autoloads nil 'noerror)

;; soft wrap long lines in ecb mode
(setq truncate-partial-width-windows nil)

;; ;; ;; color highlight "TODO" "FIXME" etc.
;; ;; (require 'highlight-fixmes-mode)
;; ;; (defun ajf-highlight-programmer-keywords ()
;; ;;   (highlight-fixmes-mode))
;; ;; ;; Version from emacs-fu
;; ;; ;; <http://emacs-fu.blogspot.com/2008/12/highlighting-todo-fixme-and-friends.html>
;; ;; (defun ajf-highlight-programmer-keywords ()
;; ;;   (font-lock-add-keywords nil
;; ;; 			    '(("\\<\\(FIXME\\|TODO\\|BUG\\):"
;; ;; 			       1 font-lock-warning-face t)
;; ;; 			      ("\\@\\(todo)"
;; ;; 			       1 font-lock-warning-face t))))

;; ;;;
;; ;;; C++ coding
;; ;;;
;; (defun my-c-mode-common-hook ()
;;    ;; Things that only need to be run once go in progn statement (I think)
;;   (progn
;; ;;     ; add hide/show minor mode to c coding
;; ;;     (hs-minor-mode 1)
;;     ; On redrock, outline mode seems better than hideshow
;;     (outline-minor-mode)
;;     ; Define style for ASA/PCI
;;     (c-add-style "asa"
;;                  '("ellemtel"
;;                    (c-offsets-alist . ((access-label . /)
;;                                        (inclass . +)
;;                                        (innamespace . 0)
;;                                        (template-args-cont . +)
;;                                        (arglist-cont-nonempty
;;                                         . c-lineup-arglist)
;;                                        (arglist-close . c-lineup-arglist)
;;                                        (topmost-intro-cont . +))
;;                                     )
;;                    (c-hanging-braces-alist .
;;                                            ((class-close before)
;;                                             ))
;;                    )
;;                  )
;;     ; Define my preferred style
;;     (c-add-style "ajf"
;;                  '("stroustrup"
;;                    (c-basic-offset . 2)
;;                    (c-offsets-alist . ((access-label . /)
;;                                        (template-args-cont . +)
;;                                        (arglist-cont-nonempty
;;                                         . c-lineup-arglist)
;;                                        (arglist-close . c-lineup-arglist)
;;                                        (topmost-intro-cont . +))
;;                                     )
;;                    (c-hanging-braces-alist
;;                     . ((defun-open after)
;;                        (class-open after)
;;                        (inline-open after)
;;                        (substatement-open after)
;;                        (class-close)  ; maybe add a function to add
;;                                       ; the semicolon as well?
;;                        (brace-list-open)
;;                        (brace-list-close))
;;                     )
;;                    )
;;                  )
;;     ; Setup auto-newlines
;;     (c-toggle-auto-newline t)
;;     (define-key c-mode-base-map (kbd "RET") 'newline-and-indent)
;;     )
;;   ;; Things to be run per buffer go here (I think)
;; ;  (senator-minor-mode)  ; I would like senator minor mode to only run in ecb,
;;                         ; but I haven't had any luck.
;;   (setq indent-tabs-mode nil)
;;   (when (and buffer-file-name
;;              (string-match "/asa\\(-git\\)?/" buffer-file-name))
;;     (c-set-style "asa")
;;     )
;;   (require 'doxymacs nil 'noerror)
;;   (if (featurep 'doxymacs)
;;       ((doxymacs-mode t)
;;        (doxymacs-font-lock)
;;        )
;;     )
;; ;;   ; This only works for semantic 1.0pre6, but that's so buggy it hangs Emacs
;; ;;   ; I don't think the gcc stuff is necessary, but it's here to be safe
;; ;;   (require 'semantic-gcc)
;; ;;   (semantic-gcc-setup)
;;   ; semantic doesn't parse the directory names correctly.  (It wants
;;   ; to look in /usr/usr/include...)  Here's a kludge to append the
;;   ; correct versions
;;   (mapc '(lambda (dir)
;;          (semantic-add-system-include
;;           (replace-regexp-in-string "^/usr/usr" "/usr" dir t t)))
;;        semantic-dependency-system-include-path)
;;   (semantic-load-enable-code-helpers)
;;   (semantic-decoration-mode)
;;   (semantic-stickyfunc-mode)
;; ;;   (ajf-highlight-programmer-keywords)
;;     )
;; (add-hook 'c-mode-hook 'my-c-mode-common-hook)
;; (add-hook 'c++-mode-hook 'my-c-mode-common-hook)
;; (setq c-default-style "ajf")

;; Fill column mode
;;
;;; TODO: Move up in the order
(if (>= emacs-major-version 27)
    (progn
      (add-hook 'prog-mode-hook '(lambda () (display-fill-column-indicator-mode)))
      (add-hook 'prog-mode-hook '(lambda () (message "Running prog-mode-hook: buffer %s" (buffer-name))))
      (eval-after-load 'markdown-mode
        '(progn (add-hook 'markdown-mode-hook '(lambda () (message "Running markdown mode hooks: buffer %s" (buffer-name))))
                (add-hook 'markdown-mode-hook #'display-fill-column-indicator-mode))
        )
      )
  (when (try-require 'fill-column-indicator)
    (setq fci-rule-color "firebrick3")

    ;; A whole bunch of logic to try to handle long lines and wrapping.
    ;;
    ;; Based initially on
    ;; https://www.emacswiki.org/emacs/FillColumnIndicator, but improved
    ;; to handle frame resizes, which is what usually changes the window
    ;; width.
    ;;
    ;; I have no idea how this will handle buffers shown in multiple
    ;; windows. My guess is the fill-column-indicator mode will be
    ;; determined by the last resized window/frame.
    ;;
    ;; Ironically, I wrote this just a day after emacs 27.1 was
    ;; released, where fill-column-indicator is no longer needed,
    ;; instead replaced by display-fill-column-indicator-mode.
    (setq fci-handle-truncate-lines nil)
    (defun auto-fci-mode (&optional unused)
      "Automatically turn on fill-column-indicator mode when necessary.

Turn on fci in buffers corresponding to files, shown in windows
wide enough to show the indicator"
      ;; TODO: How to log at different levels?
                                        ;(message "Running auto-fci-mode for buffer %s, file name %s, width %s, fill width %s"
                                        ;         (buffer-name)
                                        ;         buffer-file-name
                                        ;         (window-width)
                                        ;         (or fci-rule-column fill-column))
      (when buffer-file-name
                                        ;(message "Checking window width")
        (if (> (window-width) (or fci-rule-column fill-column))
            (fci-mode 1)
          (fci-mode 0))
        )
      )
    (defun auto-fci-mode-all-windows (&optional unused)
      (walk-windows
       (lambda (window)
         (with-current-buffer (window-buffer window)
           (auto-fci-mode)))))

    (add-hook 'prog-mode-hook 'auto-fci-mode)
    (add-hook 'after-change-major-mode-hook 'auto-fci-mode)

    ;; Check window width after frame resize events.
    ;;
    ;; This handles resizing the frame width (and height). This doesn't
    ;; handle if the windows within the frame change, but I can't
    ;; remember the last time I split my frame horizontally.  To check
    ;; for resizes of windows within a unchanged frame, a check would
    ;; have to be done via window-configuration-change-hook.
    (add-hook 'window-size-change-functions
              ;; Only check window widths when column changes.
              (lambda (frame)
                (when (frame-size-changed-p frame) (auto-fci-mode-all-windows))))
    )
  )


;;;
;;; Python
;;;


;; ;; Using pymacs 0.24-beta1 with uniquify breaks all help commands
;; ;; <http://groups.google.com/group/rope-dev/browse_thread/thread/7e41647ecc337cb7>
;; ;; ;; Ropemacs
;; ;; (require 'pymacs)


;; ;; ipython mode -- does not work with Emacs22 python.el
;; ;(require 'ipython)

;; ;; ; strip trailing whitespace from lines when saving
;; ;; (add-to-list 'nuke-trailing-whitespace-always-major-modes
;; ;;              'python-mode)

(require 'which-func)
;; If which-func-modes is t, then it's automatically enabled in all
;; supporting modes.  And the add-to-list will fail because it's not a
;; list.
(if (listp which-func-modes)
    (add-to-list 'which-func-modes 'python-mode)
  )
;; From https://emacsredux.com/blog/2014/04/05/which-function-mode/
;; and https://www.emacswiki.org/emacs/WhichFuncMode
(setq mode-line-misc-info (delete (assoc 'which-func-mode
                                         mode-line-misc-info)
				  mode-line-misc-info)
      which-func-header-line-format '(which-func-mode ("" which-func-format)))
(defadvice which-func-ff-hook (after header-line activate)
  (when which-func-mode
    (setq mode-line-misc-info (delete (assoc 'which-func-mode
                                             mode-line-misc-info)
				      mode-line-misc-info)
          header-line-format which-func-header-line-format)))


;;; python mode customization
;;;
;;; TODO: Advise python-indent-calculate-indentation to indent
;;; continued lines by 4 characters.
(add-hook 'python-mode-hook
          (lambda ()
            (progn
              (define-key python-mode-map "\C-m" 'newline-and-indent)
;;               (pymacs-load "ropemacs" "rope-")
;; Newest version of ropemacs has its own menu.  No longer need old one.
;;            (defun ropemacs-toggle-confirm-saving ()
;;              (interactive)
;;              (if ropemacs-confirm-saving
;;                  (setq ropemacs-confirm-saving nil)
;;                (setq ropemacs-confirm-saving t)
;;                )
;;              )
;;            (defun rope-generate-menu ()
;;              (easy-menu-define rope-menu python-mode-map "Rope"
;;                '("Rope"
;;                  ["Open project" rope-open-project]
;;                  ["Configure project" rope-project-config]
;;                  ["Close project" rope-close-project]
;;                  ["Find file" rope-find-file]
;;                  "---"
;;                  ["Undo" rope-undo]
;;                  ["Redo" rope-redo]
;;                  ("Create..."
;;                   ["Module" rope-create-module]
;;                   ["Package" rope-create-package]
;;                   ["File" rope-create-file]
;;                   ["Directory" rope-create-directory])
;;                  "---"
;;                  ["Rename" rope-rename]
;;                  ["Extract variable" rope-extract-variable]
;;                  ["Extract method" rope-extract-method]
;;                  ["Inline variable" rope-inline]
;;                  ["Move" rope-move]
;;                  ["Restructure" rope-restructure]
;;                  ["Use function" rope-use-function]
;;                  ["Rename module" rope-rename-current-module]
;;                  ["Move module" rope-move-current-module]
;;                  ["Convert module to package" rope-module-to-package]
;;                  "---"
;;                  ["Organize imports" rope-organize-imports]
;;                  ("Generate..."
;;                   ["Variable" rope-generate-variable]
;;                   ["Function" rope-generate-function]
;;                   ["Class" rope-generate-class]
;;                   ["Module" rope-generate-module]
;;                   ["Package" rope-generate-package])
;;                  "---"
;;                  ["Code assist" rope-code-assist]
;;                  ["Go to definition" rope-goto-definition]
;;                  ["Show doc" rope-show-doc]
;;                  ["Find occurrences" rope-find-occurrences]
;;                  ["Lucky assist" rope-lucky-assist]
;;                  "---"
;;                  ["Confirm saving" ropemacs-toggle-confirm-saving
;;                  :style toggle :selected ropemacs-confirm-saving]
;;                  )
;;                )
;;              (easy-menu-add rope-menu python-mode-map)
;;              )
;;            (rope-generate-menu)
              )
;;             (ropemacs-mode t)
            ; HideShow is better for Python.  Outline mode doesn't
            ; seem to fold functions correctly as often
            (hs-minor-mode)
	    ;(outline-minor-mode) Set indentation to 2 spaces.  Use
            ; python-guess-indent for pre-existing files
            (setq python-indent 2)
            ; strip trailing whitespace
            (ws-butler-mode)
            (when (and buffer-file-name
                       (string-match "/asa\\(-git\\)?/" buffer-file-name))
              (set-variable 'python-indent 3 t)
              )
;; 	    (ajf-highlight-programmer-keywords)
            )
          )


(use-package virtualenvwrapper
  :commands (venv-workon
             venv-deactivate
             venv-mkvirtualenv
             venv-mkvirtualenv-using
             venv-rmvirtualenv
             venv-lsvirtualenv
             venv-cdvirtualenv
             venv-cpvirtualenv
             venv-with-virtualenv)
  :custom
  ;; TODO: Move eshell-prompt-function settings somewhere else in case
  ;; I want to set it based on other packages as well. Also, need to
  ;; add color. See https://www.emacswiki.org/emacs/EshellPrompt for
  ;; details.
  (eshell-prompt-function
   (function
    (lambda ()
      (concat (if (bound-and-true-p venv-current-name)
                  (concat "("
                          venv-current-name
                          ") "))
              (abbreviate-file-name (eshell/pwd))
              (if (= (user-uid) 0) " # " " $ ")))))
  :config
  (venv-initialize-interactive-shells)
  (venv-initialize-eshell)
  ;; TODO: Try to get the current virtualenv in the modeline
  ;; (particularly doom-modeline). See doom-modeline-env.el. Maybe
  ;; putting advice around doom-modeline-env--python-args? Maybe just
  ;; rely on VIRTUAL_ENV environment variable (but need to remove
  ;; leading directory that's WORKON_HOME), or just
  ;; `venv-current-name'.
  )


;;; TODO: Advise auto-virtualenvwrapper--project-root to return name
;;; of current directory if it matches a pre-existing virtualenv, to
;;; use for my throwaway virtualenvs when testing stuff. (Obviously
;;; this would be an advise after the call that only does something if
;;; the return root is the empty string.)
(use-package auto-virtualenvwrapper
  :hook (python-mode . auto-virtualenvwrapper-activate))


;;; TODO: Get this to autoload for requirements/base.in and similar.
;;; It already autoloads for requirements/base.txt, should be easy to
;;; generalize, although the logic might be too loose, and matches too
;;; many files.
(use-package pip-requirements
  )


;;; Objective-C mode
;;;
;;; Configuration taken from <https://www.emacswiki.org/emacs/ObjectiveCMode>
(add-to-list 'auto-mode-alist '("\\.m\\'" . objc-mode))
(add-to-list 'auto-mode-alist '("\\.mm\\'" . objc-mode))
;; Use objc-mode for objective-c headers
(add-to-list 'magic-mode-alist
             `(,(lambda ()
                  (and (string= (file-name-extension buffer-file-name) "h")
                       (re-search-forward "@\\<interface\\>"
                                          magic-mode-regexp-match-limit t)))
               . objc-mode))
;; Configure cc-other-file-alist to know .h can be headers for .m and .mm files.
(require 'find-file)
(nconc (cadr (assoc "\\.h\\'" cc-other-file-alist)) '(".m" ".mm"))
(defadvice ff-get-file-name (around ff-get-file-name-framework
                                    (search-dirs
                                     fname-stub
                                     &optional suffix-list))
  "Search for Mac framework headers as well as POSIX headers."
  (or
   (if (string-match "\\(.*?\\)/\\(.*\\)" fname-stub)
       (let* ((framework (match-string 1 fname-stub))
              (header (match-string 2 fname-stub))
              (fname-stub (concat framework ".framework/Headers/" header)))
         ad-do-it))
   ad-do-it))
(ad-enable-advice 'ff-get-file-name 'around 'ff-get-file-name-framework)
(ad-activate 'ff-get-file-name)


; Jamfile mode
(use-package jam-mode
  :mode (("Jamroot" . jam-mode)
         ("\\.jam\\'" . jam-mode))
  )

;;; Go-mode
(when (or (try-require 'go-mode) (try-require 'go-mode-load))
  (add-hook 'go-mode-hook
            (lambda ()
              (progn
                (define-key go-mode-map (kbd "RET") 'newline-and-indent))
              (setq tab-width 2)
              (setq indent-tabs-mode 1)
              )
            )
)


;;; Gyp mode
;;; from <https://code.google.com/p/gyp/source/browse/trunk/tools/emacs/>
(try-require 'gyp)


;; ;;;;; SKIPPING latex stuff

;; ;;;;; SKIPPING longlines-show-effect


;; From <http://www.emacswiki.org/cgi-bin/wiki/UntabifyUponSave>
 (defun ska-untabify ()
   "Stefan Kamphausen's untabify function as discussed and described at
 http://www.jwz.org/doc/tabs-vs-spaces.html
 and improved by Claus Brunzema:
 - return nil to get `write-contents-hooks' to work correctly
   (see documentation there)
 - when instead of if
 Use some lines along the following for getting this to work in the
 modes you want it to:

 \(add-hook 'some-mode-hook
           '(lambda ()
                (add-hook 'write-contents-hooks 'ska-untabify nil t)))"
   (save-excursion
     (goto-char (point-min))
     (when (search-forward "\t" nil t)
       (untabify (1- (point)) (point-max)))
     nil))


;; Markdown mode
(use-package markdown-mode
             :commands (markdown-mode gfm-mode)
             :mode (("\\.md" . markdown-mode)
                    ("\\.mdwn" . markdown-mode)
                    ("\\.markdown" . markdown-mode))
             :config
             (setq markdown-fontify-code-blocks-natively t)
             (setq markdown-spaces-after-code-fence 0)
             (add-hook 'markdown-mode-hook
                       '(lambda ()
                          (add-hook 'write-contents-hooks 'ska-untabify nil t)))
             )


;; Yaml mode
(use-package yaml-mode
             :mode "\\.yaml")


;; JS mode
(use-package js-mode
  :commands js-mode
  :config
  (define-key js-mode-map (kbd "M-.") nil)
  )
(use-package js2-mode
  :mode "\\.js"
  :config
  (add-hook 'js2-mode-hook #'js2-imenu-extras-mode)
  (define-key js-mode-map (kbd "M-.") nil)
  )

(use-package js2-refactor
 ; :after (js2-mode)
  :hook (js2-mode . js2-refactor-mode)
  :custom
  (js2r-prefer-let-over-var t)
  ;; Prefer single quotes to double (should this be in a work setting?)
  ;;
  ;; (Yes, 2 = single quotes and 1 = double quotes. Not needlessly confusing at
  ;; all.)
  (js2r-prefered-quote-type 2)
  :config
  (easy-menu-define js2-refactor-menu js2-mode-map "Refactor"
    '("Refactor"
      ["Extract var" js2r-extract-var]
      ["Extract let" js2r-extract-let]
      ["Extract const" js2r-extract-const]
      ["Inline variable" js2r-inline-var]
      ["Rename var" js2r-rename-var]
      "---"
      ["Extract function" js2r-extract-function]
      ["Extract method" js2r-extract-method]
      "---"
      ;; These I need to play with to fully grok
      ["Expand node" js2r-expand-node-at-point]
      ["Contract node" js2r-contract-node-at-point]
      ["Wrap buffer" js2r-wrap-buffer-in-iife]
      ["Inject global" js2r-inject-global-in-iife]
      ["Convert var to this" js2r-var-to-this]
      ["Add to globals" js2r-add-to-globals-annotation]
      ["Split var declaration" js2r-split-var-declaration]
      ["Split string" js2r-split-string]
      ["String to template" js2r-string-to-template]
      ["Introduce parameter" js2r-introduce-parameter]
      ["Localize parameter" js2r-localize-parameter]
      ["Toggle function expression and declaration" js2r-toggle-function-expression-and-declaration]
      ["Toggle arrow function" js2r-toggle-arrow-function-and-expression]
      ["Toggle async function" js2r-toggle-function-async]
      ["Args to object" js2r-arguments-to-object]
      ["Unwrap" js2r-unwrap]
      ["Wrap in for-loop" js2r-wrap-in-for-loop]
      ["Convert ternary to if" js2r-ternary-to-if]
      ["Log node" js2r-log-this]
      ["Debug node" js2r-debug-this]
      ["Forward slurp" js2r-forward-slurp]
      ["Forward barf" js2r-forward-barf]
      ["Kill line" js2r-kill]
  ))
  (easy-menu-add js2-refactor-menu js2-mode-map)
  )


;; JSON mode
(use-package json-mode
             :mode "\\.json")


;; TeX mode
(load "~/.emacs.d/dotemacs.tex.el")


;; SWIG mode
(use-package swig-mode
             :mode (("\\.swig\\'" . swig-mode)
                    ("\\.i\\'" . swig-mode)))


;; HTML/SGML settings
;;
;; I used to have a whole bunch of nxml/mmm-mode settings which I have
;; lost track of. Oh, well. Those modes are probably obsolete anyway.
(add-hook 'sgml-mode-hook 'sgml-electric-tag-pair-mode)


;; Use python-mode for .pythonrc
(add-to-list 'auto-mode-alist '(".pythonrc" . python-mode))


;; Modes for certain config files

;; TODO: Again figure out how to automatically fallback to conf-mode
(use-package gitconfig-mode
             :mode (("\\.gitconfig\\.local" . gitconfig-mode)
                    ("\\.gitconfig" . gitconfig-mode)))


(add-to-list 'auto-mode-alist '(".hgrc" . conf-mode))
(add-to-list 'auto-mode-alist '(".pylintrc" . conf-mode))


;; Protocol buffer mode
(use-package protobuf-mode
             :mode "\\.proto\\'"
             )

;; sh-mode settings
(add-hook 'sh-mode-hook (lambda ()
                          (setq indent-tabs-mode nil)
                          (setq sh-basic-offset 2)
                          (setq indentation 2)))

(use-package shfmt
  :hook (sh-mode . shfmt-mode)
  :custom
  (shfmt-arguments '("-i" "2" "-ci" "-bn" "-sr")))


;; ;; Desktop save mode
;; ;; <http://www.gnu.org/software/emacs/manual/html_node/emacs/Saving-Emacs-Sessions.html>
;; ;(desktop-save-mode 1)


(use-package powershell
  :mode ("\\.ps1\\'" . powershell-mode))


;;; explain-pause-mode
;;;
;;; https://github.com/lastquestion/explain-pause-mode
(use-package explain-pause-mode
  ;; If explain-pause-mode is not available, this hook fails.
  ;; :hook
  ;; (after-init . explain-pause-mode)
  :config (explain-pause-mode)
  )


;; Mercurial command server vc backend
;; https://github.com/muffinmad/emacs-vc-hgcmd
;;
;; Much faster for work clients.
;;
;; TODO: Move above loading the local init, and add a version in the
;; local init for work clients.
(use-package vc-hgcmd
             :config
             (add-to-list 'vc-handled-backends 'Hgcmd))


(setq local-init-file "~/.emacs.d/init-local.el")
(if (file-exists-p local-init-file)
    (load local-init-file)
)

;; warn that some packages were missing
(if missing-packages-list
    (progn (message "Packages not found: %S" missing-packages-list)))

;; Save customized settings into separate file
;; <http://www.emacsblog.org/>
(cond ((<= emacs-major-version 23)
       (setq custom-file "~/.emacs.d/custom-23.el"))
      (t
       ;; Emacs version 24 and later
       (setq custom-file "~/.emacs.d/custom.el"))
      )
(load custom-file 'noerror)
