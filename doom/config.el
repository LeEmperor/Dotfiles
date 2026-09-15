;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; (setq doom-theme 'doom-solarized-light)
(setq doom-theme 'doom-tokyo-night)
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

(defvar my/ghostel-workspace-last-slots (make-hash-table :test #'eq)
  "Most recently selected Ghostel terminal slot in each workspace.")

(defvar my/ghostel-workspace-slot-buffers (make-hash-table :test #'eq)
  "Numbered Ghostel terminal buffers grouped by Doom workspace.")

(defvar-local my/ghostel-popup-p nil
  "Non-nil when this Ghostel buffer belongs to the floating terminal bank.")

(defvar-local my/ghostel-popup-workspace nil
  "Doom workspace that owns this floating Ghostel buffer.")

(defvar-local my/ghostel-popup-slot nil
  "Numbered terminal slot occupied by this floating Ghostel buffer.")

(defvar-local my/ghostel-popup-parent-frame nil
  "Top-level frame that owns this floating Ghostel buffer's Posframe.")

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

(defvar my/floating-posframe-focus-order (make-hash-table :test #'eq)
  "Floating buffers ordered most-recent-first for each top-level frame.")

(defvar my/floating-posframe-focus-timer nil
  "Timer used to debounce floating Posframe focus restoration.")

(defun my/floating-posframe--visible-child (parent-frame)
  "Return the most recently active visible child of PARENT-FRAME."
  (catch 'visible
    (dolist (buffer (gethash parent-frame my/floating-posframe-focus-order))
      (when-let* ((child-frame (my/ghostel--posframe buffer))
                  ((frame-visible-p child-frame))
                  ((eq (my/ghostel--root-frame child-frame) parent-frame)))
        (throw 'visible child-frame)))
    nil))

(defun my/floating-posframe--activate (buffer parent-frame child-frame)
  "Register and focus BUFFER's CHILD-FRAME beneath PARENT-FRAME."
  (let ((buffers (gethash parent-frame my/floating-posframe-focus-order)))
    (puthash parent-frame
             (cons buffer (delq buffer buffers))
             my/floating-posframe-focus-order))
  (redirect-frame-focus parent-frame child-frame)
  (select-frame-set-input-focus child-frame)
  (select-window (frame-root-window child-frame)))

(defun my/floating-posframe--deactivate (buffer parent-frame)
  "Unregister BUFFER and update focus redirection for PARENT-FRAME."
  (let ((buffers (gethash parent-frame my/floating-posframe-focus-order)))
    (when (memq buffer buffers)
      (setq buffers (delq buffer buffers))
      (if buffers
          (puthash parent-frame buffers my/floating-posframe-focus-order)
        (remhash parent-frame my/floating-posframe-focus-order))
      (redirect-frame-focus
       parent-frame
       (my/floating-posframe--visible-child parent-frame)))))

(defun my/floating-posframe--restore-focus-h ()
  "Restore focus to an active floating child after an i3 workspace switch."
  (setq my/floating-posframe-focus-timer nil)
  (catch 'restored
    (maphash
     (lambda (parent-frame _buffers)
       (when (and (frame-live-p parent-frame)
                  (eq (frame-focus-state parent-frame) t))
         (when-let* ((child-frame
                      (my/floating-posframe--visible-child parent-frame))
                     ((not (eq (frame-focus-state child-frame) t))))
           (redirect-frame-focus parent-frame child-frame)
           (select-frame-set-input-focus child-frame)
           (select-window (frame-root-window child-frame))
           (throw 'restored t))))
     my/floating-posframe-focus-order)))

(defun my/floating-posframe--schedule-focus-restore-h ()
  "Schedule floating child focus restoration after focus events settle."
  (when (timerp my/floating-posframe-focus-timer)
    (cancel-timer my/floating-posframe-focus-timer))
  (setq my/floating-posframe-focus-timer
        (run-at-time 0.10 nil #'my/floating-posframe--restore-focus-h)))

;; Remove superseded per-popup callbacks when this config is reloaded, then
;; install the shared handler once.
(remove-function after-focus-change-function
                 #'my/ghostel--schedule-focus-restore-h)
(remove-function after-focus-change-function
                 #'my/floating-scratch--schedule-focus-restore-h)
(add-function :after after-focus-change-function
              #'my/floating-posframe--schedule-focus-restore-h)

(defun my/ghostel--workspace (&optional frame)
  "Return the Doom workspace associated with FRAME, or nil."
  (when (bound-and-true-p persp-mode)
    (get-current-persp (or frame (selected-frame)))))

(defun my/ghostel--workspace-slots (workspace)
  "Return the terminal slot table for WORKSPACE, creating it if needed."
  (or (gethash workspace my/ghostel-workspace-slot-buffers)
      (let ((slots (make-hash-table :test #'eql)))
        (puthash workspace slots my/ghostel-workspace-slot-buffers)
        slots)))

(defun my/ghostel--buffer-name (workspace)
  "Return the base Ghostel buffer name for WORKSPACE."
  (format "*doom:ghostel-popup:%s*"
          (if workspace (safe-persp-name workspace) "main")))

(defun my/ghostel--hide-other-posframes (slots except)
  "Hide terminal Posframes in SLOTS other than EXCEPT."
  (maphash (lambda (_slot buffer)
             (when (and (buffer-live-p buffer)
                        (not (eq buffer except)))
               (when-let* ((child-frame (my/ghostel--posframe buffer))
                           ((frame-visible-p child-frame)))
                 (let ((parent-frame (my/ghostel--root-frame child-frame)))
                   (posframe-hide buffer)
                   (my/floating-posframe--deactivate buffer parent-frame)))))
           slots))

(defun my/ghostel--hide-all-posframes-h (&rest _)
  "Hide every numbered terminal Posframe before switching workspaces."
  (maphash (lambda (_workspace slots)
             (my/ghostel--hide-other-posframes slots nil))
           my/ghostel-workspace-slot-buffers))

(when (and (boundp 'my/ghostel-focus-restore-timer)
           (timerp my/ghostel-focus-restore-timer))
  (cancel-timer my/ghostel-focus-restore-timer))
(when (and (boundp 'my/floating-scratch-focus-timer)
           (timerp my/floating-scratch-focus-timer))
  (cancel-timer my/floating-scratch-focus-timer))

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
             :height (floor (* 0.80 (frame-height parent-frame)))
             :left-fringe 16
             :right-fringe 16
             :border-width 6
             :border-color (doom-color 'magenta)
             :cursor t
             :lines-truncate t
             :accept-focus t
             :window-point (with-current-buffer buffer (point))))
      (when (window-live-p old-window)
        (quit-window nil old-window)))
    (when (frame-live-p child-frame)
      (my/floating-posframe--activate buffer parent-frame child-frame))))

(defun my/ghostel--cleanup-popup-h ()
  "Detach the current floating terminal from its slot and Posframe.

This runs before its buffer is killed, so the parent frame never remains
focus-redirected to a child frame that Posframe is about to delete."
  (when my/ghostel-popup-p
    (let* ((buffer (current-buffer))
           (workspace my/ghostel-popup-workspace)
           (slot my/ghostel-popup-slot)
           (parent-frame my/ghostel-popup-parent-frame)
           (slots (gethash workspace my/ghostel-workspace-slot-buffers))
           (child-frame (my/ghostel--posframe buffer))
           (was-visible (and child-frame (frame-visible-p child-frame))))
      (when (and slots (eq (gethash slot slots) buffer))
        (remhash slot slots))
      (when child-frame
        (posframe-hide buffer))
      (when (frame-live-p parent-frame)
        (my/floating-posframe--deactivate buffer parent-frame)
        (when was-visible
          (select-frame-set-input-focus parent-frame))))))

(defun my/ghostel--exit-popup-h (buffer _event)
  "Clean up floating terminal BUFFER when its shell exits."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (my/ghostel--cleanup-popup-h))))

(defun my/ghostel-send-space ()
  "Send one literal space to the active Ghostel terminal."
  (interactive)
  (ghostel-send-string " "))

(defun my/ghostel-toggle (arg)
  "Toggle workspace-local Ghostel terminal ARG, or the last selected one.

With a positive numeric prefix ARG, remember and toggle that terminal slot.
Without ARG, toggle the most recently selected slot in this workspace."
  (interactive "P")
  (require 'ghostel)
  (require 'posframe)
  (let* ((parent-frame (my/ghostel--root-frame))
         (workspace (my/ghostel--workspace parent-frame))
         (slots (my/ghostel--workspace-slots workspace)))
    (when (numberp arg)
      (unless (> arg 0)
        (user-error "Terminal number must be positive"))
      (puthash workspace arg my/ghostel-workspace-last-slots))
    (let* ((slot (gethash workspace my/ghostel-workspace-last-slots 1))
           (buffer (gethash slot slots))
           (child-frame (and (buffer-live-p buffer)
                             (my/ghostel--posframe buffer))))
      (if (and child-frame (frame-visible-p child-frame))
          (progn
            (posframe-hide buffer)
            (my/floating-posframe--deactivate buffer parent-frame)
            (when (frame-live-p parent-frame)
              (select-frame-set-input-focus parent-frame)))
        (my/ghostel--hide-other-posframes slots buffer)
        (unless (buffer-live-p buffer)
          (with-selected-frame parent-frame
            ;; The workspace-specific name is also part of Ghostel's terminal
            ;; identity, preventing equal slot numbers in different workspaces
            ;; from resolving to the same underlying terminal.
            (dlet ((ghostel-buffer-name
                    (my/ghostel--buffer-name workspace)))
              ;; `ghostel' normally displays a new buffer before initializing
              ;; it.  Suppress that intermediate display; the initialized
              ;; buffer is placed directly into its Posframe immediately below.
              (cl-letf (((symbol-function 'pop-to-buffer)
                         (lambda (&rest _args) (selected-window))))
                (setq buffer (ghostel slot)))))
          (when workspace
            (persp-add-buffer buffer workspace nil))
          (puthash slot buffer slots))
        (with-current-buffer buffer
          (setq-local my/ghostel-popup-p t
                      my/ghostel-popup-workspace workspace
                      my/ghostel-popup-slot slot
                      my/ghostel-popup-parent-frame parent-frame)
          ;; The exit hook runs before Ghostel kills the buffer; the kill hook
          ;; is a fallback for terminals killed by an Emacs command instead.
          (add-hook 'ghostel-exit-functions #'my/ghostel--exit-popup-h nil t)
          (add-hook 'kill-buffer-hook #'my/ghostel--cleanup-popup-h nil t))
        (my/ghostel--show-posframe buffer parent-frame)))))

(after! persp-mode
  (add-hook 'persp-before-switch-functions
            #'my/ghostel--hide-all-posframes-h))

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
  ;; Closing the shell should close its floating terminal.  The next toggle
  ;; will then create a fresh buffer for the now-empty numbered slot.
  (setq ghostel-kill-buffer-on-exit t)
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
          (my/floating-posframe--deactivate buffer parent-frame)
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
          (my/floating-posframe--activate
           buffer parent-frame child-frame))))))

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

;; Keep these printable in insert/Emacs states.  This also clears the global
;; bindings left behind if an older version of this config is reloaded.
(map! :g "H" #'self-insert-command
      :g "L" #'self-insert-command
      :desc "Previous tab" :n "H" #'+tabs:previous-or-goto
      :desc "Next tab"     :n "L" #'+tabs:next-or-goto)

;; Oil-like filesystem operations in Dired.
(after! dired
  (map! :map dired-mode-map
        :n "+" #'dired-create-directory
        :n "N" #'dired-create-empty-file
        :n "D" #'dired-do-delete
        :n "R" #'dired-do-rename))

;; The available buffer tabs are shared by the current workspace/project group,
;; while cycling changes only the buffer displayed by the selected window.  SPC
;; h intentionally replaces Doom's help prefix; help remains available from
;; C-h.
(map! :leader
      :desc "Previous tab in window" "h" #'+tabs:previous-or-goto
      :desc "Next tab in window"     "l" #'+tabs:next-or-goto)

(map! :leader
      :desc "Dismiss popup/window" "q" #'quit-window
      :desc "Quit Emacs"           "Q" #'save-buffers-kill-terminal)

(defun my/current-tab-group-buffers ()
  "Return the live buffers in the current shared tab group."
  (let ((tabs
         (when (and (bound-and-true-p centaur-tabs-mode)
                    (fboundp 'centaur-tabs-current-tabset)
                    (fboundp 'centaur-tabs-tab-values))
           (when-let* ((tabset (centaur-tabs-current-tabset t)))
             (centaur-tabs-tab-values tabset)))))
    (seq-filter
     #'buffer-live-p
     (or tabs
         (doom-real-buffer-list
          (if (bound-and-true-p persp-mode)
              (persp-buffer-list)
            (buffer-list)))))))

(defun my/close-buffer-tab ()
  "Close the current workspace's shared buffer tab without changing splits.

Every window displaying the killed buffer switches to a neighboring buffer in
the same tab group.  If this was the group's last tab, show its directory with
Dired instead.  For buffers that do not visit a file, use `default-directory'.
If another workspace owns the buffer, remove it only from this workspace;
otherwise kill it.  Closing Dired itself does not reopen it."
  (interactive)
  (let* ((buffer (current-buffer))
         (windows (get-buffer-window-list buffer nil nil))
         (workspace (and (bound-and-true-p persp-mode)
                         (get-current-persp)))
         (tab-buffers (my/current-tab-group-buffers))
         (remaining-tabs (delq buffer (copy-sequence tab-buffers)))
         ;; Match Centaur Tabs' close behavior: prefer the next tab, then the
         ;; previous one when the current tab is last.
         (next-tab
          (when-let* ((position (cl-position buffer tab-buffers)))
            (or (nth (1+ position) tab-buffers)
                (and (> position 0)
                     (nth (1- position) tab-buffers)))))
         (dired-p (derived-mode-p 'dired-mode))
         (directory (if buffer-file-name
                        (file-name-directory buffer-file-name)
                      default-directory)))
    ;; `kill-buffer' may ask about unsaved changes or a running process.  Do
    ;; not change any windows when the user declines to kill it.
    (when (or (kill-buffer buffer)
              ;; Persp Mode returns nil from `kill-buffer' when the buffer is
              ;; still owned elsewhere: it removes the buffer from this
              ;; workspace but intentionally keeps the underlying buffer live.
              (and workspace
                   (buffer-live-p buffer)
                   (not (persp-contain-buffer-p buffer workspace))))
      (cond (remaining-tabs
             (dolist (window windows)
               (when (window-live-p window)
                 (set-window-buffer window (or next-tab (car remaining-tabs))))))
            ((not dired-p)
             (let ((dired-buffer (dired-noselect directory)))
               (when workspace
                 (persp-add-buffer dired-buffer workspace nil nil))
               (dolist (window windows)
                 (when (window-live-p window)
                   (set-window-buffer window dired-buffer)))))))))

(map! :leader
      :desc "Close workspace buffer tab"
      "x" #'my/close-buffer-tab)

;; Prefer the recursive, Orderless-filtered project picker over the built-in
;; path-oriented `find-file' prompt.  The latter remains available on SPC .
(map! :leader
      :desc "Find file in project"
      "f f" #'projectile-find-file)

;; `map!' states apply to one key/command pair and must immediately precede
;; that pair.  Preserve the standard global bindings outside normal state.
(map! :g "C-j" #'electric-newline-and-maybe-indent
      :g "C-k" #'kill-line
      :desc "Scroll window down" :n "C-j" #'evil-scroll-line-down
      :desc "Scroll window up"   :n "C-k" #'evil-scroll-line-up)

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

;; Use a project-local .venv in Python buffers.  GUI-launched Emacs does not
;; inherit an activated shell environment, so make the environment local to
;; each buffer before Doom starts Eglot, Flycheck, or a Python REPL.
(defun my/python-use-project-venv-h ()
  "Use the nearest project-local .venv for the current Python buffer."
  (when-let* ((root (locate-dominating-file default-directory ".venv"))
              (venv (expand-file-name ".venv" root))
              (bin (expand-file-name "bin" venv))
              ((file-directory-p bin)))
    (setq-local process-environment (copy-sequence process-environment)
                exec-path (cons bin exec-path)
                python-shell-interpreter (expand-file-name "python" bin))
    (setenv "VIRTUAL_ENV" venv)
    (setenv "PATH"
            (concat bin path-separator (getenv "PATH")))))

;; Doom runs these local-variable hooks before its appended LSP startup hook,
;; ensuring Pyrefly and Ruff are discoverable when Eglot/Flycheck start.
(add-hook 'python-mode-local-vars-hook #'my/python-use-project-venv-h)
(add-hook 'python-ts-mode-local-vars-hook #'my/python-use-project-venv-h)

;; Provide a context-aware project rail in dedicated right-hand side windows.
;; Its upper slot shows a pinned buffer, the slow_model plot, or project
;; compilation output, and its lower slot shows Magit.  SPC o p toggles the
;; complete rail.
(defconst my/kaggriculture-project-root
  (expand-file-name "~/devel/shaw/kaggriculture/")
  "Root of the Kaggriculture research project.")

(defconst my/kaggriculture-plot-root
  (expand-file-name "slow_model/" my/kaggriculture-project-root)
  "Directory containing the Kaggriculture plotting script.")

(defconst my/kaggriculture-plot-file
  (expand-file-name "plot.png" my/kaggriculture-plot-root)
  "Image generated by the Kaggriculture plotting script.")

(defconst my/kaggriculture-authoring-root
  (expand-file-name "authoring/" my/kaggriculture-project-root)
  "OCaml elaboration layer: policy families authored as typed values.")

(defconst my/kaggriculture-policies-root
  (expand-file-name "experiments/policies/" my/kaggriculture-project-root)
  "Directory holding one subdirectory per Kaggriculture policy family.")

(defconst my/kaggriculture-render-script
  (expand-file-name "tools/authoring_render.sh" my/kaggriculture-project-root)
  "Script chaining dune build, family emission, and the policy report.")

(defvar my/kaggriculture-family "monocrop_reorder"
  "Policy family the render loop rebuilds and reports on.

Saving a file that identifies a family updates this, so a later save under
`my/kaggriculture-authoring-root\' that names no family reuses the last one.")

(defvar my/kaggriculture-seed 1234
  "Episode seed used by the on-save policy report.")

(defvar my/kaggriculture-plot-process nil
  "Most recently started Kaggriculture plot-rendering process.")

(defconst my/project-rail-width 0.42
  "Fraction of the frame used by the project output rail.")

(defvar my/project-rail-pinned-output-buffers
  (make-hash-table :test #'equal)
  "Explicit upper-rail buffers keyed by project root.")

(defun my/kaggriculture--fit-plot-window-h ()
  "Fit the current plot image to its visible window."
  (when (derived-mode-p 'image-mode)
    (when-let ((window (get-buffer-window (current-buffer) t)))
      (with-selected-window window
        (image-transform-fit-to-window)))))

(defun my/kaggriculture--plot-buffer ()
  "Return the live-reloading Kaggriculture plot buffer."
  (unless (file-exists-p my/kaggriculture-plot-file)
    (user-error "The plot has not been rendered yet"))
  (let ((buffer (find-file-noselect my/kaggriculture-plot-file)))
    (with-current-buffer buffer
      (auto-revert-mode 1)
      (setq-local auto-revert-verbose nil)
      (add-hook 'after-revert-hook
                #'my/kaggriculture--fit-plot-window-h nil t))
    buffer))

(defun my/kaggriculture--plot-render-finished-h (process _event)
  "Refresh the plot after PROCESS exits, or show its errors."
  (when (and (eq process my/kaggriculture-plot-process)
             (memq (process-status process) '(exit signal)))
    (if (and (eq (process-status process) 'exit)
             (zerop (process-exit-status process)))
        (progn
          (when-let ((buffer (get-file-buffer
                              my/kaggriculture-plot-file)))
            (with-current-buffer buffer
              (revert-buffer :ignore-auto :noconfirm)))
          (when (process-get process 'show-rail-after-render)
            (my/project-rail-show my/kaggriculture-plot-root))
          (message "Plot refreshed"))
      (display-buffer (process-buffer process))
      (message "Plot rendering failed; see *kaggriculture-plot-build*"))))

(defun my/kaggriculture-render-plot (&optional show-after-render)
  "Asynchronously render the Kaggriculture plot.

When SHOW-AFTER-RENDER is non-nil, display the project rail after a successful
render."
  (interactive)
  (when (process-live-p my/kaggriculture-plot-process)
    (set-process-sentinel my/kaggriculture-plot-process #'ignore)
    (delete-process my/kaggriculture-plot-process))
  (let ((default-directory my/kaggriculture-plot-root)
        (log-buffer (get-buffer-create "*kaggriculture-plot-build*")))
    (with-current-buffer log-buffer
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (setq my/kaggriculture-plot-process
          (make-process
           :name "kaggriculture-plot"
           :buffer log-buffer
           :command
           (list (expand-file-name ".venv/bin/python"
                                   my/kaggriculture-plot-root)
                 (expand-file-name "main.py"
                                   my/kaggriculture-plot-root))
           :noquery t
           :sentinel #'my/kaggriculture--plot-render-finished-h))
    (process-put my/kaggriculture-plot-process
                 'show-rail-after-render show-after-render)))

(defun my/project-rail--windows ()
  "Return project-rail windows visible in the selected frame."
  (seq-filter
   (lambda (window)
     (window-parameter window 'my/project-rail))
   (window-list (selected-frame) 'nomini)))

(defun my/project-rail--display-buffer (buffer slot root)
  "Display BUFFER in project-rail SLOT for ROOT."
  (let ((window
         (display-buffer-in-side-window
          buffer
          `((side . right)
            (slot . ,slot)
            (window-width . ,my/project-rail-width)))))
    (set-window-parameter window 'my/project-rail t)
    (set-window-parameter window 'my/project-rail-root root)
    window))

(defun my/project-rail--project-root (directory)
  "Return a project root for DIRECTORY."
  (let ((default-directory (file-name-as-directory
                            (expand-file-name directory))))
    (file-name-as-directory
     (expand-file-name
      (or (when-let ((project (project-current nil)))
            (project-root project))
          (locate-dominating-file default-directory ".git")
          default-directory)))))

(defun my/project-rail--kaggriculture-context-p (directory)
  "Return non-nil when DIRECTORY belongs to the plotting model."
  (file-in-directory-p
   (file-name-as-directory (expand-file-name directory))
   my/kaggriculture-plot-root))

(defun my/project-rail--compilation-buffer (root)
  "Return the most recent compilation-derived buffer below ROOT."
  (seq-find
   (lambda (buffer)
     (with-current-buffer buffer
       (and (derived-mode-p 'compilation-mode)
            (stringp default-directory)
            (file-in-directory-p
             (file-name-as-directory (expand-file-name default-directory))
             root))))
   (buffer-list)))

(defun my/project-rail--pinned-output-buffer (root)
  "Return the live pinned output buffer for ROOT."
  (let ((buffer (gethash root my/project-rail-pinned-output-buffers)))
    (if (buffer-live-p buffer)
        buffer
      (remhash root my/project-rail-pinned-output-buffers)
      nil)))

(defun my/project-rail--output-buffer (directory root)
  "Return the context-appropriate upper output buffer.

An explicitly pinned buffer wins.  Otherwise the Kaggriculture slow model uses
its plot, and other contexts use their most recent Emacs compilation buffer."
  (cond ((my/project-rail--pinned-output-buffer root))
        ((my/project-rail--kaggriculture-context-p directory)
         (if (file-exists-p my/kaggriculture-plot-file)
             (my/kaggriculture--plot-buffer)
           (my/kaggriculture-render-plot t)
           nil))
        ((my/project-rail--compilation-buffer root))))

(defun my/project-rail--show-magit (root)
  "Show the Magit status for ROOT in the lower project-rail slot."
  (when (locate-dominating-file root ".git")
    (require 'magit-status)
    (let ((magit-display-buffer-noselect t)
          (magit-display-buffer-function
           (lambda (buffer)
             (my/project-rail--display-buffer buffer 1 root))))
      (magit-status-setup-buffer root))))

(defun my/project-rail-show (&optional directory)
  "Show the context-aware output rail for DIRECTORY.

The upper slot contains a pinned buffer, model plot, or compilation output.
The lower slot contains Magit.  If there is no output buffer, Magit uses the
whole rail."
  (interactive)
  (let* ((directory
          (file-name-as-directory
           (expand-file-name
            (or directory
                (and buffer-file-name
                     (file-name-directory buffer-file-name))
                default-directory))))
         (root (my/project-rail--project-root directory))
         (output-buffer (my/project-rail--output-buffer directory root))
         output-window)
    (when output-buffer
      (setq output-window
            (my/project-rail--display-buffer output-buffer -1 root)))
    (my/project-rail--show-magit root)
    (when (and output-window
               (eq output-buffer
                   (get-file-buffer my/kaggriculture-plot-file))
               (with-current-buffer output-buffer
                 (derived-mode-p 'image-mode)))
      (with-selected-window output-window
        (image-transform-fit-to-window)))))

(defun my/project-rail-hide ()
  "Hide all project-rail windows in the selected frame."
  (interactive)
  (dolist (window (my/project-rail--windows))
    (when (window-live-p window)
      (delete-window window))))

(defun my/project-rail-toggle ()
  "Show or hide the context-aware project output rail."
  (interactive)
  (if (my/project-rail--windows)
      (my/project-rail-hide)
    (my/project-rail-show)))

(defun my/project-rail-use-buffer (buffer)
  "Pin BUFFER into the current project's upper rail slot and show it."
  (interactive
   (list (read-buffer "Upper rail buffer: " (current-buffer) t)))
  (let* ((directory default-directory)
         (root (my/project-rail--project-root directory))
         (buffer (get-buffer buffer)))
    (unless (buffer-live-p buffer)
      (user-error "That buffer is no longer live"))
    (puthash root buffer my/project-rail-pinned-output-buffers)
    (my/project-rail-hide)
    (my/project-rail-show directory)))

(defun my/project-rail-clear-output-buffer ()
  "Unpin the current project's upper rail buffer and restore its default."
  (interactive)
  (let* ((directory default-directory)
         (root (my/project-rail--project-root directory)))
    (remhash root my/project-rail-pinned-output-buffers)
    (my/project-rail-hide)
    (my/project-rail-show directory)))

(defun my/kaggriculture--family-p (name)
  "Return NAME when it names a renderable policy family.

`experiments/policies/\' also holds `common/\' and loose package files, and
`authoring/families/\' may grow sources the emitter does not yet know about.
A directory only counts once it carries the DSL adapter the report runs."
  (when (and (stringp name)
             (not (string-empty-p name))
             (file-exists-p
              (expand-file-name (concat name "/dsl_policy.py")
                                my/kaggriculture-policies-root)))
    name))

(defun my/kaggriculture--family-at (file)
  "Return the policy family FILE belongs to, or nil.

Recognizes both ends of the loop: an authoring source named for its family
\(authoring/families/NAME.ml\) and a family\'s own directory
\(experiments/policies/NAME/...\)."
  (let ((file (expand-file-name file)))
    (my/kaggriculture--family-p
     (cond
      ((and (file-in-directory-p
             file (expand-file-name "families/" my/kaggriculture-authoring-root))
            (equal (file-name-extension file) "ml"))
       (file-name-base file))
      ((file-in-directory-p file my/kaggriculture-policies-root)
       (car (split-string
             (file-relative-name file my/kaggriculture-policies-root) "/" t)))))))

(defun my/kaggriculture-render-family (&optional family seed show-after-run)
  "Rebuild FAMILY at SEED and pin its report in the upper rail.

Runs `my/kaggriculture-render-script\', which typechecks the OCaml authoring
layer, re-emits the family\'s JSON encoding, and runs one oracle episode
through the DSL interpreter.  The stages share a buffer because they are
mutually exclusive in time: a build failure means there is no report to show."
  (interactive
   (list (or (and buffer-file-name
                  (my/kaggriculture--family-at buffer-file-name))
             my/kaggriculture-family)
         (if current-prefix-arg
             (prefix-numeric-value current-prefix-arg)
           my/kaggriculture-seed)
         t))
  (require 'compile)
  (let ((family (or family my/kaggriculture-family))
        (seed (or seed my/kaggriculture-seed)))
    (when-let ((process (get-buffer-process "*kaggriculture-render*")))
      (when (process-live-p process)
        (set-process-sentinel process #'ignore)
        (delete-process process)))
    (let* ((default-directory my/kaggriculture-project-root)
           (command
            (combine-and-quote-strings
             (list my/kaggriculture-render-script family (number-to-string seed))))
           ;; `compilation-start' normally chooses a popup before it returns the
           ;; new buffer.  The project rail owns display of this report instead.
           (display-buffer-overriding-action
            '(display-buffer-no-window (allow-no-window . t)))
           (buffer
            (compilation-start
             command 'compilation-mode
             (lambda (_mode) "*kaggriculture-render*"))))
      (puthash (my/project-rail--project-root default-directory)
               buffer my/project-rail-pinned-output-buffers)
      (when show-after-run
        (my/project-rail-hide)
        (my/project-rail-show default-directory)))))

(define-obsolete-function-alias 'my/kaggriculture-run-policy-report
  'my/kaggriculture-render-family "2026-08-21")

;; Dune reports OCaml errors as `File "path", line N, characters A-B:' with the
;; path relative to the workspace root, which is the compilation buffer's
;; `default-directory'.  Emacs ships no rule for it.  Character offsets are
;; 0-based upstream and 1-based here, so the highlighted column can sit one
;; character early; the file and line, which is what `next-error' needs, are exact.
(after! compile
  (add-to-list 'compilation-error-regexp-alist-alist
               '(dune-ocaml
                 "^File \"\\([^\"\n]+\\)\", line \\([0-9]+\\), characters \\([0-9]+\\)-\\([0-9]+\\):$"
                 1 2 (3 . 4)))
  (add-to-list 'compilation-error-regexp-alist 'dune-ocaml))

(defun my/kaggriculture-toggle-plot ()
  "Compatibility command for toggling the project output rail."
  (interactive)
  (my/project-rail-toggle))

(defun my/kaggriculture-render-on-save-h ()
  "Rebuild the Kaggriculture plot when its main.py is saved."
  (when (and buffer-file-name
             (file-equal-p
              buffer-file-name
              (expand-file-name "main.py" my/kaggriculture-plot-root)))
    (my/kaggriculture-render-plot)))

(add-hook 'after-save-hook #'my/kaggriculture-render-on-save-h)

(defun my/kaggriculture-render-on-save-family-h ()
  "Re-render the current policy family after saving one of its sources.

Fires for the OCaml authoring layer and for a family\'s own Python and JSON,
since a change to either end can move the reported margin."
  (when buffer-file-name
    (let* ((file (expand-file-name buffer-file-name))
           (named (my/kaggriculture--family-at file))
           ;; A save under authoring/lib/ or authoring/kaggriculture/ names no
           ;; family but can still change what every family emits, so it
           ;; re-renders whichever one was last worked on.
           (family (or named
                       (and (file-in-directory-p
                             file my/kaggriculture-authoring-root)
                            (equal (file-name-extension file) "ml")
                            (my/kaggriculture--family-p
                             my/kaggriculture-family)))))
      (when named
        (setq my/kaggriculture-family named))
      (when (and family
                 (member (file-name-extension file) '("ml" "py" "json")))
        (my/kaggriculture-render-family family my/kaggriculture-seed nil)))))

(add-hook 'after-save-hook #'my/kaggriculture-render-on-save-family-h)

(defun my/project-rail-follow-compilation-h ()
  "Put new compilation output in a visible rail for the same project."
  (when-let* ((rail-window (car (my/project-rail--windows)))
              (root (window-parameter rail-window 'my/project-rail-root))
              ((file-in-directory-p
                (file-name-as-directory
                 (expand-file-name default-directory))
                root)))
    (my/project-rail--display-buffer (current-buffer) -1 root)))

(add-hook 'compilation-mode-hook #'my/project-rail-follow-compilation-h)

;; Run a tree's own command after every save and route the output into the
;; upper rail slot.  This is the general form of the Kaggriculture render loop
;; above: the rail already knows how to display a compilation buffer for the
;; project it belongs to, so all this adds is "which command does this tree
;; run, and on which saves".
;;
;; `compilation-always-kill' is a defcustom in compile.el, so the byte-compiler
;; has to have seen it to bind it dynamically below.
(eval-when-compile (require 'compile))

(defvar my/run-on-save-alist
  `((,(expand-file-name "~/devel/shaw/molecular-dynamics/molecular_rendering/")
     :command "dune exec molecular_rendering"
     :match "\\(\\.mli?\\|/dune\\(-project\\)?\\)\\'"))
  "Per-directory on-save run commands.

Each entry is (ROOT :command COMMAND [:match REGEXP]).  Saving a file under
ROOT whose name matches REGEXP -- any file, when REGEXP is omitted -- runs
COMMAND with `default-directory' at ROOT.  Anything under a `_build/' is
ignored, and the most specific ROOT wins, so a subproject can override the
tree it sits in.")

(defvar my/run-on-save-enabled t
  "When nil, saving never triggers `my/run-on-save-alist'.")

(defun my/run-on-save--entry (file &optional any-file)
  "Return the most specific `my/run-on-save-alist' entry covering FILE.
With ANY-FILE, ignore each entry's `:match' regexp."
  (let ((file (expand-file-name file))
        best)
    (pcase-dolist (`(,root . ,plist) my/run-on-save-alist)
      (let ((root (file-name-as-directory (expand-file-name root))))
        (when (and (file-in-directory-p file root)
                   (not (string-match-p "/_build/" file))
                   (or any-file
                       (string-match-p (or (plist-get plist :match) "") file))
                   (> (length root) (length (or (car best) ""))))
          (setq best (cons root plist)))))
    best))

(defun my/run-on-save-run (root command &optional show)
  "Run COMMAND in ROOT, pinning its output into ROOT's upper rail slot."
  (require 'compile)
  (let* ((default-directory (file-name-as-directory (expand-file-name root)))
         (name (format "*run: %s*"
                       (file-name-nondirectory
                        (directory-file-name default-directory))))
         ;; Never prompt about the previous run still going, and never let
         ;; `compilation-start' pick a window: the rail owns display, via
         ;; `my/project-rail-follow-compilation-h'.
         (compilation-always-kill t)
         (display-buffer-overriding-action
          '(display-buffer-no-window (allow-no-window . t)))
         (buffer (compilation-start command 'compilation-mode
                                    (lambda (_mode) name))))
    (puthash (my/project-rail--project-root default-directory)
             buffer my/project-rail-pinned-output-buffers)
    (when show
      (my/project-rail-hide)
      (my/project-rail-show default-directory))
    buffer))

(defun my/run-on-save-h ()
  "Run this file's tree command, if it has one."
  (when (and my/run-on-save-enabled buffer-file-name)
    (when-let* ((entry (my/run-on-save--entry buffer-file-name)))
      (my/run-on-save-run (car entry) (plist-get (cdr entry) :command)))))

(add-hook 'after-save-hook #'my/run-on-save-h)

(defun my/run-on-save-now ()
  "Run this file's tree command and show the rail, ignoring `:match'."
  (interactive)
  (let ((entry (my/run-on-save--entry
                (or buffer-file-name default-directory) :any-file)))
    (unless entry
      (user-error "No run-on-save command covers this file"))
    (my/run-on-save-run (car entry) (plist-get (cdr entry) :command) t)))

(defun my/run-on-save-toggle ()
  "Toggle whether saving runs a tree's command."
  (interactive)
  (message "Run on save %s"
           (if (setq my/run-on-save-enabled (not my/run-on-save-enabled))
               "enabled"
             "disabled")))

(map! :leader
      (:prefix ("o" . "open")
       :desc "Dired"                        "-" #'dired-jump
       :desc "Use buffer as project output" "b" #'my/project-rail-use-buffer
       :desc "Clear pinned project output"  "c" #'my/project-rail-clear-output-buffer
       :desc "Toggle project output rail"   "p" #'my/project-rail-toggle
       :desc "Render policy family"         "r" #'my/kaggriculture-render-family
       :desc "Run this tree's command"      "R" #'my/run-on-save-now)
      (:prefix ("t" . "toggle")
       :desc "Run on save"                  "R" #'my/run-on-save-toggle))

(with-eval-after-load 'python
  ;; Prefer Pyrefly as the full Python language server.
  (set-eglot-client! '(python-mode python-ts-mode) '("pyrefly" "lsp"))
  ;; Doom's formatter module handles format-on-save; select Ruff instead of
  ;; its default Python formatter, Black.
  (set-formatter! 'ruff :modes '(python-mode python-ts-mode)))

;; Keep Pyrefly diagnostics from Eglot and chain Doom/Flycheck's built-in Ruff
;; checker after them, rather than treating Eglot as the exclusive checker.
(after! flycheck-eglot
  (setq flycheck-eglot-exclusive nil))
