;; Disabling inbuilt packages for Elpaca
(setq package-enable-at-startup nil)

;; Every file opened and loaded by Emacs will run through this list to check for
;; a proper handler for the file, but during startup, it won’t need any of them.
;; This is reset in posimacs-init.el after `elpaca-after-init-hook' it is reset
;; to the original value.
(defvar file-name-handler-alist--old file-name-handler-alist)

;; https://www.reddit.com/r/emacs/comments/3kqt6e/2_easy_little_known_steps_to_speed_up_emacs_start/
;; Note, `gcmh' package will modify this later, so we don't reset it.
(setq gc-cons-threshold most-positive-fixnum
      file-name-handler-alist nil)

;; Use the no-littering var directory for elisp native compile cache
(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (convert-standard-filename
        (expand-file-name  "var/eln-cache/" user-emacs-directory))))

;; Turn off graphics features that would slow down initial startup.
;; https://github.com/Gavinok/emacs.d  
(setq frame-resize-pixelwise t
      frame-inhibit-implied-resize t
      frame-title-format '("%b")
      ring-bell-function 'ignore
      use-dialog-box t 
      use-file-dialog nil
      use-short-answers t
      inhibit-splash-screen t
      inhibit-startup-screen t
      inhibit-x-resources t
      inhibit-startup-echo-area-message user-login-name 
      inhibit-startup-buffer-menu t
      package-native-compile t
      default-frame-alist
      '((tool-bar-lines . 0)
        (menu-bar-lines . 0)
        ;;(undecorated . t)
        (vertical-scroll-bars . nil)
        (horizontal-scroll-bars . nil)))
