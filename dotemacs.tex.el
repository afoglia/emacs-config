;;; AucTeX mode for (La)TeX files

(when (try-require 'tex-site)
  (if (eq system-type 'windows-nt)
      (require 'tex-mik)
    )

  ;; Use math-mode
  (add-hook 'LaTeX-mode-hook 'LaTeX-math-mode)
  (add-hook 'LaTeX-mode-hook 'outline-minor-mode)

  ;; plug in RefTex
  (add-hook 'LaTeX-mode-hook 'turn-on-reftex)
  (setq reftex-plug-into-AUCTeX t)

                                        ; automatically parse buffers and save info
  (setq TeX-parse-self t)
  (setq TeX-auto-save t)

                                        ; bib-cite minor mode
  (autoload 'bib-cite-minor-mode "bib-cite" "Enhanced bib handling for AucTeX" t)

  ;; kdvi integration
  (if (locate-library "kdvi-search")
      (progn
                                        ; start emacs server to allow reverse searching with kdvi
        (add-hook 'LaTeX-mode-hook 'server-start)
        (add-hook 'server-switch-hook 'raise-frame)
                                        ;(setq TeX-source-specials-mode 1) ; doesn't seem to work with kpdf

        ;; KDVI is no longer in development. Instead, KDE uses Okular for DVI viewing.
                                        ; kdvi forward search
        (require 'kdvi-search)
        (add-hook 'LaTeX-mode-hook
                  (lambda () (local-set-key "\C-x\C-j" 'kdvi-jump-to-line)))
        (add-hook 'tex-mode-hook
                  (lambda () (local-set-key "\C-x\C-j" 'kdvi-jump-to-line)))

        ;; (setq TeX-output-view-style
        ;;       (list
        ;;        (list "^dvi$" "^pstricks$\\|^pst-\\|^psfrag$"
        ;;              "%(o?)dvips %d -o && gv %f")
        ;;        (list "^dvi$" "^a4\\(?:dutch\\|paper\\|wide\\)?\\|sem-a4$"
        ;;              "%(o?)xdvi %dS -paper a4 %d")
        ;;        (list "^dvi$" (list "^a5\\(?:comb\\|paper\\)?$"
        ;;                            "^landscape$")
        ;;              "%(o?)xdvi %dS -paper a5r -s 0 %d")
        ;;        (list "^dvi$" "^a5\\(?:comb\\|paper\\)?$"
        ;;              "kdvi --unique %dS --paper a5 %d")
        ;;        (list "^dvi$" "^b5paper$"
        ;;              "kdvi --unique %dS --paper b5 %d")
        ;;        (list "^dvi$" (list "^landscape$" "^pstricks$\\|^psfrag$")
        ;;              "%(o?)dvips -t landscape %d -o && gv %f")
        ;;        (list "^dvi$" "^letterpaper$"
        ;;              "kdvi --unique %dS --paper us %d")
        ;;        (list "^dvi$" "^legalpaper$"
        ;;              "kdvi --unique %dS --paper legal %d")
        ;;        (list "^dvi$" "^executivepaper$"
        ;;              "kdvi --unique %dS --paper 7.25x10.5in %d")
        ;;        (list "^dvi$" "^landscape$"
        ;;              "kdvi --unique %dS --paper a4r -s 0 %d")
        ;;        (list "^dvi$" "." "kdvi --unique %dS %d")
        ;;        (list "^pdf$" "." "xpdf %o")
        ;;        (list "^html?$" "." "netscape %o")))

        ;; Ubuntu box uses kdvi 1.4, which doesn't use --paper option
        (setq TeX-output-view-style
              (list
               (list "^dvi$" "^pstricks$\\|^pst-\\|^psfrag$"
                     "%(o?)dvips %d -o && gv %f")
               (list "^dvi$" "^a4\\(?:dutch\\|paper\\|wide\\)?\\|sem-a4$"
                     "%(o?)xdvi %dS -paper a4 %d")
               (list "^dvi$" (list "^a5\\(?:comb\\|paper\\)?$"
                                   "^landscape$")
                     "%(o?)xdvi %dS -paper a5r -s 0 %d")
               (list "^dvi$" "^a5\\(?:comb\\|paper\\)?$"
                     "kdvi --unique %dS %d")
               (list "^dvi$" "^b5paper$"
                     "kdvi --unique %dS %d")
               (list "^dvi$" (list "^landscape$" "^pstricks$\\|^psfrag$")
                     "%(o?)dvips -t landscape %d -o && gv %f")
               (list "^dvi$" "^letterpaper$"
                     "kdvi --unique %dS %d")
               (list "^dvi$" "^legalpaper$"
                     "kdvi --unique %dS %d")
               (list "^dvi$" "^executivepaper$"
                     "kdvi --unique %dS %d")
               (list "^dvi$" "^landscape$"
                     "kdvi --unique %dS %d")
               (list "^dvi$" "." "kdvi --unique %dS %d")
               (list "^pdf$" "." "xpdf %o")
               (list "^html?$" "." "netscape %o")))
        )
    )
  )