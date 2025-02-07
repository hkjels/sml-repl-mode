;;; sml-repl.el --- Inline evaluation and REPL for Standard ML -*- lexical-binding: t; -*-
;;
;; Author: Henrik Kjerringvåg <henrik@kjerringvag.no>
;; Version: 0.1
;; Package-Requires: ((emacs "26.1"))
;; Keywords: languages, sml, repl, evaluation
;;
;;; Commentary:
;;
;; This package provides a REPL for Standard ML and inline evaluation facilities.
;;
;; I'm currently taking a course on programming languages, and the
;; first language we're exploring is Standard ML.  While experimenting
;; with various SML modes in Emacs, I noticed a lack of interactive
;; overlays when evaluating code—something I'm accustomed to from
;; Elisp and Clojure.  Although sml-mode provides REPL interaction, I
;; wanted to avoid relying too heavily on it, given Emacs' shift
;; toward tree-sitter modes.  This is my first experience with Standard
;; ML, so sml-repl-mode may have some rough edges, but so far, it has
;; worked quite well.
;;
;; Usage:
;; Enable `sml-repl-mode` in your Standard ML source buffer.
;; Keybindings:
;;   C-c C-e   Evaluate the current region.
;;   C-c C-l   Evaluate the current line.
;;   C-c C-b   Evaluate the current buffer.
;;   C-c C-f   Evaluate a file.
;;
;;
;; License:
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;; Code:

(require 'comint)
(require 'seq)
(require 'subr-x)

(defgroup sml-repl nil
  "Inline evaluation and simple REPL for Standard ML."
  :group 'languages)

(defcustom sml-repl-show-repl-on-start nil
  "If non-nil, show the SML REPL buffer when it is started."
  :type 'boolean
  :group 'sml-repl)

(defcustom sml-repl-overlay-delay 6
  "Time in seconds after which the inline evaluation overlay is automatically dismissed."
  :type 'number
  :group 'sml-inline)

(defcustom sml-repl-only-show-result t
  "Only show the value in the overlay and not its type etc."
  :type 'boolean
  :group 'sml-repl)

(defcustom sml-repl-buffer-name "*SML-REPL*"
  "Name of the SML REPL buffer."
  :type 'string
  :group 'sml-repl)

(defcustom sml-repl-font-lock t
  "If non-nil, enable font-lock in the SML REPL buffer."
  :type 'boolean
  :group 'sml-repl)

(defcustom sml-repl-overlay-font-lock t
  "If non-nil, apply font-lock to the inline evaluation result overlays."
  :type 'boolean
  :group 'sml-repl)

(defcustom sml-repl-prompt-regexp "^- "
  "Regular expression matching the SML REPL prompt.
The prompt is assumed to be a dash followed by a space."
  :type 'string
  :group 'sml-repl)

(defface sml-repl-result-overlay-face
  '((t (:inherit bold)))
  "Face for inline SML REPL evaluation results.
This is only applied if `sml-repl-overlay-font-lock` is non truthy."
  :group 'sml-repl)

(defface sml-repl-error-overlay-face
  '((t (:inherit warning)))
  "Face for inline SML REPL error results."
  :group 'sml-repl)

(defun sml-repl-run ()
  "Start the SML REPL if not already running.
If `sml-repl-show-repl-on-start' is non-nil, display the REPL buffer.
Notify the user once the REPL is connected."
  (interactive)
  (let ((buffer (get-buffer sml-repl-buffer-name)))
    (if (and buffer (comint-check-proc buffer))
        buffer
      (let* ((sml-cmd (or (executable-find "sml") "sml"))
             (repl-buffer (apply #'make-comint-in-buffer "SML-REPL" sml-repl-buffer-name sml-cmd nil nil)))
        (with-current-buffer repl-buffer
          (sml-repl-buffer-mode)
          ;; Wait until the REPL prompt appears or timeout after 5 seconds.
          (let ((start-time (float-time))
                (timeout 5))
            (while (and (< (- (float-time) start-time) timeout)
                        (not (save-excursion
                               (goto-char (point-min))
                               (re-search-forward sml-repl-prompt-regexp nil t))))
              (accept-process-output nil 0.1)))
          (erase-buffer)
          (insert "(* Standard ML REPL *)\n")
          (insert "- "))
        (when sml-repl-show-repl-on-start
          (pop-to-buffer repl-buffer))
        (message "Connected to the Standard ML REPL!")
        repl-buffer))))

(defun sml-repl--get-process ()
  "Return the SML REPL process, starting it if necessary."
  (or (and (get-buffer sml-repl-buffer-name)
           (get-buffer-process sml-repl-buffer-name))
      (progn (sml-repl-run)
             (get-buffer-process sml-repl-buffer-name))))

(defun sml-repl--fontify-string (str)
  "Return an SML fontified version of STR."
  (with-temp-buffer
    (insert str)
    (delay-mode-hooks
      (if (fboundp 'sml-ts-mode)
          (sml-ts-mode)
        (when (fboundp 'sml-mode)
          (sml-mode)))
      (when (fboundp 'highlight-numbers-mode)
        (highlight-numbers-mode)))
    (font-lock-ensure)
    (buffer-substring (point-min) (point-max))))

(defun sml-repl--eval-code (code callback)
  "Send CODE to the SML REPL and call CALLBACK with the output.
A timeout is set to wait for the REPL's response."
  (let* ((proc (sml-repl--get-process))
         (output-buffer (get-buffer sml-repl-buffer-name))
         (start-marker (with-current-buffer output-buffer (point-max)))
         (cmd (if (string-match-p ";\\s-*$" code)
                  (concat code "\n")
                (concat code ";\n")))
         (timeout 2)
         (start-time (float-time)))
    (with-current-buffer output-buffer (goto-char (point-max)))
    (comint-redirect-send-command-to-process cmd output-buffer proc nil t)
    (while (and (< (- (float-time) start-time) timeout)
                (with-current-buffer output-buffer
                  (save-excursion
                    (goto-char (point-max))
                    (not (re-search-backward sml-repl-prompt-regexp start-marker t)))))
      (accept-process-output proc 0.1))
    (let ((output (with-current-buffer output-buffer
                    (buffer-substring-no-properties start-marker (point-max)))))
      (funcall callback output))))

(defun sml-repl--clean-output (output)
  "Clean the SML REPL OUTPUT by removing prompt lines and trimming whitespace."
  (let* ((lines (split-string output "\n"))
         (clean-lines (seq-filter (lambda (line)
                                    (not (string-match-p sml-repl-prompt-regexp line)))
                                  lines))
         (result (string-trim (string-join clean-lines "\n"))))
    (if (and sml-repl-only-show-result (string-match "val [^=]+ = \\([^:]+\\) : .*" output))
        (match-string 1 output)
      result)))

(defun sml-repl--display-inline-result (beg end result)
  "Display the inline evaluation RESULT on the line following the code.
Overlays created by this function are automatically cleared after a
delay specified with `sml-repl-overlay-delay`."
  (let* ((clean-result (sml-repl--clean-output result))
         (error-p (string-match-p "^stdIn:.*Error:" clean-result))
         (face (if error-p 'sml-repl-error-overlay-face 'sml-repl-result-overlay-face))
         (offset "   > ")
         (display-text (concat offset clean-result))
         (final-text (if (and (not error-p) sml-repl-overlay-font-lock)
                         (sml-repl--fontify-string display-text)
                       (propertize display-text 'face face)))
         (overlay-pos end)
         (ov (make-overlay overlay-pos overlay-pos)))
    (overlay-put ov 'after-string final-text)
    (overlay-put ov 'sml-repl-inline-result t)
    (overlay-put ov 'line-number nil)
    (run-with-timer sml-repl-overlay-delay nil (lambda (ov) (when (overlayp ov) (delete-overlay ov))) ov)))

(defun sml-repl--clear-inline-results (beg end)
  "Clear inline evaluation overlays between BEG and the line following END."
  (remove-overlays beg (save-excursion (goto-char end) (forward-line 1) (point))
                   'sml-repl-inline-result t))

;;;###autoload
(defun sml-repl-eval-region (beg end)
  "Evaluate the SML code in the region from BEG to END and display the result inline.
Before evaluation, any existing inline results in the affected area are cleared.
The code is sent to the SML REPL and the output is shown as an overlay on the line
following the evaluated region."
  (interactive "r")
  ;; Clear previous inline results in the affected area.
  (if (and (= beg (point-min)) (= end (point-max)))
      (remove-overlays (point-min) (point-max) 'sml-repl-inline-result t)
    (sml-repl--clear-inline-results beg end))
  (sml-repl--get-process)
  (let ((code (buffer-substring-no-properties beg end)))
    (sml-repl--eval-code code (lambda (result)
                                (sml-repl--display-inline-result beg end result)))))

;;;###autoload
(defun sml-repl-eval-line ()
  "Evaluate the current line of SML code and display the result inline.
Any existing inline result for this line is cleared before evaluation."
  (interactive)
  (let ((beg (line-beginning-position))
        (end (line-end-position)))
    (sml-repl-eval-region beg end)))

;;;###autoload
(defun sml-repl-eval-buffer ()
  "Evaluate the current buffer of SML code and display the result inline.
Any existing inline result for this line is cleared before evaluation."
  (interactive)
  (let ((beg (point-min))
        (end (point-max)))
    (sml-repl-eval-region beg end)))

;;;###autoload
(defun sml-repl-eval-file (file)
  "Read an SML source FILE and send its contents to the SML REPL for evaluation.
This function opens FILE in a temporary buffer and uses `sml-repl-eval-buffer'
to process its contents."
  (interactive "fSelect SML file to evaluate: ")
  (with-temp-buffer
    (insert-file-contents file)
    (sml-repl-eval-buffer (current-buffer))))

;;;###autoload
(define-derived-mode sml-repl-buffer-mode comint-mode "SML-REPL"
  "Major mode for the SML REPL buffer."
  (progn
    (delay-mode-hooks
      (when (fboundp 'highlight-numbers-mode)
        (highlight-numbers-mode)))
    (setq-local indent-line-function #'ignore)))

;;;###autoload
(define-minor-mode sml-repl-mode
  "Minor mode for inline evaluation and REPL integration for Standard ML.
When enabled, evaluation results are shown inline in the buffer.
Keybindings:
  C-c C-e   Evaluate the current region.
  C-c C-l   Evaluate the current line."
  :lighter " SML-REPL"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c C-e") 'sml-repl-eval-region)
            (define-key map (kbd "C-c C-l") 'sml-repl-eval-line)
            (define-key map (kbd "C-c C-b") 'sml-repl-eval-buffer)
            (define-key map (kbd "C-c C-f") 'sml-repl-eval-file)
            map))

(provide 'sml-repl)
;;; sml-repl.el ends here
