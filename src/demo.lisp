(in-package #:java-ldk-demo)

(defparameter *commons-lang-coordinates* "org.apache.commons:commons-lang3:3.17.0")

;;; SHA-256 of the Maven Central jar (no .sha256 sidecar is published).
(defparameter *commons-lang-jar-sha256*
  "6ee731df5c8e5a2976a1ca023b6bb320ea8d3539fbe64c8a1d5cb765127c33b4")

(defparameter *sample* "OpenLDK")
(defparameter *sample-reversed* "KDLnepO")

(defun reverse-string (text)
  "Reverse TEXT with org.apache.commons.lang3.StringUtils.reverse.
DigestUtils is not used: OpenLDK has no java.security.MessageDigest."
  (check-type text string)
  (unless (find-package '#:openldk.interop)
    (error "OpenLDK runtime is not loaded. Needs SBCL outside Windows and JDK 25."))
  (ldk:add-maven-jar *commons-lang-coordinates* :sha256 *commons-lang-jar-sha256*)
  (ldk:lstring
   (ldk:jstatic "org.apache.commons.lang3.StringUtils"
                "reverse(Ljava/lang/String;)"
                (ldk:jstring text))))

(defun run (&optional (text *sample*))
  "Print StringUtils.reverse of TEXT. Returns the Lisp string."
  (let ((reversed (reverse-string text)))
    (format t "~A~%" reversed)
    reversed))
