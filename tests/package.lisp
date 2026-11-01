(defpackage #:java-ldk-demo/tests
  (:use #:cl #:rove)
  ;; JAVA-LDK-DEMO:RUN clashes with ROVE:RUN.
  (:import-from #:java-ldk-demo
                #:reverse-string
                #:*sample*
                #:*sample-reversed*))
