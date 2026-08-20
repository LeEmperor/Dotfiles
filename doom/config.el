;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq doom-theme 'doom-solarized-light)
(setq display-line-numbers-type 'relative)
(setq-default tab-width 2
              indent-tabs-mode nil
              ;; `tab-to-tab-stop' uses this instead of a mode's inferred
              ;; indentation width.  The last interval repeats indefinitely.
              tab-stop-list '(2 4))

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Give minibuffer completion UIs (including Vertico) Evil states.  This must
;; be set before evil-collection initializes.
(setq evil-collection-setup-minibuffer t)

;; `evil-collection-mode-list' is assembled before this file is loaded, so
;; initialize these integrations explicitly after enabling minibuffer support.
(after! evil-collection
  (evil-collection-init '(minibuffer vertico)))

(after! evil-escape
  (setq evil-escape-key-sequence "jk"
        evil-escape-delay 0.20
        ;; Doom normally excludes terminal buffers from evil-escape.  Ghostel's
        ;; Evil integration supports normal mode, so allow `jk' there as well.
        evil-escape-excluded-major-modes
        (delq 'ghostel-mode evil-escape-excluded-major-modes)))

(defvar my/ghostel-last-slot 1
  "Most recently selected numbered Ghostel terminal.")

(defvar my/ghostel-slot-buffers (make-hash-table :test #'eql)
  "Ghostel buffers indexed by terminal slot number.")

(defun my/ghostel--root-frame (&optional frame)
  "Return the top-level parent of FRAME."
  (let ((frame (or frame (selected-frame)))
        parent)
    (while (setq parent (frame-parameter frame 'parent-frame))
      (setq frame parent))
    frame))

(defun my/ghostel--posframe (buffer)
  "Return BUFFER's Posframe child frame, when it has one."
  (when (buffer-live-p buffer)
    (let ((frame (buffer-local-value 'posframe--frame buffer)))
      (and (frame-live-p frame) frame))))

(defun my/ghostel--hide-other-posframes (except)
  "Hide numbered terminal Posframes other than EXCEPT."
  (maphash (lambda (_slot buffer)
             (when (and (buffer-live-p buffer)
                        (not (eq buffer except)))
               (posframe-hide buffer)))
           my/ghostel-slot-buffers))

(defun my/ghostel--show-posframe (buffer parent-frame)
  "Show BUFFER in a centered, focused child frame of PARENT-FRAME."
  (let (child-frame old-window)
    (with-selected-frame parent-frame
      ;; Clean up any ordinary window left by an older configuration after the
      ;; same buffer has been placed in its child frame.
      (setq old-window (get-buffer-window buffer parent-frame))
      (setq child-frame
            (posframe-show
             buffer
             :poshandler #'posframe-poshandler-frame-center
             :width (floor (* 0.72 (frame-width parent-frame)))
             :height (floor (* 0.62 (frame-height parent-frame)))
             :left-fringe 8
             :right-fringe 8
             :border-width 2
             :cursor t
             :lines-truncate t
             :accept-focus t
             :window-point (with-current-buffer buffer (point))))
      (when (window-live-p old-window)
        (quit-window nil old-window)))
    (when (frame-live-p child-frame)
      (select-frame-set-input-focus child-frame)
      (select-window (frame-root-window child-frame)))))

(defun my/ghostel-send-space ()
  "Send one literal space to the active Ghostel terminal."
  (interactive)
  (ghostel-send-string " "))

(defun my/ghostel-toggle (arg)
  "Toggle centered Ghostel terminal ARG, or the last selected terminal.

With a positive numeric prefix ARG, remember and toggle that terminal slot.
Without ARG, toggle the most recently selected slot."
  (interactive "P")
  (require 'ghostel)
  (require 'posframe)
  (when (numberp arg)
    (unless (> arg 0)
      (user-error "Terminal number must be positive"))
    (setq my/ghostel-last-slot arg))
  (let* ((slot my/ghostel-last-slot)
         (parent-frame (my/ghostel--root-frame))
         (buffer (gethash slot my/ghostel-slot-buffers))
         (child-frame (and (buffer-live-p buffer)
                           (my/ghostel--posframe buffer))))
    (if (and child-frame (frame-visible-p child-frame))
        (progn
          (posframe-hide buffer)
          (when (frame-live-p parent-frame)
            (select-frame-set-input-focus parent-frame)))
      (my/ghostel--hide-other-posframes buffer)
      (unless (buffer-live-p buffer)
        (with-selected-frame parent-frame
          (dlet ((ghostel-buffer-name "*doom:ghostel-popup*"))
            ;; `ghostel' normally displays a new buffer before initializing it.
            ;; Suppress that intermediate display; the initialized buffer is
            ;; placed directly into its Posframe immediately below.
            (cl-letf (((symbol-function 'pop-to-buffer)
                       (lambda (&rest _args) (selected-window))))
              (setq buffer (ghostel slot)))))
        (puthash slot buffer my/ghostel-slot-buffers))
      (my/ghostel--show-posframe buffer parent-frame))))

(map! :leader
      :desc "Toggle numbered terminal"
      "/" #'my/ghostel-toggle)

(after! evil-ghostel
  ;; Make SPC / available while the terminal is in insert state.  Other Space
  ;; sequences fall through to the terminal, so ordinary shell input still
  ;; receives its spaces.
  (evil-define-key* 'insert evil-ghostel-mode-map
    (kbd "SPC")
    (general-key-dispatch 'my/ghostel-send-space
      :timeout 0.4
      "/" 'my/ghostel-toggle))

  ;; Ghostel normally reserves C-c as a prefix, making an interrupt C-c C-c,
  ;; and evil-ghostel forwards C-y to the shell's line editor.  In insert state
  ;; use conventional terminal/Emacs behavior instead: one C-c interrupts and
  ;; the common paste keys send the clipboard/kill-ring text through Ghostel's
  ;; bracketed-paste path.  Ghostel's C-c prefix remains available from normal
  ;; state for its less common terminal commands.
  (evil-define-key* 'insert evil-ghostel-mode-map
    (kbd "C-c") #'ghostel-send-C-c
    (kbd "C-y") #'ghostel-yank
    (kbd "C-S-v") #'ghostel-yank
    (kbd "S-<insert>") #'ghostel-yank)

  ;; Evil normal state should behave like Vim's terminal-normal mode: freeze
  ;; the rendered terminal and make its entire retained scrollback an ordinary
  ;; navigable buffer.  Without this, evil-ghostel intentionally keeps motions
  ;; such as `j' and `G' attached to the live shell prompt while Ghostel remains
  ;; in semi-char input mode.
  (defun my/ghostel-enter-normal-browse-mode-h ()
    "Enter Ghostel copy mode when switching a shell to Evil normal state."
    (when (and (derived-mode-p 'ghostel-mode)
               (bound-and-true-p ghostel--term)
               (not (ghostel-alt-screen-p))
               (not (eq ghostel--input-mode 'copy)))
      (ghostel-copy-mode)))

  (defun my/ghostel-resume-input-on-insert-h ()
    "Resume Ghostel terminal input when returning to Evil insert state."
    (when (and (derived-mode-p 'ghostel-mode)
               (eq ghostel--input-mode 'copy))
      (ghostel-readonly-exit)))

  (add-hook 'evil-normal-state-entry-hook
            #'my/ghostel-enter-normal-browse-mode-h)
  (add-hook 'evil-insert-state-entry-hook
            #'my/ghostel-resume-input-on-insert-h))

(after! ghostel
  ;; Ghostel's default is 5 MiB (roughly 5,000 typical 80-column rows).
  ;; Keep a ToggleTerm-like amount of longer-lived history.  This value is
  ;; allocated when a terminal is created, so existing terminals retain the
  ;; size with which they were started.
  (setq ghostel-max-scrollback (* 20 1024 1024)))

(define-minor-mode my/floating-scratch-mode
  "Mark Doom's persistent scratch buffer as the floating scratchpad."
  :init-value nil
  :lighter nil
  :keymap (make-sparse-keymap))

(defun my/floating-scratch--root-frame (&optional frame)
  "Return the top-level parent of FRAME."
  (let ((frame (or frame (selected-frame)))
        parent)
    (while (setq parent (frame-parameter frame 'parent-frame))
      (setq frame parent))
    frame))

(defun my/floating-scratch--frame (buffer)
  "Return BUFFER's Posframe child frame, when it has one."
  (when (buffer-live-p buffer)
    (let ((frame (buffer-local-value 'posframe--frame buffer)))
      (and (frame-live-p frame) frame))))

(defun my/floating-scratch-toggle ()
  "Toggle Doom's persistent scratch buffer in a centered child frame."
  (interactive)
  (require 'posframe)
  (let* ((parent-frame (my/floating-scratch--root-frame))
         (buffer (get-buffer "*doom:scratch*"))
         (child-frame (my/floating-scratch--frame buffer)))
    (if (and child-frame (frame-visible-p child-frame))
        (progn
          (with-current-buffer buffer
            (doom-persist-scratch-buffer-h))
          (posframe-hide buffer)
          (when (frame-live-p parent-frame)
            (select-frame-set-input-focus parent-frame)))
      (unless (buffer-live-p buffer)
        (with-selected-frame parent-frame
          (setq buffer
                (doom-scratch-buffer
                 nil
                 (doom--scratch-buffer-initial-mode)
                 default-directory))))
      (with-current-buffer buffer
        (my/floating-scratch-mode +1))
      (let (child-frame old-window)
        (with-selected-frame parent-frame
          (setq old-window (get-buffer-window buffer parent-frame))
          (setq child-frame
                (posframe-show
                 buffer
                 :poshandler #'posframe-poshandler-frame-center
                 :width (floor (* 0.72 (frame-width parent-frame)))
                 :height (floor (* 0.62 (frame-height parent-frame)))
                 :left-fringe 8
                 :right-fringe 8
                 :border-width 2
                 :cursor t
                 :lines-truncate nil
                 :respect-mode-line t
                 :accept-focus t
                 :window-point (with-current-buffer buffer (point))))
          (when (window-live-p old-window)
            (quit-window nil old-window)))
        (when (frame-live-p child-frame)
          (select-frame-set-input-focus child-frame)
          (select-window (frame-root-window child-frame)))))))

(map! :leader
      :desc "Toggle floating scratchpad"
      "[" #'my/floating-scratch-toggle)

(after! evil
  ;; Preserve ordinary spaces while making SPC [ available from insert state
  ;; inside the floating scratchpad.
  (evil-define-key* 'insert my/floating-scratch-mode-map
    (kbd "SPC")
    (general-key-dispatch 'self-insert-command
      :timeout 0.4
      "[" 'my/floating-scratch-toggle)))

(map! :leader
        :desc "Save current buffer"
        "w" #'save-buffer)

(map! :i
    "TAB" #'tab-to-tab-stop
    [tab] #'tab-to-tab-stop)

(map! :n
    :desc "Previous tab" "H" #'+tabs:previous-or-goto
    :desc "Next tab"     "L" #'+tabs:next-or-goto)

;; Cycle the visible buffer tabs in the selected window only.  This matches
;; Neovim's per-split buffer navigation: the buffer displayed by neighboring
;; windows is not changed.  SPC h intentionally replaces Doom's help prefix;
;; help remains available from C-h.
(map! :leader
    :desc "Previous tab in window" "h" #'+tabs:previous-or-goto
    :desc "Next tab in window"     "l" #'+tabs:next-or-goto)

(map! :leader
    :desc "Dismiss popup/window" "q" #'quit-window
    :desc "Quit Emacs"           "Q" #'save-buffers-kill-terminal)

(defun my/kill-buffer-to-directory ()
  "Kill the current buffer and show its directory in the same window.

For buffers that do not visit a file, use `default-directory'.  When called
from Dired, simply kill that Dired buffer instead of reopening it."
  (interactive)
  (if (derived-mode-p 'dired-mode)
      (kill-current-buffer)
    (let ((buffer (current-buffer))
          (window (selected-window))
          (directory (if buffer-file-name
                         (file-name-directory buffer-file-name)
                       default-directory)))
      ;; `kill-buffer' may ask about unsaved changes or a running process.  Do
      ;; not replace the buffer when the user declines to kill it.
      (when (kill-buffer buffer)
        (when (window-live-p window)
          (select-window window)
          (dired directory))))))

(map! :leader
      :desc "Close buffer to directory"
      "x" #'my/kill-buffer-to-directory)

;; Prefer the recursive, Orderless-filtered project picker over the built-in
;; path-oriented `find-file' prompt.  The latter remains available on SPC .
(map! :leader
      :desc "Find file in project"
      "f f" #'projectile-find-file)

(map! :n
    :desc "Scroll window down" "C-j" #'evil-scroll-line-down
    :desc "Scroll window up"   "C-k" #'evil-scroll-line-up)

(use-package! pulsar
:config
(setq pulsar-delay 0.055
        pulsar-iterations 10)
(pulsar-global-mode 1))

;; Show Doom's keybinding hints in a centered child frame instead of a
;; full-width popup at the bottom of the current frame.
(setq which-key-idle-delay 0.4)

(use-package! which-key-posframe
  :after which-key
  :config
  (setq which-key-posframe-poshandler #'posframe-poshandler-frame-center
        which-key-posframe-border-width 2
        which-key-posframe-parameters
        '((left-fringe . 8)
          (right-fringe . 8)
          (no-accept-focus . t)))
  (which-key-posframe-mode 1))

(map! :leader
      :desc "Show top-level keymap"
      "?" #'which-key-show-top-level)

(defun my/open-doom-config ()
  "Open the personal Doom config.el."
  (interactive)
  (find-file (expand-file-name "config.el" doom-user-dir)))

(defun my/open-doom-init ()
  "Open the personal Doom init.el."
  (interactive)
  (find-file (expand-file-name "init.el" doom-user-dir)))

(defun my/open-doom-packages ()
  "Open the personal Doom packages.el."
  (interactive)
  (find-file (expand-file-name "packages.el" doom-user-dir)))

(defun my/open-shell-config ()
  "Open the main interactive Bash configuration."
  (interactive)
  (find-file (expand-file-name "~/.bash_configs")))

(map! :leader
      (:prefix ("e" . "edit config")
       :desc "Doom config.el"   "c" #'my/open-doom-config
       :desc "Doom init.el"     "i" #'my/open-doom-init
       :desc "Doom packages.el" "p" #'my/open-doom-packages
       :desc "Bash config"      "b" #'my/open-shell-config
       :desc "Reload Doom"      "r" #'doom/reload)
      :desc "Reload Doom config"
      "r c" #'doom/reload)

;; Use slang-server for Verilog and SystemVerilog buffers.  Emacs uses
;; `verilog-mode' for both, so identify the language as SystemVerilog (which is
;; also a superset of Verilog) when speaking to the server.
(after! eglot
  (let* ((configured-server (getenv "SLANG_SERVER"))
         (local-build (expand-file-name "~/slang-server/build/bin/slang-server"))
         (server (cond
                  ((and configured-server
                        (file-executable-p configured-server))
                   configured-server)
                  ((executable-find "slang-server"))
                  ((file-executable-p local-build) local-build))))
    (when server
      (add-to-list
       'eglot-server-programs
       `((verilog-mode :language-id "systemverilog") . (,server)))
      (add-hook 'verilog-mode-hook #'eglot-ensure))))

(defun my/toggle-lsp-diagnostics ()
  "Toggle the Flycheck diagnostics list in its bottom window."
  (interactive)
  (if-let ((window (get-buffer-window "*Flycheck errors*" (selected-frame))))
      (delete-window window)
    (unless (bound-and-true-p flycheck-mode)
      (user-error "Flycheck is not active in this buffer"))
    (flycheck-list-errors)))

(after! evil
  (evil-ex-define-cmd "lsp" #'my/toggle-lsp-diagnostics)
  (evil-ex-define-cmd "lsp-restart" #'eglot-reconnect))

;; Match the project-root marker used by the Neovim slang-server setup.
(after! projectile
  (add-to-list 'projectile-project-root-files ".slang"))
