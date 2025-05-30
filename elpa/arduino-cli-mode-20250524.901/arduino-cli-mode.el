;;; arduino-cli-mode.el --- Arduino-CLI command wrapper -*- lexical-binding: t -*-

;; Copyright © 2019

;; Author: Love Lagerkvist
;; URL: https://github.com/motform/arduino-cli-mode
;; Package-Version: 20250524.901
;; Package-Revision: aa93d49dc90c
;; Package-Requires: ((emacs "25.1"))
;; Created: 2019-11-16
;; Keywords: processes tools

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; arduino-cli-mode is an Emacs minor mode for using the excellent new
;; Arduino command line interface in an Emacs-native fashion.  The mode
;; covers the full range of arduino-cli features in an Emacs native
;; fashion.  The mode leverages the infinite power the GNU to provide
;; fussy-finding of libraries and much improved support for handling
;; multiple boards.  The commands that originally require multiple
;; steps (such as first searching for a library and then separately
;; installing it) have been folded into one.
;; 
;; For more information on the package and default board behavior,
;; see the README at https://github.com/motform/arduino-cli-mode
;;
;; For more information on arduino-cli itself,
;; see https://github.com/arduino/arduino-cli
;;
;; Tested against arduino-cli <= 0.10.0

;;; Code:

(require 'compile)
(require 'json)
(require 'map)
(require 'seq)
(require 'subr-x)

(eval-when-compile (require 'cl-lib))

;;; Customization
(defgroup arduino-cli nil
  "Arduino-cli-mode functions and settings."
  :group  'tools
  :prefix "arduino-cli-"
  :link   '(url-link https://github.com/motform/arduino-cli-mode))

(defcustom arduino-cli-mode-keymap-prefix (kbd "C-c C-a")
  "Arduino-cli keymap prefix."
  :group 'arduino-cli
  :type  'string)

;; arduino-cli-default-fqbn and arduino-cli-default-port may be useful
;; as file local variables but are not ":safe" because (if used) their
;; values are passed to the shell as part of an arduino-cli command
;; line.

;; Simple FQBNs have the format <vendor>:<architecture>:<board-id> but
;; the full syntax is more complicated, and arduino-cli-mode simply
;; passes the value to arduino-cli without parsing it in any way.

(defcustom arduino-cli-default-fqbn nil
  "Default fqbn to use if board selection fails."
  :group 'arduino-cli
  :type  '(choice 
	   (const :tag "No default (error message if board selection fails)" 
		  nil)
	   (string :tag "Fully qualified board name")))

;; This is a string that is an "Upload port address, e.g.: COM3 or
;; /dev/ttyACM2" (according to arduino-cli help message).
;; It might be possible to validate it, but for now we just treat
;; it as a string; arduino-cli-mode does not parse it, but simply
;; passes the value to arduino-cli.

(defcustom arduino-cli-default-port nil
  "Default port to use if board selection fails."
  :group 'arduino-cli
  :type  '(choice 
	   (const :tag "No default (error message if board selection fails)" 
		  nil)
	   (string :tag "Port address")))

(defcustom arduino-cli-verify nil
  "Non-nil means verify uploaded binary after the upload."
  :group 'arduino-cli
  :type  'boolean)

(defcustom arduino-cli-warnings nil
  "Set GCC warning level, can be nil (none), `default', `more' or `all'."
  :group 'arduino-cli
  :type  '(choice (const :tag "--warnings default" default)
		  (const :tag "--warnings more" more)
		  (const :tag "--warnings all" all)
		  (const :tag "No warnings flag; default level is \"none\"" nil)))

(defcustom arduino-cli-verbosity nil
  "The verbosity flags (if any) to pass to arduino-cli commands.

`quiet' passes --quiet to applicable arduino-cli commands
(otherwise ignored).

`verbose' passes --verbose to arduino-cli compile commands, 
or all commands if arduino-cli-compile-only-verbosity is set to nil."
  :group 'arduino-cli
  :type  '(choice (const :tag "Quiet" quiet)
		  (const :tag "Verbose" verbose)
		  (const :tag "None" nil)))

(defcustom arduino-cli-compile-only-verbosity t
  "Non-nil (default) means only apply verbosity setting to compilation."
  :group 'arduino-cli
  :type 'boolean)

(defcustom arduino-cli-compile-color t
  "Non-nil (default) means apply ANSI colors from compilation output."
  :group 'arduino-cli
  :type 'boolean)

;;; Internal functions
(defun arduino-cli--compilation-filter ()
  "Filter function for applying ANSI colors in compilation output."
  (when arduino-cli-compile-color
    (ansi-color-apply-on-region compilation-filter-start (point-max))))

(define-compilation-mode arduino-cli-compilation-mode "arduino-cli-compilation"
  "Arduino-cli specific `compilation-mode' derivative."
  (setq-local compilation-scroll-output t)
  (require 'ansi-color)
  (add-hook 'compilation-filter-hook #'arduino-cli--compilation-filter))

(defun arduino-cli--?map-put (m v k)
  "Puts V in M under K when V, else return M."
  (if v (setf (map-elt m k) v)) m)

(defun arduino-cli--verify ()
  "Get verify bool."
  (when arduino-cli-verify " -t"))

(defun arduino-cli--verbosity ()
  "Get the current verbosity level."
  (pcase arduino-cli-verbosity
    ('quiet   " --quiet")
    ('verbose " --verbose")))

(defun arduino-cli--warnings ()
  "Get the current warnings level."
  (when arduino-cli-warnings
    (concat " --warnings " (symbol-name arduino-cli-warnings))))

(defun arduino-cli--compile-color ()
  "Get the current compilation color setting."
  (when (not arduino-cli-compile-color)
    " --no-color"))

(defun arduino-cli--general-flags ()
  "Add flags to CMD, if set."
  (concat (unless arduino-cli-compile-only-verbosity
            (arduino-cli--verbosity))))

(defun arduino-cli--compile-flags ()
  "Add flags to CMD, if set."
  (concat (arduino-cli--verify)
          (arduino-cli--warnings)
          (arduino-cli--verbosity)
          (arduino-cli--compile-color)))

(defun arduino-cli--add-flags (mode cmd)
  "Add general and MODE flags to CMD, if set."
  (concat cmd (pcase mode
                ('compile (arduino-cli--compile-flags))
                (_        (arduino-cli--general-flags)))))

(defun arduino-cli--compile (cmd)
  "Run arduino-cli CMD in 'arduino-cli-compilation-mode."
  (let* ((cmd  (concat "arduino-cli " cmd " " (shell-quote-argument (expand-file-name default-directory))))
         (cmd* (arduino-cli--add-flags 'compile cmd)))
    (save-some-buffers (not compilation-ask-about-save) (lambda () default-directory))
    (setf arduino-cli--compilation-buffer
          (compilation-start cmd* 'arduino-cli-compilation-mode))))

(defun arduino-cli--message (cmd &rest path)
  "Run arduino-cli CMD in PATH (if provided) and print as message.
If PATH is not provided, default-directory is used.
PATH should be an absolute directory name."
  (let* ((default-directory (if path (car path) default-directory))
         (cmd  (concat "arduino-cli " cmd))
         (cmd* (arduino-cli--add-flags 'message cmd))
         (out  (shell-command-to-string cmd*)))
    (message "%s" (string-trim out))))

(defun arduino-cli--arduino? (usb-device)
  "Return USB-DEVICE if it is an Arduino, nil otherwise."
  (assoc 'matching_boards usb-device))

(defun arduino-cli--selected-board? (board selected-board)
  "Return BOARD if it is the SELECTED-BOARD."
  (string= (arduino-cli--board-address board)
           selected-board))

(defun arduino-cli--cmd-json (cmd)
  "Get the result of CMD as JSON-style alist."
  (let* ((cmmd (concat "arduino-cli " cmd " --format json")))
    (thread-first cmmd shell-command-to-string json-read-from-string)))

(defun arduino-cli--default-board ()
  "Get the default Arduino board, if available."
  (thread-first '()
    (arduino-cli--?map-put arduino-cli-default-fqbn 'fqbn)
    (arduino-cli--?map-put (arduino-cli--?map-put '() arduino-cli-default-port 'address) 'port)))

(defun arduino-cli--board ()
  "Get connected Arduino board."
  (let* ((output          (arduino-cli--cmd-json "board list"))
         (ports           (alist-get 'detected_ports output))
         (boards          (seq-filter #'arduino-cli--arduino? ports))
         (boards-info     (seq-map (lambda (m) (thread-first (assoc 'boards m) cdr (seq-elt 0))) boards))
         (informed-boards (cl-mapcar (lambda (m n) (map-merge 'list m n)) boards boards-info))
         (selected-board  (arduino-cli--dispatch-board informed-boards))
         (default-board   (arduino-cli--default-board)))
    (cond (selected-board selected-board)
          (default-board  default-board)
          (t (error "ERROR: No board connected")))))

;; TODO add automatic support for compiling to known cores when no boards are connected
(defun arduino-cli--dispatch-board (boards)
  "Correctly dispatch on the amount of BOARDS connected."
  (pcase (length boards)
    (`1           (car boards))
    ((pred (< 1)) (arduino-cli--select-board boards))
    (_ nil)))

(defun arduino-cli--board-fqbn (board)
  "Get FQBN of BOARD.
If BOARD has multiple matching_boards, the first one is used."
  (let* ((matching-boards (cdr (assoc 'matching_boards board)))
         ;; TODO: does the order here make sense?
         (first-matching-board (if matching-boards
                                   (aref matching-boards 0)
                                 board))
         (fqbn (cdr (assoc 'fqbn first-matching-board))))
    fqbn))

(defun arduino-cli--board-address (board)
  "Get port address of BOARD."
  (cdr (assoc 'address (cdr (assoc 'port board)))))

(defun arduino-cli--board-name (board)
  "Get name of BOARD in (name @ port) format."
  (concat (cdr (assoc 'name board))
          " @ "
          (arduino-cli--board-address board)))

(defun arduino-cli--select-board (boards)
  "Prompt user to select an Arduino from BOARDS."
  (let* ((board-names (cl-mapcar #'arduino-cli--board-name boards))
         (selection   (thread-first board-names
                        (arduino-cli--select "Board ")
                        (split-string "@")
                        cadr
                        string-trim)))
    (car (seq-filter (lambda (m) (arduino-cli--selected-board? m selection)) boards))))

(defun arduino-cli--cores ()
  "Get installed Arduino cores."
  (let* ((output   (arduino-cli--cmd-json "core list"))
         (cores    (alist-get 'platforms output))
         (id-pairs (seq-map (lambda (m) (assoc 'id m)) cores))
         (ids      (seq-map #'cdr id-pairs)))
    (if ids ids
      (error "ERROR: No cores installed"))))

(defun arduino-cli--search-cores ()
  "Search from list of cores."
  (let* ((output    (arduino-cli--cmd-json "core search")) ; search without parameters gets all cores
         (cores    (alist-get 'platforms output))
         (id-pairs (seq-map (lambda (m) (assoc 'id m)) cores))
         (ids      (seq-map #'cdr id-pairs)))
    (arduino-cli--select ids "Core ")))

(defun arduino-cli--libs (&optional full)
  "Get installed Arduino libraries.  If FULL is non-nil, return the full data objects, else return only library names."
  (let* ((output    (arduino-cli--cmd-json "lib list"))
         (libs      (alist-get 'installed_libraries output)))
    (if libs
        (if full
            libs
          (seq-map (lambda (lib) (cdr (assoc 'name (assoc 'library lib)))) libs))
      (error "ERROR: No libraries installed"))))

(defun arduino-cli--search-libs ()
  "Get installed Arduino libraries."
  (let* ((libs      (cdr (assoc 'libraries (arduino-cli--cmd-json "lib search")))))
    (if libs libs
      (error "ERROR: Unable to find libraries"))))

(defun arduino-cli--select (xs msg)
  "Select option from XS, prompted by MSG."
  (completing-read msg xs))


;;; User commands
(defun arduino-cli-compile ()
  "Compile Arduino project."
  (interactive)
  (let* ((board (arduino-cli--board))
         (fqbn  (if-let (fqbn (arduino-cli--board-fqbn board)) fqbn
                  (error "ERROR: No fqbn specified")))
         (cmd   (concat "compile --fqbn " fqbn)))
    (arduino-cli--compile cmd)))

(defun arduino-cli-compile-and-upload ()
  "Compile and upload Arduino project."
  (interactive)
  (when (arduino-cli--serial-monitor-is-active)
    (arduino-cli-stop-serial-monitor "to upload a sketch")
    (add-hook 'compilation-finish-functions
              #'arduino-cli--start-serial-monitor-callback))
  (let* ((board (arduino-cli--board))
         (fqbn  (if-let (fqbn (arduino-cli--board-fqbn board))
                    fqbn
                  (error "ERROR: No fqbn specified")))
         (port  (if-let (port (arduino-cli--board-address board))
                    port
                  (error "ERROR: No port specified")))
         (cmd   (concat "compile --fqbn " fqbn " --port " port " --upload")))
    (arduino-cli--compile cmd)))

(defun arduino-cli-upload ()
  "Upload Arduino project."
  (interactive)
  (when (arduino-cli--serial-monitor-is-active)
    (arduino-cli-stop-serial-monitor "to upload a sketch")
    (add-hook 'compilation-finish-functions
              #'arduino-cli--start-serial-monitor-callback))
  (let* ((board (arduino-cli--board))
         (fqbn  (if-let (fqbn (arduino-cli--board-fqbn board))
                    fqbn
                  (error "ERROR: No fqbn specified")))
         (port  (if-let (port (arduino-cli--board-address board))
                    port
                  (error "ERROR: No port specified")))
         (cmd (concat "upload --fqbn " fqbn " --port " port)))
    (arduino-cli--compile cmd)))

(defun arduino-cli-board-list ()
  "Show list of connected Arduino boards."
  (interactive)
  (arduino-cli--message "board list"))

(defun arduino-cli-core-list ()
  "Show list of installed Arduino cores."
  (interactive)
  (arduino-cli--message "core list"))

(defun arduino-cli-core-upgrade ()
  "Update-index and upgrade all installed Arduino cores."
  (interactive)
  (let* ((cores     (arduino-cli--cores))
         (selection (arduino-cli--select cores "Core "))
         (cmd       (concat "core upgrade " selection)))
    (shell-command-to-string "arduino-cli core update-index")
    (arduino-cli--message cmd)))

(defun arduino-cli-core-upgrade-all ()
  "Update-index and upgrade all installed Arduino cores."
  (interactive)
  (shell-command-to-string "arduino-cli core update-index")
  (arduino-cli--message "core upgrade"))

(defun arduino-cli-kill-arduino-connection ()
  "Kill any existing connection to an arduino."
  (interactive)
  (let ((comp-proc (get-buffer-process arduino-cli--compilation-buffer)))
    (if comp-proc
        (condition-case ()
            (progn
              (interrupt-process comp-proc)
              (sit-for 1)
              (delete-process comp-proc))
          (error nil))
      (message "No Arduino connection running!"))))

;; TODO change from compilation mode into other, non blocking mini-buffer display
(defun arduino-cli-core-install ()
  "Find and install Arduino cores."
  (interactive)
  (let* ((core (arduino-cli--search-cores))
         (cmd  (concat "arduino-cli core install " core)))
    (shell-command-to-string "arduino-cli core update-index")
    (setf arduino-cli--compilation-buffer
          (compilation-start cmd 'arduino-cli-compilation-mode))))

(defun arduino-cli-core-uninstall ()
  "Find and uninstall Arduino cores."
  (interactive)
  (let* ((cores     (arduino-cli--cores))
         (selection (arduino-cli--select cores "Core "))
         (cmd       (concat "core uninstall " selection)))
    (arduino-cli--message cmd)))

(defun arduino-cli-lib-list ()
  "Show list of installed Arduino libraries."
  (interactive)
  (arduino-cli--message "lib list"))

(defun arduino-cli-lib-upgrade ()
  "Upgrade Arduino libraries."
  (interactive)
  (shell-command-to-string "arduino-cli lib update-index")
  (arduino-cli--message "lib upgrade"))

;; TODO change from compilation mode into other, non blocking mini-buffer display
(defun arduino-cli-lib-install (select-version-p)
  "Find and install Arduino libraries.  With prefix arg SELECT-VERSION-P, allow selecting the library version."
  (interactive "P")
  (let* ((libs (arduino-cli--search-libs))
         (lib-names (if select-version-p
                        (apply #'append (seq-map (lambda (lib)
                                                   (seq-map (lambda (ver)
                                                              (format "%s@%s" (cdr (assoc 'name lib)) ver))
                                                            (cdr (assoc 'available_versions lib))))
                                                 libs))
                      (seq-map (lambda (lib) (cdr (assoc 'name lib))) libs)))
         (selection (arduino-cli--select lib-names "Library "))
         (cmd (concat "arduino-cli lib install " (shell-quote-argument selection))))
    (shell-command-to-string "arduino-cli lib update-index")
    (setf arduino-cli--compilation-buffer
          (compilation-start cmd 'arduino-cli-compilation-mode))))

(defun arduino-cli-lib-uninstall ()
  "Find and uninstall Arduino libraries."
  (interactive)
  (let* ((libs (arduino-cli--libs))
         (selection (arduino-cli--select libs "Library "))
         (cmd (concat "lib uninstall " (shell-quote-argument selection))))
    (arduino-cli--message cmd)))

(defun arduino-cli-lib-browse ()
  "Browse the install directory of an installed Arduino library."
  (interactive)
  (let* ((output    (arduino-cli--libs t))
         (lib-dirs  (seq-map (lambda (lib)
                               (let ((library (cdr (assoc 'library lib))))
                                 (cons (cdr (assoc 'name library))
                                       (cdr (assoc 'install_dir library)))))
                             output))
         (selection (let ((completion-extra-properties
                           `(:annotation-function ,(lambda (k) (format " (%s)" (alist-get k lib-dirs nil nil #'string=))))))
                      (arduino-cli--select (seq-map #'car lib-dirs) "Library "))))
    (find-file (alist-get selection lib-dirs nil nil #'string=))))

(defun arduino-cli-new-sketch ()
  "Create a new Arduino sketch."
  (interactive)
  (let* ((name (read-string "Sketch name: "))
         (path (expand-file-name (read-directory-name "Sketch path: ")))
         (cmd  (concat "sketch new " name)))
    (arduino-cli--message cmd path)))

(defun arduino-cli-config-init ()
  "Create a new Arduino config."
  (interactive)
  (when (y-or-n-p "Init will override any existing config files, are you sure? ")
    (arduino-cli--message "config init")))

(defun arduino-cli-config-dump ()
  "Dump the current Arduino config."
  (interactive)
  (arduino-cli--message "config dump"))

(defun arduino-cli-config-directory-browse ()
  "Browse a directory specified in the current Arduino config."
  (interactive)
  (let* ((output    (arduino-cli--cmd-json "config get directories"))
         (dir-keys  (seq-map (lambda (kv) (substring-no-properties (symbol-name (car kv)))) output))
         (selection (let ((completion-extra-properties
                           `(:annotation-function ,(lambda (k) (format " (%s)" (alist-get (intern k) output))))))
                      (arduino-cli--select dir-keys "Directory ")))
         )
    (find-file (alist-get (intern selection) output))))

(defcustom arduino-cli-monitor-buffer-name "arduino cli monitor"
  "The name for the arduino monitor buffer."
  :group 'arduino-cli
  :type 'string)

(defvar arduino-cli--monitor-buffer nil
  "The buffer for the monitor.")

(defvar arduino-cli-monitor-default-baud-rate 115200
  "The default baud rate to listen to for the serial monitor.

It can be overridden by passing a prefix argument to
`#'arduino-cli-start-serial-monitor'.

This must match the value set in your sketch, in a line of code that
looks like Serial.begin(115200).

The arduino will only accept certain values. For more, see
https://www.arduino.cc/reference/it/language/functions/communication/serial/begin/")

(defun arduino-cli--serial-monitor-is-active ()
  "Return t if the monitor is active, nil otherwise."
  (not (not (process-live-p (get-buffer-process arduino-cli--monitor-buffer)))))

(defun arduino-cli--start-serial-monitor-callback (compilation-buffer process-finish-status)
  "Start the serial monitor and remove itself from `compilation-finish-functions'.

It only runs when COMPILATION-BUFFER is
`arduino-cli--compilation-buffer', and PROCESS-FINISH-STATUS is
\"finished\n\", which is what the arduino reports."
  (when (and (eq compilation-buffer
                 arduino-cli--compilation-buffer)
             (string= process-finish-status
                      "finished\n"))
    (remove-hook 'compilation-finish-functions #'arduino-cli--start-serial-monitor-callback)
    (arduino-cli-start-serial-monitor)))

(defun arduino-cli-start-serial-monitor (&optional monitor-baud-rate)
  "Start the arduino serial monitor.

If MONITOR-BAUD-RATE is passed, use that as the baud rate. Otherwise,
use `arduino-cli-monitor-default-baud-rate'."
  (interactive "P")
  (when (arduino-cli--serial-monitor-is-active)
    (arduino-cli-stop-serial-monitor "to restart the serial monitor")
    (while (arduino-cli--serial-monitor-is-active)
      ;; arduino-cli-stop-serial-monitor calls kill-process, which
      ;; kills the process asynchronously, so we need to wait for the
      ;; process to actually end before restarting the monitor.
      (sit-for 0.01)))
  (let ((monitor-buffer (or (and (buffer-live-p arduino-cli--monitor-buffer)
                                 arduino-cli--monitor-buffer)
                            (get-buffer-create arduino-cli-monitor-buffer-name))))
    (unless (eq arduino-cli-verbosity 'quiet)
      (with-current-buffer monitor-buffer
        (insert (format-time-string "\nStarting the monitor at %T...\nTo stop it, press C-c C-c, or run arduino-cli-stop-serial-monitor.\n\n"))))
    (let* ((board (arduino-cli--board))
           (port (if-let (port (arduino-cli--board-address board))
                     port
                   (error "ERROR: No port specified")))
           (async-shell-command-buffer 'confirm-kill-process)
           (shell-command-dont-erase-buffer t)
           (window (async-shell-command (format "arduino-cli monitor --port %s --config baudrate=%s %s"
                                                (shell-quote-argument port)
                                                (shell-quote-argument (format "%d"
                                                                              (or (when monitor-baud-rate (prefix-numeric-value monitor-baud-rate))
                                                                                  arduino-cli-monitor-default-baud-rate)))
                                                (arduino-cli--general-flags))
                                        monitor-buffer)))
      (setf arduino-cli--monitor-buffer (window-buffer window)))))

(defun arduino-cli-stop-serial-monitor (&optional reason)
  "Stop the arduino serial monitor.

If provided, REASON is printed in a message in the buffer."
  (interactive)
  (let ((arduino-monitor-process (get-buffer-process arduino-cli--monitor-buffer)))
    (when (and (bufferp arduino-cli--monitor-buffer)
               (process-live-p arduino-monitor-process))
      (kill-process arduino-monitor-process)
      (unless (eq arduino-cli-verbosity 'quiet)
        (with-current-buffer arduino-cli--monitor-buffer
          (insert (format "\nStopped serial monitor %sat %s...\n\n"
                          (if reason
                              (concat reason " ")
                            "")
                          (format-time-string "%T"))))))))

;;; Minor mode
(defvar arduino-cli-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "c") #'arduino-cli-compile)
    (define-key map (kbd "b") #'arduino-cli-compile-and-upload)
    (define-key map (kbd "u") #'arduino-cli-upload)
    (define-key map (kbd "n") #'arduino-cli-new-sketch)
    (define-key map (kbd "l") #'arduino-cli-board-list)
    (define-key map (kbd "i") #'arduino-cli-lib-install)
    (define-key map (kbd "U") #'arduino-cli-lib-uninstall)
    (define-key map (kbd "k") #'arduino-cli-kill-arduino-connection)
    (define-key map (kbd "m") #'arduino-cli-start-serial-monitor)
    (define-key map (kbd "M") #'arduino-cli-stop-serial-monitor)
    map)
  "Keymap for arduino-cli mode commands after `arduino-cli-mode-keymap-prefix'.")
(fset 'arduino-cli-command-map arduino-cli-command-map)

(defvar arduino-cli-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map arduino-cli-mode-keymap-prefix 'arduino-cli-command-map)
    map)
  "Keymap for arduino-cli mode.")

(defvar arduino-cli--compilation-buffer nil
  "The compilation buffer for the most recent compilation.")

(easy-menu-define arduino-cli-menu arduino-cli-mode-map
  "Menu for arduino-cli."
  '("Arduino-CLI"
    ["New sketch" arduino-cli-new-sketch]
    "--"
    ["Compile Project"            arduino-cli-compile]
    ["Upload Project"             arduino-cli-upload]
    ["Compile and Upload Project" arduino-cli-compile-and-upload]
    "--"
    ["Board list"     arduino-cli-board-list]
    ["Core list"      arduino-cli-core-list]
    ["Core install"   arduino-cli-core-install]
    ["Core uninstall" arduino-cli-core-uninstall]
    "--"
    ["Library list"      arduino-cli-lib-list]
    ["Library install"   arduino-cli-lib-install]
    ["Library uninstall" arduino-cli-lib-uninstall]
    "--"
    ["Core list"      arduino-cli-core-list]
    ["Core install"   arduino-cli-core-install]
    ["Core uninstall" arduino-cli-core-uninstall]
    ["Core upgrade"   arduino-cli-core-upgrade]
    "--"
    ["Config init" arduino-cli-config-init]
    ["Config dump" arduino-cli-config-dump]))

;;;###autoload
(define-minor-mode arduino-cli-mode
  "Arduino-cli integration for Emacs."
  :lighter " arduino-cli"
  :keymap   arduino-cli-mode-map
  :group   'arduino-cli
  :require 'arduino-cli)

(provide 'arduino-cli-mode)
;;; arduino-cli-mode.el ends here
