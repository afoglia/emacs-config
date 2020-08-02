;;; Set up font
;;;
;;; In emacs 23, Ubuntu 12.04, emacs no longer respects the settings
;;; in .Xresources.
(set-default-font "Terminus-9")

;;; Need to set it for each frame...  Ugh.
;;; <http://superuser.com/questions/210555/emacs-font-settings-not-working-in-new-frame>
(add-to-list 'default-frame-alist
             '(font . "Terminus-9"))

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
       (mapcar
        (lambda (site-start-dir)
          (concat user-emacs-directory site-start-dir))
        ajf-site-start-dirs)))

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

;; Emacs package support
(when (>= emacs-major-version 23)
  (require 'package)
  (package-initialize)
  (add-to-list 'package-archives
               '("melpa" . "http://melpa.org/packages/") t)
)

(when (try-require 'auto-package-update)
  (setq auto-package-update-prompt-before-update t)
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
           ;; Need to install color-theme-modern and try to set up those
           ;; themes. See load-theme function and custom-safe-themes variable.
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

;;; Quiet startup

;; Shut off startup message
(setq inhibit-startup-message t)

;; Leave the scratch buffer empty
(setq initial-scratch-message nil)

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
(message "windows-system == %s" window-system)
(if (memq window-system '(mac ns))
    (when (try-require 'exec-path-from-shell)
      (exec-path-from-shell-initialize)))

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

(require 'zoom-frm)
(global-set-key (if (boundp 'mouse-wheel-down-event)
                    (vector (list 'control mouse-wheel-down-event))
                  [C-mouse-wheel])   ; Emacs 20, 21
                'zoom-frm-in)
(when (boundp 'mouse-wheel-up-event)
  (global-set-key (vector (list 'control mouse-wheel-up-event)) 'zoom-frm-out))
;; (global-set-key [S-mouse-1]    'zoom-frm-in)
;; (global-set-key [C-S-mouse-1]  'zoom-frm-out)
;; ;; Get rid of `mouse-set-font':
;; (global-set-key [S-down-mouse-1] nil)

;;; Set up emacs-server
(server-start)
(add-hook 'server-switch-hook
          (lambda nil
            (let ((server-buf (current-buffer)))
              (bury-buffer)
              (switch-to-buffer-other-frame server-buf))))


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


;;; Amx
(when (try-require 'amx)
  (amx-mode))

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

; Clean up unused buffers at 4 AM
(require 'midnight)
(midnight-delay-set 'midnight-delay "4:00am")

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
(when (try-require 'ws-butler)
  (setq ws-butler-keep-whitespace-before-point nil)
  (ws-butler-global-mode)
)

;; Function to highlight lines longer that run over 80 columns
(defun show-overlong-lines ()
  (interactive)
  (font-lock-add-keywords
   nil
   '(("^[^\n]\\{80\\}\\(.*\\)$" 1 font-lock-warning-face t))))

;; Highlight matching parentheses
(show-paren-mode t)
;; From <http://www.emacswiki.org/emacs/ShowParenMode>
(defadvice show-paren-function (after show-matching-paren-offscreen activate)
  "If the matching paren is offscreen, show the matching line in the echo area.  Has no effect if the character before point is not of the syntax class ')'."
  (interactive)
  ;; Only call `blink-matching-open' if the character before point
  ;; is a close parentheses type character.  Otherwise, there's not
  ;; really any point, and `blink-matching-open' would just echo
  ;; "Mismatched parentheses", which gets really annoying.
  (let* ((cb (char-before (point)))
         (matching-text
          (if (and cb
                   (char-equal (char-syntax cb) ?\) ))
              (blink-matching-open))))
    (when matching-text
      (message matching-text)))
  )

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

;;; Browse kill ring
(when (require 'browse-kill-ring nil 'noerror)
  (browse-kill-ring-default-keybindings))


;; Glasses mode settings
(setq glasses-separate-parentheses-p nil)
;(setq glasses-separator "")
;(setq glasses-face 'bold)
(setq glasses-original-separator "") ; keep originally underscored
                                     ; stuff underscored
(setq glasses-separator "_")
(setq glasses-face 'italic)


;; Automatic smerge mode
(autoload 'smerge-mode "smerge-mode" nil t)
(defun sm-try-smerge ()
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^<<<<<<< " nil t)
      (smerge-mode 1))))
(add-hook 'find-file-hooks 'sm-try-smerge t)


;; Flycheck
(when (try-require 'flycheck)
  (global-flycheck-mode)
  (setq flycheck-idle-change-delay 4))


;; Put a2ps in the File menu
;;
;; Need to use `load` and not `require` because a2ps doesn't "provide"
;; a2ps-print.
(when (load "a2ps-print" 'noerror)
    (setq a2ps-switches `("-C"))
    ;; TODO: Ubuntu/Debian puts this in the menu already...  Need to
    ;; check the load-history variable to see if it's already been
    ;; loaded, or can check the menu.
    (easy-menu-add-item nil
			'("file") ["a2ps Buffer" a2ps-buffer "--"]
			"separator-window")
)
;; (load "a2ps-print")
;; (setq a2ps-switches `("-C"))
;; (easy-menu-add-item nil
;;                     '("file") ["a2ps Buffer" a2ps-buffer "--"]
;;                     "separator-window")



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

;;; TODO: Move up in the order
(when (try-require 'fill-column-indicator)
  (setq fci-rule-color "firebrick3")
  (add-hook 'after-change-major-mode-hook (lambda () (if buffer-file-name (fci-mode 1))))
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

; python mode customization
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
                                     &optionak suffix-list))
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
(require 'jam-mode nil 'noerror)
;; (if (featurep 'jam-mode)
;;     (setq jam-indent-size 3)
;; )

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

;; ;;
;; ;; Add new automatic modes for files
;; ;;
;; (setq auto-mode-alist (append
;;                        '(("\\.gnu-emacs\\(-custom\\)?\\'" . lisp-mode)
;;                          ("/asa\\(-git\\)?/.*\\.h\\'" . c++-mode)
;;                          ("Jamroot" . jam-mode)
;;                          (".*\\.jam\\'" . jam-mode))
;;                        auto-mode-alist)
;; )

;; From <http://www.emacswiki.org/cgi-bin/wiki/UntabifyUponSave>
 (defun ska-untabify ()
   "Stefan Kamphausen's untabify function as discussed and described at
 http://www.jwz.org/doc/tabs-vs-spaces.html
 and improved by Claus Brunzema:
 - return nil to get `write-contents-hooks' to work correctly
   (see documentation there)
 - `make-local-hook' instead of `make-local-variable'
 - when instead of if
 Use some lines along the following for getting this to work in the
 modes you want it to:

 \(add-hook 'some-mode-hook
           '(lambda ()
               (make-local-hook 'write-contents-hooks)
                (add-hook 'write-contents-hooks 'ska-untabify nil t)))"
   (save-excursion
     (goto-char (point-min))
     (when (search-forward "\t" nil t)
       (untabify (1- (point)) (point-max)))
     nil))

;; Markdown mode
(autoload 'markdown-mode "markdown-mode")
(add-to-list 'auto-mode-alist '("\\.mdwn" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.markdown" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md" . markdown-mode))
(setq markdown-fontify-code-blocks-natively t)
(setq markdown-spaces-after-code-fence 0)
(add-hook 'markdown-mode-hook
           (lambda ()
             (make-local-hook 'write-contents-hooks)
             (add-hook 'write-contents-hooks 'ska-untabify nil t)))

;; Yaml mode
(when (try-require 'yaml-mode)
  (add-to-list 'auto-mode-alist '("\\.yaml" . yaml-mode)))


;; TeX mode
(load "~/.emacs.d/dotemacs.tex.el")


;; SWIG mode
(when (try-require 'swig-mode)
  (add-to-list 'auto-mode-alist '("\\.swig\\'" . swig-mode))
  (add-to-list 'auto-mode-alist '("\\.i\\'" . swig-mode))
  )

;; Use python-mode for .pythonrc
(add-to-list 'auto-mode-alist '(".pythonrc" . python-mode))

;; conf-mode for certain config files
(add-to-list 'auto-mode-alist '(".gitconfig" . conf-mode))
(add-to-list 'auto-mode-alist '(".hgrc" . conf-mode))

;; Protocol buffer mode
(try-require 'protobuf-mode)

;; sh-mode settings
(add-hook 'sh-mode-hook (lambda ()
                          (setq indent-tabs-mode nil)
                          (setq sh-basic-offset 2)
                          (setq indentation 2)))

;; ;; Desktop save mode
;; ;; <http://www.gnu.org/software/emacs/manual/html_node/emacs/Saving-Emacs-Sessions.html>
;; ;(desktop-save-mode 1)


;;; explain-pause-mode
;;;
;;; https://github.com/lastquestion/explain-pause-mode
(when (try-require 'explain-pause-mode)
  (add-hook 'after-init-hook #'explain-pause-mode))

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
