;;; Install this demo's deps from GHCR and reverse a string with Commons Lang.
;;; JAVA_HOME must be a JDK 25. OpenLDK does not download a JDK on Darwin.
(require :asdf)

(defun %die (fmt &rest args)
  (apply #'format *error-output* fmt args)
  (terpri *error-output*)
  (uiop:quit 1))

(when (find-package :ql)
  (%die "Quicklisp is loaded. Start with ros +Q so installs stay on GHCR."))
(when (find-package :cl+ssl)
  (%die "cl+ssl is already loaded. Start a clean image with ros +Q."))

(let ((home (uiop:getenv "JAVA_HOME")))
  (unless home
    (%die "JAVA_HOME is unset. Point it at a JDK 25."))
  (let ((release (merge-pathnames "release" (uiop:ensure-directory-pathname home))))
    (unless (and (uiop:file-exists-p release)
                 (search "JAVA_VERSION=\"25" (uiop:read-file-string release)))
      (%die "JAVA_HOME is not JDK 25: ~A" home))))

(defvar *systems-root*
  (merge-pathnames "cl-repository/systems/" (uiop:xdg-data-home)))

(defun %version-parts (name)
  (if (string-equal name "latest")
      (list most-positive-fixnum)
      (handler-case
          (mapcar #'parse-integer (uiop:split-string name :separator "."))
        (error () nil))))

(defun %version-dir> (a b)
  (let ((pa (%version-parts (car (last (pathname-directory a)))))
        (pb (%version-parts (car (last (pathname-directory b))))))
    (cond ((and pa pb)
           (loop for x = (or (pop pa) 0)
                 for y = (or (pop pb) 0)
                 do (cond ((> x y) (return t))
                          ((< x y) (return nil)))
                 while (or pa pb)))
          (pa t)
          (t nil))))

(defun %best-version-dirs (root)
  (loop for sys in (uiop:subdirectories root)
        for versions = (uiop:subdirectories sys)
        when versions
          collect (first (sort (copy-list versions) #'%version-dir>))))

(defun %register-sources ()
  "Demo dir, then a cl-repository checkout, then one GHCR version per system.
A :tree of the whole systems root also sees older installs (serdes-protocol
0.2.0 ahead of 0.2.2) and a vendored cl-oci 0.16 client."
  (let ((checkout (merge-pathnames "Projects/lisp/cl-repository/"
                                   (user-homedir-pathname))))
    (asdf:initialize-source-registry
     `(:source-registry
       (:directory ,(namestring (uiop:getcwd)))
       ,@(when (probe-file (merge-pathnames "cl-repository-client.asd" checkout))
           `((:tree ,(namestring checkout))))
       ,@(when (uiop:directory-exists-p *systems-root*)
           (loop for dir in (%best-version-dirs *systems-root*)
                 collect `(:tree ,(namestring dir))))
       :inherit-configuration))))

(%register-sources)

;;; Published cl+ssl binds ASN1_STRING_data. Homebrew openssl (the
;;; /opt/homebrew/opt/openssl symlink) is OpenSSL 4, which dropped that
;;; symbol. Point cl+ssl at openssl@3 before the client loads it.
#+darwin
(when (and (probe-file "/opt/homebrew/opt/openssl@3/lib/libcrypto.dylib")
           (probe-file "/opt/homebrew/opt/openssl@3/lib/libssl.dylib"))
  (asdf:load-system "cffi")
  (asdf:load-system "cl+ssl/config")
  ;; The macros are read after the package exists. A direct call in this
  ;; file would be interned before LOAD-SYSTEM runs.
  (eval (list (find-symbol "DEFINE-LIBCRYPTO-PATH" "CL+SSL/CONFIG")
              "/opt/homebrew/opt/openssl@3/lib/libcrypto.dylib"))
  (eval (list (find-symbol "DEFINE-LIBSSL-PATH" "CL+SSL/CONFIG")
              "/opt/homebrew/opt/openssl@3/lib/libssl.dylib")))

(asdf:load-system "cl-repository-client")
(load (merge-pathnames "scripts/ci/pre-install.lisp" (uiop:getcwd)))
(cl-repo:add-registry "https://ghcr.io" :namespace "egao1980/cl-systems" :priority :prepend)
(let ((needed '("openldk/1.0.2/"
                "java-backend-openldk/0.1.0/"
                "crypto-backend-ironclad/0.2.1/"
                "http-backend-dexador/0.1.5/"
                "iterate/1.6.0/"
                "rove/")))
  (unless (every (lambda (rel)
                   (uiop:directory-exists-p (merge-pathnames rel *systems-root*)))
                 needed)
    (cl-repo:ensure-system-dependencies
     "java-ldk-demo"
     :also-tests t
     :default-source :oci
     :with '("iterate" "java-backend-openldk" "crypto-backend-ironclad" "http-backend-dexador"))))
(%register-sources)
(let ((root (namestring *systems-root*))
      (best (make-hash-table :test #'equal)))
  (dolist (dir (%best-version-dirs *systems-root*))
    (setf (gethash (namestring dir) best) t))
  (asdf:map-systems
   (lambda (sys)
     (let ((src (ignore-errors (namestring (asdf:system-source-directory sys)))))
       (when (and src
                  (eql 0 (search root src))
                  (not (loop for dir being the hash-keys of best
                             thereis (eql 0 (search dir src)))))
         (asdf:clear-system (asdf:component-name sys)))))))
(unless (asdf:find-system "openldk/interop" nil)
  (%die "openldk/interop is not on the ASDF path after the GHCR install."))
(load (merge-pathnames "scripts/ci/pre-test.lisp" (uiop:getcwd)))

;;; OpenLDK src/native/system.lisp sets SB-IMPL::FD-STREAM-FILE-POSITION.
;;; SBCL 2.4.11 package-locks that. 2.6.7 (CI) compiles it. Unlock for the load.
;;; Separate forms: the reader must not see JAVA-LDK-DEMO until LOAD-SYSTEM
;;; has created the package.
#+sbcl
(defmacro %with-locks (&body body)
  `(sb-ext:without-package-locks ,@body))
#-sbcl
(defmacro %with-locks (&body body)
  `(progn ,@body))

(%with-locks
  (asdf:load-system "java-ldk-demo"))

(%with-locks
  (let ((got (java-ldk-demo:reverse-string java-ldk-demo:*sample*)))
    (format t "StringUtils.reverse(~S) => ~S~%" java-ldk-demo:*sample* got)
    (unless (string= got java-ldk-demo:*sample-reversed*)
      (%die "expected ~S, got ~S" java-ldk-demo:*sample-reversed* got)))
  (unless (asdf:test-system "java-ldk-demo")
    (%die "asdf:test-system failed")))

(format t "java-ldk-demo ok~%")
#+sbcl (sb-ext:exit :code 0 :abort t)
#-sbcl (uiop:quit 0)
