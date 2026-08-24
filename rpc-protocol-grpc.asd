(defsystem "rpc-protocol-grpc"
  :version "0.1.0"
  :description "gRPC binding for rpc-protocol (rpc-transport over grpc-protocol)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("rpc-protocol" "grpc-protocol")
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
