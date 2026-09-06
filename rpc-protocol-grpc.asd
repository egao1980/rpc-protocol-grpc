(defsystem "rpc-protocol-grpc"
  :version "0.2.0"
  :description "gRPC binding for rpc-protocol (unary + streams + serve over grpc-protocol)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("rpc-protocol" (:version "grpc-protocol" "0.2.0"))
  :properties (:cl-repo (:ci (:with ("dissect"))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "backend"))
  :in-order-to ((test-op (test-op "rpc-protocol-grpc/tests"))))

(defsystem "rpc-protocol-grpc/tests"
  :depends-on ("rpc-protocol-grpc" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "backend-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
