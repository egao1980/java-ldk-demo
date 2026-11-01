(defsystem "java-ldk-demo"
  :version "0.1.0"
  :description "Call Apache Commons Lang from SBCL through java-backend-openldk."
  :author "egao1980"
  :license "MIT"
  :depends-on ("java-backend-openldk"
               "crypto-backend-ironclad"
               "http-backend-dexador")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "demo"))
  :in-order-to ((test-op (test-op "java-ldk-demo/tests")))
  :properties
  ;; serapeum (via OpenLDK) depends on iterate. Client 0.23 leaves a
  ;; non-registry copy in place. :with force-installs the GHCR package.
  (:cl-repo (:ci (:with ("iterate")))))

(defsystem "java-ldk-demo/tests"
  :depends-on ("java-ldk-demo" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "demo-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
