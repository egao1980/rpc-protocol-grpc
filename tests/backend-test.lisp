(in-package #:rpc-protocol-grpc/tests)

(defclass mock-backend (grpc-protocol:grpc-backend) ())

(defclass mock-channel (grpc-protocol:grpc-channel) ())

(defclass mock-stream (grpc-protocol:grpc-stream)
  ((inbox :initarg :inbox :initform nil :accessor mock-inbox)
   (outbox :initform nil :accessor mock-outbox)))

(defmethod grpc-protocol:backend-grpc-connect ((backend mock-backend) target
                                               &key credentials metadata)
  (make-instance 'mock-channel
                 :target target
                 :backend backend
                 :credentials credentials
                 :metadata metadata))

(defmethod grpc-protocol:backend-grpc-call ((channel mock-channel) method request
                                            &key timeout metadata)
  (declare (ignore timeout metadata))
  (list :ok method request (grpc-protocol:grpc-channel-target channel)))

(defmethod grpc-protocol:backend-grpc-stream ((channel mock-channel) method
                                              &key metadata)
  (make-instance 'mock-stream
                 :channel channel
                 :method method
                 :inbox (copy-list (getf metadata :inbox))))

(defmethod grpc-protocol:grpc-send ((stream mock-stream) message &key)
  (push message (mock-outbox stream))
  message)

(defmethod grpc-protocol:grpc-recv ((stream mock-stream) &key timeout)
  (declare (ignore timeout))
  (or (pop (mock-inbox stream)) :eof))

(defun with-mock (fn)
  (let ((grpc-protocol:*grpc-backend* (make-instance 'mock-backend)))
    (funcall fn)))

(deftest connect-call-response
  (with-mock
    (lambda ()
      (let ((tr (rpc-protocol-grpc:grpc-rpc-connect "localhost:1"
                                                    :credentials :insecure)))
        (ok (typep tr 'rpc-protocol:rpc-transport))
        (ok (typep (rpc-protocol-grpc:grpc-rpc-channel tr)
                   'grpc-protocol:grpc-channel))
        (rpc-protocol-grpc:use-grpc-rpc-transport tr)
        (ok (equalp (list :ok "/pkg.Svc/Ping" #(1 2) "localhost:1")
                    (rpc-protocol:rpc-invoke "/pkg.Svc/Ping" #(1 2)
                                             :mode :call-response)))
        (ok (eq t (rpc-protocol:rpc-invoke "/pkg.Svc/Ping" #(9)
                                           :mode :notify)))
        (rpc-protocol:rpc-close tr)
        (ok (grpc-protocol:grpc-channel-closed-p
             (rpc-protocol-grpc:grpc-rpc-channel tr)))))))

(deftest call-stream
  (with-mock
    (lambda ()
      (let* ((tr (rpc-protocol-grpc:grpc-rpc-connect "localhost:1"))
             (s (rpc-protocol:rpc-call-stream "/pkg.Svc/Watch" 'req
                                              :transport tr
                                              :metadata '(:inbox (a b)))))
        (ok (eq :call-stream (rpc-protocol:rpc-stream-mode s)))
        (ok (equal '(req) (mock-outbox (rpc-protocol-grpc:grpc-rpc-stream-inner s))))
        (ok (eq 'a (rpc-protocol:rpc-recv s)))
        (ok (eq 'b (rpc-protocol:rpc-recv s)))
        (ok (eq :eof (rpc-protocol:rpc-recv s)))
        (rpc-protocol:rpc-close s)
        (ok (rpc-protocol:rpc-stream-closed-p s))))))

(deftest client-and-bidi
  (with-mock
    (lambda ()
      (let ((tr (rpc-protocol-grpc:grpc-rpc-connect "localhost:1")))
        (let ((s (rpc-protocol:rpc-invoke "/pkg.Svc/Upload" nil
                                          :mode :client-stream
                                          :transport tr)))
          (ok (eq :client-stream (rpc-protocol:rpc-stream-mode s)))
          (ok (eq 'chunk (rpc-protocol:rpc-send s 'chunk)))
          (rpc-protocol:rpc-close s))
        (let ((s (rpc-protocol:rpc-invoke "/pkg.Svc/Chat" nil
                                          :mode :bidi-stream
                                          :transport tr
                                          :metadata '(:inbox (hi)))))
          (ok (eq :bidi-stream (rpc-protocol:rpc-stream-mode s)))
          (ok (eq 'hi (rpc-protocol:rpc-recv s)))
          (ok (eq 'yo (rpc-protocol:rpc-send s 'yo)))
          (rpc-protocol:rpc-close s))))))

(defclass mock-server (grpc-protocol:grpc-server)
  ((handlers :initarg :handlers :accessor mock-server-handlers)))

(defmethod grpc-protocol:backend-grpc-serve ((backend mock-backend) handlers
                                             &key host port credentials metadata)
  (declare (ignore metadata))
  (let ((s (make-instance 'mock-server
                          :backend backend
                          :host (or host "127.0.0.1")
                          :port (or port 0)
                          :credentials credentials
                          :handlers handlers)))
    (setf (grpc-protocol:grpc-server-running-p s) t)
    s))

(deftest serve-starts-and-stops
  (with-mock
    (lambda ()
      (let* ((tr (rpc-protocol-grpc:grpc-rpc-listen
                  :host "127.0.0.1" :port 8443
                  :credentials '(:ssl :cert "c" :key "k")))
             (stop (rpc-protocol:rpc-serve
                    (lambda (method params)
                      (declare (ignore method))
                      params)
                    :transport tr)))
        (ok (functionp stop))
        (funcall stop)))))

(deftest listen-target
  (with-mock
    (lambda ()
      (let ((tr (rpc-protocol-grpc:grpc-rpc-listen
                 :host "127.0.0.1" :port 9
                 :credentials :ssl)))
        (ok (typep tr 'rpc-protocol-grpc:grpc-rpc-transport))
        (ok (equal "127.0.0.1:9"
                   (grpc-protocol:grpc-channel-target
                    (rpc-protocol-grpc:grpc-rpc-channel tr))))))))
