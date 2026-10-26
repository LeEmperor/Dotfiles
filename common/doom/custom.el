(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(safe-local-variable-values
   '((+format-with . clang-format)
     (eval when
      (derived-mode-p 'c++-mode 'c++-ts-mode)
      (add-hook 'after-save-hook
                (lambda nil
                  (require 'compile)
                  (let
                      ((compilation-always-kill t)
                       (display-buffer-overriding-action
                        '(display-buffer-no-window
                          (allow-no-window . t))))
                    (compilation-start compile-command 'compilation-mode
                                       (lambda
                                         (_mode)
                                         "*quantiq-check*"))))
                nil t))
     (tuareg-match-patterns-aligned . t)
     (tuareg-indent-align-with-first-arg . t))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
