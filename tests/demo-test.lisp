(in-package #:java-ldk-demo/tests)

(deftest commons-lang-reverse
  (if (find-package '#:openldk.interop)
      (ok (string= *sample-reversed* (reverse-string *sample*)))
      (skip "OpenLDK runtime is not loaded on this Lisp")))
