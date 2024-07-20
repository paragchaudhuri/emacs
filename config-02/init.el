;; -*- lexical-binding: t -*-

(defvar elpaca-installer-version 0.7)
(defvar elpaca-directory (expand-file-name "etc/elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))

(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (< emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                 ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                 ,@(when-let ((depth (plist-get order :depth)))
                                                     (list (format "--depth=%d" depth) "--no-single-branch"))
                                                 ,(plist-get order :repo) ,repo))))
                 ((zerop (call-process "git" nil buffer t "checkout"
                                       (or (plist-get order :ref) "--"))))
                 (emacs (concat invocation-directory invocation-name))
                 ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                       "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                 ((require 'elpaca))
                 ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; Install use-package support
(elpaca elpaca-use-package
  ;; Enable use-package :ensure support for Elpaca.
  (elpaca-use-package-mode))

;; Loading no-littering early
(elpaca no-littering
  (require 'no-littering))

;; Making sure etc/custom.el gets all customizations

(elpaca-wait) ;let all elpaca queues finish before proceeding

;; See posimacs-early-init.el for initial replacement.
(defun pec--elpaca-after-init ()
  "Undo filename handler trick and delete self for fun."

;; Making sure etc/custom.el gets all customizations
(load
  (setq custom-file (expand-file-name "customs.el" user-emacs-directory))
 'noerror)

  (setq file-name-handler-alist file-name-handler-alist--old)
  (remove-hook 'elpaca-after-init-hook #'pec--elpaca-after-init)
  (fmakunbound #'pec--elpaca-after-init)
  (makunbound 'file-name-handler-alist--old))

(add-hook 'elpaca-after-init-hook #'pec--elpaca-after-init)

;; Idle garbage collection
(use-package gcmh
  :ensure t
  :demand t
  :config
  (add-hook 'elpaca-after-init-hook (lambda () (gcmh-mode 1))))

(use-package evil
  :ensure t
  :demand t
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-vsplit-window-right t)
  (setq evil-split-window-below t)
  (evil-mode)
  (define-key evil-insert-state-map (kbd "C-g") 'evil-normal-state)
  (define-key evil-insert-state-map (kbd "C-h") 'evil-delete-backward-char-and-join)

  ;;Use visual line motions even outside of visual-line-mode buffers
  ;;(evil-global-set-key 'motion "j" 'evil-next-visual-line)
  ;;(evil-global-set-key 'motion "k" 'evil-previous-visual-line)

  ;;Do not use evil mode in some buffers
  ;(evil-set-initial-state 'messages-buffer-mode 'normal)
  ;(evil-set-initial-state 'dashboard-mode 'normal)
  )

(use-package evil-collection
  :after evil
  :after magit
  :config
  (setq evil-collection-mode-list '(dashboard dired ibuffer))
  (evil-collection-init))

;;(use-package evil-tutor)

(use-package general
  :ensure (:wait t)
  :demand t
  :config
  (general-evil-setup)

  ;; set up 'SPC' as the global leader key
  (general-create-definer pec/leader-keys
    :states '(normal insert visual emacs)
    :keymaps 'override
    :prefix "SPC" ;; set leader
    :non-normal-prefix "S-SPC") ;; access leader in insert mode

  (pec/leader-keys
    "SPC" '(execute-extended-command :wk "M-x alternate")
    "." '(consult-fd :wk "Find file")
    "f c" '((lambda () (interactive) (find-file ~/.config/emacs/emacs.org)) :wk "Edit emacs config")
    "TAB TAB" '(comment-line :wk "Comment lines"))
  
  (pec/leader-keys
    "b" '(:ignore t :wk "buffer")
    "b b" '(consult-buffer :wk "Switch buffer")
    "b i" '(ibuffer :wk "Ibuffer")
    "b k" '(kill-this-buffer :wk "Kill this buffer")
    "b n" '(next-buffer :wk "Next buffer")
    "b p" '(previous-buffer :wk "Previous buffer")
    "b r" '(revert-buffer :wk "Reload buffer"))
  
  (pec/leader-keys
    "d" '(:ignore t :wk "Dired")
    "d d" '(dired :wk "Open dired")
    "d j" '(dired-jump :wk "Dired jump to current")
    "d n" '(neotree-dir :wk "Open directory in neotree")
    "d p" '(dired-preview-global-mode :wk "Dired preview mode toggle"))
  
  (pec/leader-keys
    "e" '(:ignore t :wk "Evaluate")
    "e b" '(eval-buffer :wk "Evaluate elisp in buffer")
    "e d" '(eval-defun :wk "Evaluate defun containing or after point")
    "e e" '(eval-expression :wk "Evaluate an eLisp expression")
    "e l" '(eval-last-sexp :wk "Evaluate eLisp expression before point")
    "e r" '(eval-region :wk "Evaluate eLisp in region")
    "e s" '(eshell :wk "Wshell")
    "e h" '(consult-history :wk "Eshell history"))

  (pec/leader-keys
    "h" '(:ignore t :wk "Help")
    "h f" '(describe-function :wk "Describe function")
    "h t" '(load-theme :wk "Load theme")
    "h v" '(describe-variable :wk "Describe variable")
    "h r r" '((lambda () (interactive)
		(load-file user-init-file)
		(ignore (elpaca-process-queues)))
	      :wk "Reload Emacs init.el"))

  (pec/leader-keys
    "m" '(:ignore t :wk "Org")
    "m a" '(org-agenda :wk "Org agenda") 
    "m b" '(org-babel-tangle :wk "Org babel tangle")
    "m e" '(org-export-dispath :wk "Org export dispatch")
    "m i" '(org-toggle-item :wk "Org toggle item")
    "m h" '(consult-org-heading :wk "Goto Org heading")
    "m t" '(org-todo :wk "Org todo")
    "m T" '(org-todo-list :wk "Org todo list"))

  (pec/leader-keys
    "m l" '(:ignore t :wk "Org tables")
    "m l -" '(org-table-insert-hline :wk "Insert hline in table"))

  (pec/leader-keys
    "m d" '(:ignore t :wk "Org date/deadline")
    "m d t" '(org-time-stamp :wk "Org time stamp"))
    
  (pec/leader-keys
   "t" '(:ignore t :wk "Toggle")
   "t l" '(display-line-numbers-mode :wk "Toggle line numbers")
   "t t" '(visual-line-mode :wk "Toggle truncated lines")
   "t v" '(vterm-toggle :wk "Toggle vterm"))

  (pec/leader-keys
   "w" '(:ignore t :wk "Windows")
   "w c" '(evil-window-delete :wk "Close window")
   "w n" '(evil-window-new :wk "New window")
   "w s" '(evil-window-split :wk "Horizontal split window")
   "w v" '(evil-window-vsplit :wk "Vetically split window")

   "w <left>" '(evil-window-left :wk "Window left")
   "w <down>" '(evil-window-down :wk "Window down")
   "w <up>" '(evil-window-up :wk "Window up")
   "w <right>" '(evil-window-right :wk "Window right")
   "w w" '(evil-window-next :wk "Goto next window")

   "w H" '(buf-move-left :wk "Buffer move left")
   "w J" '(buf-move-down :wk "Buffer move down")
   "w K" '(buf-move-up :wk "Buffer move up")
   "w L" '(buf-move-right :wk "Buffer move right"))

  (pec/leader-keys
    "o" '(ace-window :wk "Ace window"))
  )

(use-package ace-window
  :ensure t
  :diminish
  :config (ace-window-display-mode 1)
  )

(use-package buffer-move
  :ensure t
  :bind (
         ("C-S-<up>" . buf-move-up)
         ("C-S-<down>" . buf-move-down)
         ("C-S-<left>" . buf-move-left)
         ("C-S-<right>" . buf-move-right))
  )

(use-package vertico
  	:ensure t
  	:demand t
  	:bind (:map vertico-map
  		    ("C-j" . vertico-next)
  		    ("C-k" . vetico-previous)
  		    ("C-f" . vertico-exit)
  		    :map minibuffer-local-map
  		    ("M-h" . backward-kill-word))
  	:custom
  	(vertico-cycle t)
  	:init
  	(vertico-mode))

  (use-package savehist
  	:init
  	(savehist-mode))

  ;; A few more useful configurations...
(use-package emacs
  :custom
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  ;; Emacs 28 and newer: Hide commands in M-x which do not work in the current
  ;; mode.  Vertico commands are hidden in normal buffers. This setting is
  ;; useful beyond Vertico.
  (read-extended-command-predicate #'command-completion-default-include-p)
  :init
  ;; Add prompt indicator to `completing-read-multiple'.
  ;; We display [CRM<separator>], e.g., [CRM,] if the separator is a comma.
  (defun crm-indicator (args)
    (cons (format "[CRM%s] %s"
                  (replace-regexp-in-string
                   "\\`\\[.*?]\\*\\|\\[.*?]\\*\\'" ""
                   crm-separator)
                  (car args))
          (cdr args)))
  (advice-add #'completing-read-multiple :filter-args #'crm-indicator)

  ;; Do not allow the cursor in the minibuffer prompt
  (setq minibuffer-prompt-properties
        '(read-only t cursor-intangible t face minibuffer-prompt))
  (add-hook 'minibuffer-setup-hook #'cursor-intangible-mode))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package corfu
    :ensure t
  ;; Optional customizations
    :custom
    (corfu-cycle t)                ;; Enable cycling for `corfu-next/previous'
    (corfu-auto t)                 ;; Enable auto completion
    (corfu-separator ?\s)          ;; Orderless field separator
    (corfu-auto-prefix 2)
    (corfu-auto-delay 0.0)
    (corfu-quit-at-boundary 'separator)
    (corfu-preview-current 'insert)
    (corfu-preselect-first nil)
  ;; (corfu-quit-no-match nil)      ;; Never quit, even if there is no match
  ;; (corfu-preview-current nil)    ;; Disable current candidate preview
  ;; (corfu-preselect 'prompt)      ;; Preselect the prompt
  ;; (corfu-on-exact-match nil)     ;; Configure handling of exact matches
  ;; (corfu-scroll-margin 5)        ;; Use scroll margin

  ;; Enable Corfu only for certain modes.
  ;; :hook ((prog-mode . corfu-mode)
  ;;        (shell-mode . corfu-mode)
  ;;        (eshell-mode . corfu-mode))

  ;; Recommended: Enable Corfu globally.  This is recommended since Dabbrev can
  ;; be used globally (M-/).  See also the customization variable
  ;; `global-corfu-modes' to exclude certain modes.
  :init
  (global-corfu-mode)
  (corfu-history-mode)
  (corfu-popupinfo-mode))

;; A few more useful configurations...
(use-package emacs
  :custom
  ;; TAB cycle if there are only few candidates
  ;; (completion-cycle-threshold 3)

  ;; Enable indentation+completion using the TAB key.
  ;; `completion-at-point' is often bound to M-TAB.
  (tab-always-indent 'complete)

  ;; Emacs 30 and newer: Disable Ispell completion function. As an alternative,
  ;; try `cape-dict'.
  (text-mode-ispell-word-completion nil)

  ;; Emacs 28 and newer: Hide commands in M-x which do not apply to the current
  ;; mode.  Corfu commands are hidden, since they are not used via M-x. This
  ;; setting is useful beyond Corfu.
  ;;(read-extended-command-predicate #'command-completion-default-include-p)
  )

;; Enable rich annotations using the Marginalia package
(use-package marginalia  
  :after vertico
  :ensure t
  ;; Bind `marginalia-cycle' locally in the minibuffer.  To make the binding
  ;; available in the *Completions* buffer, add it to the
  ;; `completion-list-mode-map'.
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))
  :custom
  (marginalia-annotators '(marginalia-annotators-heavy marginalia-annotators-light nil))
  :init
  (marginalia-mode))

(use-package consult
  :ensure t
  :after vertico
  :after orderless
  ;; Replace bindings. Lazily loaded due by `use-package'.
  :bind (;; C-c bindings in `mode-specific-map'
         ("C-c M-x" . consult-mode-command)
         ("C-c h" . consult-history)
         ("C-c k" . consult-kmacro)
         ("C-c m" . consult-man)
         ("C-c i" . consult-info)
         ([remap Info-search] . consult-info)
         ;; C-x bindings in `ctl-x-map'
         ("C-x M-:" . consult-complex-command)     ;; orig. repeat-complex-command
         ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
         ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
         ("C-x 5 b" . consult-buffer-other-frame)  ;; orig. switch-to-buffer-other-frame
         ("C-x t b" . consult-buffer-other-tab)    ;; orig. switch-to-buffer-other-tab
         ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
         ("C-x p b" . consult-project-buffer)      ;; orig. project-switch-to-buffer
         ;; Custom M-# bindings for fast register access
         ("M-#" . consult-register-load)
         ("M-'" . consult-register-store)          ;; orig. abbrev-prefix-mark (unrelated)
         ("C-M-#" . consult-register)
         ;; Other custom bindings
         ("M-y" . consult-yank-pop)                ;; orig. yank-pop
         ;; M-g bindings in `goto-map'
         ("M-g e" . consult-compile-error)
         ("M-g f" . consult-flymake)               ;; Alternative: consult-flycheck
         ("M-g g" . consult-goto-line)             ;; orig. goto-line
         ("M-g M-g" . consult-goto-line)           ;; orig. goto-line
         ("M-g o" . consult-outline)               ;; Alternative: consult-org-heading
         ("M-g m" . consult-mark)
         ("M-g k" . consult-global-mark)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ;; M-s bindings in `search-map'
         ("M-s d" . consult-find)                  ;; Alternative: consult-fd
         ("M-s c" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history)         ;; orig. isearch-edit-string
         ("M-s e" . consult-isearch-history)       ;; orig. isearch-edit-string
         ("M-s l" . consult-line)                  ;; needed by consult-line to detect isearch
         ("M-s L" . consult-line-multi)            ;; needed by consult-line to detect isearch
         ;; Minibuffer history
         :map minibuffer-local-map
         ("M-s" . consult-history)                 ;; orig. next-matching-history-element
         ("M-r" . consult-history))                ;; orig. previous-matching-history-element

  ;; Enable automatic preview at point in the *Completions* buffer. This is
  ;; relevant when you use the default completion UI.
  :hook (completion-list-mode . consult-preview-at-point-mode)

  ;; The :init configuration is always executed (Not lazy)
  :init

  ;; Optionally configure the register formatting. This improves the register
  ;; preview for `consult-register', `consult-register-load',
  ;; `consult-register-store' and the Emacs built-ins.
  (setq register-preview-delay 0.5
        register-preview-function #'consult-register-format)

  ;; Optionally tweak the register preview window.
  ;; This adds thin lines, sorting and hides the mode line of the window.
  (advice-add #'register-preview :override #'consult-register-window)

  ;; Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  ;; Configure other variables and modes in the :config section,
  ;; after lazily loading the package.
  :config

  ;; Optionally configure preview. The default value
  ;; is 'any, such that any key triggers the preview.
  ;; (setq consult-preview-key 'any)
  ;; (setq consult-preview-key "M-.")
  ;; (setq consult-preview-key '("S-<down>" "S-<up>"))
  ;; For some commands and buffer sources it is useful to configure the
  ;; :preview-key on a per-command basis using the `consult-customize' macro.
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file consult-xref
   consult--source-bookmark consult--source-file-register
   consult--source-recent-file consult--source-project-recent-file
   ;; :preview-key "M-."
   :preview-key '(:debounce 0.4 any))

  ;; Optionally configure the narrowing key.
  ;; Both < and C-+ work reasonably well.
  (setq consult-narrow-key "<") ;; "C-+"
  )

(use-package embark
  :ensure t
  :bind
  (("C-." . embark-act)         ;; pick some comfortable binding
   ("C-;" . embark-dwim)        ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'

  :init

  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)

  ;; Show the Embark target at point via Eldoc. You may adjust the
  ;; Eldoc strategy, if you want to see the documentation from
  ;; multiple providers. Beware that using this can be a little
  ;; jarring since the message shown in the minibuffer can be more
  ;; than one line, causing the modeline to move up and down:

  ;; (add-hook 'eldoc-documentation-functions #'embark-eldoc-first-target)
  ;; (setq eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)

  :config

  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

;; Consult users will also want the embark-consult package.
(use-package embark-consult
  :ensure t ; only need to install it, embark loads it after consult if found
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

(use-package dashboard
  :ensure t
  :after projectile
  :after nerd-icons
  :after page-break-lines
  :init
  (setq initial-buffer-choice 'dashboard-open)
  (setq dashboard-set-heading-icons t)
  (setq dashboard-set-file-icons t)
  (setq dashboard-display-icons-p t)     ; display icons on both GUI and terminal
  (setq dashboard-icon-type 'nerd-icons) ; use `nerd-icons' package
  (setq dashboard-banner-logo-title "Emacs Dashboard")
  (setq dashboard-startup-banner 'logo)
  (setq dashboard-center-content t)
  (setq dashboard-vertically-center-content t)
  (setq dashboard-navigation-cycle nil)
  (setq dashboard-startupify-list '(dashboard-insert-banner
                                    dashboard-insert-newline
                                    dashboard-insert-banner-title
				    dashboard-insert-newline 
				    dashboard-insert-page-break
				    dashboard-insert-newline
                                    dashboard-insert-navigator
                                    dashboard-insert-newline
                                    dashboard-insert-init-info
                                    dashboard-insert-items
                                    dashboard-insert-newline
				    dashboard-insert-page-break
				    dashboard-insert-newline
                                    dashboard-insert-footer))
  (setq dashboard-items '((recents . 5)
			  (agenda . 5)
			  (bookmarks . 3)
			  (projects . 3)
			  (registers . 3)))
  (setq dashboard-modify-heading-icons '((recents   . "nf-oct-file_text")
					 (bookmarks . "nf-oct-book")))

  :config
  (add-hook 'elpaca-after-init-hook #'dashboard-insert-startupify-lists)
  (add-hook 'elpaca-after-init-hook #'dashboard-initialize)
  (dashboard-setup-startup-hook))

(use-package dired-open
  :ensure t
  :config
  (setq dired-open-extentions '(("gif" . "sxiv")
				("jpg" . "sxiv")
				("jpeg" . "sxiv")
				("png" . "sxiv")
				("ppm" . "sxiv")
				("mp4" . "mpv")
				("mkv" . "mpv"))))

(use-package dired-preview
  :ensure t
  :after dired
   :bind ( 
   ("C-<down>" . dired-next-line)
   ("C-<up>" .  dired-previous-line))
  :init
  (dired-preview-global-mode)
  :config
  (setq dired-preview-delay 0.2)
  (setq dired-preview-max-size (expt 2 20))
  (setq dired-preview-ignored-extensions-regexp
        (concat "\\."
                "\\(mkv\\|webm\\|mp4\\|mp3\\|ogg\\|m4a"
                "\\|gz\\|zst\\|tar\\|xz\\|rar\\|zip"
                "\\|iso\\|epub\\)"))

  )

(use-package treemacs
  :ensure (:wait t)
  :defer t
  :init
  (with-eval-after-load 'winum
    (define-key winum-keymap (kbd "M-0") #'treemacs-select-window))
  :config
  (progn
    ;; The default width and height of the icons is 22 pixels. If you are
    ;; using a Hi-DPI display, uncomment this to double the icon size.
    ;;(treemacs-resize-icons 44)
    (treemacs-follow-mode t)
    (treemacs-filewatch-mode t)
    (treemacs-fringe-indicator-mode 'always)
    (when treemacs-python-executable
      (treemacs-git-commit-diff-mode t))

    (pcase (cons (not (null (executable-find "git")))
                 (not (null treemacs-python-executable)))
      (`(t . t)
       (treemacs-git-mode 'deferred))
      (`(t . _)
       (treemacs-git-mode 'simple)))

    ;;(treemacs-hide-gitignored-files-mode nil)
   )
  :bind
  (:map global-map
        ("M-0"       . treemacs-select-window)
        ("C-x t 1"   . treemacs-delete-other-windows)
        ("C-x t t"   . treemacs)
        ("C-x t d"   . treemacs-select-directory)
        ("C-x t B"   . treemacs-bookmark)
        ("C-x t C-t" . treemacs-find-file)
        ("C-x t M-t" . treemacs-find-tag)))

(use-package treemacs-evil
  :after (treemacs evil)
  :ensure t)

(use-package treemacs-projectile
  :after (treemacs projectile)
  :ensure t)

(use-package treemacs-icons-dired
  :hook (dired-mode . treemacs-icons-dired-enable-once)
  :ensure t)

(use-package treemacs-nerd-icons
  :ensure t
  :after (treemacs nerd-icons)
  :config
  (treemacs-load-theme "nerd-icons"))

;; (use-package treemacs-magit
;;   :after (treemacs magit)
;;   :ensure t)

;; (use-package treemacs-persp ;;treemacs-perspective if you use perspective.el vs. persp-mode
;;   :after (treemacs persp-mode) ;;or perspective vs. persp-mode
;;   :ensure t
;;   :config (treemacs-set-scope-type 'Perspectives))

;; (use-package treemacs-tab-bar ;;treemacs-tab-bar if you use tab-bar-mode
;;   :after (treemacs)
;;   :ensure t
;;   :config (treemacs-set-scope-type 'Tabs))

;;(treemacs-start-on-boot)

(set-face-attribute 'default nil
                     :font "Fira Code Retina"
                     :height 140
                     :weight 'medium)
 (set-face-attribute 'variable-pitch nil
                     :font "Cantarell"
                     :height 160
                     :weight 'medium)
 (set-face-attribute 'fixed-pitch nil
                     :font "Fira Code Retina"
                     :height 140
                     :weight 'medium)
;;Makes commented text and keywords italics
;;This is working in emacsclient but not emacs
;;Your font must have an italic face available
(set-face-attribute 'font-lock-comment-face nil
                    :slant 'italic)
(set-face-attribute 'font-lock-keyword-face nil
                    :slant 'italic)

;;To get the deault font in emacsclient - uncomment if needed
;;(add-to-list 'default-frame-list '(font . "Fira Code Retina"))

;; Line spacing adjustment
;; (setq-default line-spacing 0.12)

(global-set-key (kbd "C-=") 'text-scale-increase)
(global-set-key (kbd "C--") 'text-scale-decrease)
(global-set-key (kbd "<C-wheel-up>") 'text-scale-increase)
(global-set-key (kbd "<C-wheel-down>") 'text-scale-decrease)

(use-package rainbow-delimiters
:ensure t
:hook (prog-mode . rainbow-delimiters-mode))

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

;; Set margins?
(set-fringe-mode 10)

;;Turn off tooltips
(tooltip-mode -1)

;;Enable column numbers in the panel
(column-number-mode)

;;Enable line numbers
(global-display-line-numbers-mode t)
(global-visual-line-mode t)

;;Hide line numbers in some modes
(dolist (mode '(org-mode-hook
              term-mode-hook
              shell-mode-hook
              eshell-mode-hook))
(add-hook mode (lambda() (display-line-numbers-mode 0))))

(use-package page-break-lines
  :ensure t
  :diminish
  :config
  (page-break-lines-mode 1))

(add-to-list 'default-frame-alist '(alpha-background . 90))

(use-package all-the-icons
    :ensure t)

  (use-package dired-subtree
    :ensure t
    :config
    (advice-add 'dired-subtree-toggle :after (lambda () 
  					     (interactive)
  					     (when nerd-icons-dired-mode
  					       (revert-buffer)))))

  (use-package nerd-icons
    :ensure t)

(use-package nerd-icons-dired
:ensure t
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package pdf-tools
  :ensure t
  :config
  (setq-default pdf-view-display-size 'fit-width)
  )

(use-package flycheck
  :ensure t
  :defer t
  :diminish
  :init (global-flycheck-mode)
  )

(use-package lsp-pyright
:ensure t
)

(use-package lsp-mode
  :ensure t
  :commands (lsp lsp-deferred)
  :init
  (setq lsp-keymap-prefix "C-l")
  :hook ((c-mode . lsp-deferred)
	 (c-ts-mode . lsp-deferred)
	 (c++-mode . lsp-deferred)
	 (c++-ts-mode . lsp-deferred)
	 (typescript-ts-mode . lsp-deferred)
	 (js-ts-mode . lsp-deferred)
	 (python-mode . lsp-deferred)
	 (python-ts-mode . lsp-deferred)
	 )
  :config
  (setq lsp-enable-which-key-integration 1)
     
  )

(use-package consult-lsp
  :ensure t
  :after lsp
  :after consult
  :commands (consult-lsp-symbols
	     consult-lsp-file-symbols
	     consult-lsp-diagnostics)
  )

(use-package treesit-auto
  :ensure t
  :config
  (treesit-auto-add-to-auto-mode-alist 'all))

(defun pec/org-mode-setup ()
   (org-indent-mode 1)
   (variable-pitch-mode 1)
   (visual-line-mode 1))

(use-package org
   :ensure (:wait t)
   :hook (org-mode . pec/org-mode-setup)
   :config
   (setq org-ellipsis " ▼"))

 (with-eval-after-load 'org-faces
     (dolist (face '((org-level-1 . 1.2)
                       (org-level-2 . 1.1)	
                       (org-level-3 . 1.05)
                       (org-level-4 . 1.0)	
                       (org-level-5 . 1.1)	
                       (org-level-6 . 1.1)	
                       (org-level-7 . 1.1)	
                       (org-level-8 . 1.1)))	
       (set-face-attribute (car face) nil :font "Cantarell" :weight 'regular :height (cdr face)))
 
       (setq org-startup-indented 1)
       (set-face-attribute 'org-block nil :foreground nil :inherit 'fixed-pitch)
       (set-face-attribute 'org-code nil :inherit '(shadow fixed-pitch))
       (set-face-attribute 'org-table nil :inherit '(shadow fixed-pitch))
       ;;(set-face-attribute 'org-indent nil :inherit '(org-hide fixed-pitch))
       (with-eval-after-load 'org-indent
         (set-face-attribute 'org-indent nil :inherit '(org-hide fixed-pitch)))
       (set-face-attribute 'org-verbatim nil :inherit '(shadow fixed-pitch))
       (set-face-attribute 'org-special-keyword nil :inherit '(font-lock-comment-face fixed-pitch))
       (set-face-attribute 'org-meta-line nil :inherit '(font-lock-comment-face fixed-pitch))
       (set-face-attribute 'org-checkbox nil :inherit 'fixed-pitch)
     )


 (defun pec/org-mode-visual-fill ()
   (setq visual-fill-column-width 100
         visual-fill-column-center-text t)
         (visual-fill-column-mode 1))

 (use-package visual-fill-column
   :ensure t
   :after org
   :hook (org-mode . pec/org-mode-visual-fill))

(use-package org-bullets
  :ensure t
  :after org
  :hook (org-mode . org-bullets-mode)
  :custom
  (org-bullets-bullet-list '("◉" "○" "●" "○" "●" "○" "●")))

(org-babel-do-load-languages
  'org-babel-load-languages
  '((emacs-lisp . t)
    (python . t)))

 (require 'org-tempo)

(add-to-list 'org-structure-template-alist '("sh" . "src shell"))
(add-to-list 'org-structure-template-alist '("elt" . "src emacs-lisp :tangle \"init.el\" "))
(add-to-list 'org-structure-template-alist '("el" . "src emacs-lisp"))
(add-to-list 'org-structure-template-alist '("py" . "src python"))

(electric-indent-mode 1)

(use-package eshell-syntax-highlighting
  :after esh-mode
  :config
  (eshgell-syntax-highlighting-global-mode +1))

(setq eshell-rc-script (concat user-emacs-directory "eshell/profile")
      eshell-aliases-file (concat user-emacs-directory "eshell/aliases")
      eshell-history-size 5000
      eshell-buffer-maximum-lines 5000
      eshell-hist-ignoreups t
      eshell-scroll-to-bottom-on-input t
      eshell-destroy-buffer-when-process-dies t
      eshell-visual-commands'("bash" "fish" "htop" "ssh" "top" "zsh"))

(use-package vterm
  :ensure t
  :config
  (setq shell-file-name "/bin/bash"
        vterm-max-scrollback 5000))

(use-package vterm-toggle
  :ensure t
  :config
  (setq vterm-toggle-fullscreen-p nil)
  (setq vterm-toggle-scope 'project)
  (add-to-list 'display-buffer-alist
               '((lambda (buffer-or-name _)
                   (let ((buffer (get-buffer buffer-or-name)))
                     (with-current-buffer buffer
                       (or (equal major-mode 'vterm-mode)
                           (string-prefix-p vterm-buffer-name (buffer-name buffer))))))
                 (display-buffer-reuse-window display-buffer-at-bottom)
                 (reusable-frames . visible)
                 (window-height . 0.3))))

(use-package sudo-edit
  :ensure t
  :config
  (pec/leader-keys
   "f u" '(sudo-edit-find-file :wk "Sudo find file")
   "f U" '(sudo-edit :wk "Sudo edit file")))

(use-package doom-modeline
  :ensure t
  :init (doom-modeline-mode 1)
  :custom ((doom-modeline-height 15)))

(use-package doom-themes
  :ensure t
  :demand t
  :config
  (setq doom-themes-enable-bold t
      doom-themes-enable-italic t)
  (load-theme 'doom-rouge t)
  (doom-themes-treemacs-config)
  (setq doom-themes-treemacs-theme "doom-color")
  (doom-themes-org-config))

(use-package solaire-mode
  :ensure t
  :init (solaire-global-mode 1)
  )

(use-package which-key
  :ensure t
  :init
  (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-side-window-location 'bottom
	  which-key-sort-order #'which-key-key-order-alpha
	  which-key-sort-uppercase-first nil
	  which-key-add-column-padding 1
	  which-key-min-display-lines 6
	  which-key-side-window-slot -10
	  which-key-side-window-max-height 0.25
	  which-key-mode-delay 0.8
	  which-key-max-description-length 25
	  which-key-allow-imprecise-window-fit nil
	  which-key-separator " → "))
