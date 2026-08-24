(in-package #:rpc-protocol-grpc)

;;; rpc-protocol interaction modes over grpc-protocol.
;;; Wire backends (http2 / native) stay on grpc-protocol; this is the adapter.

(defclass grpc-rpc-transport (rpc-protocol:rpc-transport)
  ((channel :initarg :channel :reader grpc-rpc-channel))
  (:documentation "rpc-transport wrapping a grpc-protocol channel."))

(defclass grpc-rpc-stream (rpc-protocol:rpc-stream)
  ((grpc-stream :initarg :grpc-stream :reader grpc-rpc-stream-inner)))

(defun grpc-rpc-connect (target &key credentials metadata
                         (backend grpc-protocol:*grpc-backend*))
  "Open a gRPC channel and return it as an rpc-transport."
  (make-instance 'grpc-rpc-transport
                 :channel (grpc-protocol:grpc-connect
                           target
                           :credentials credentials
                           :metadata metadata
                           :backend backend)))

(defun use-grpc-rpc-transport (transport)
  (setf rpc-protocol:*rpc-transport* transport)
  transport)

(defmethod rpc-protocol:backend-rpc-call ((transport grpc-rpc-transport) method params
                                          &key timeout id)
  (declare (ignore id))
  (handler-case
      (grpc-protocol:grpc-call (grpc-rpc-channel transport) method params
                               :timeout timeout)
    (grpc-protocol:grpc-error (c)
      (error 'rpc-protocol:rpc-error
             :message (grpc-protocol:grpc-error-message c)
             :code rpc-protocol:+internal-error+
             :data (list :status (grpc-protocol:grpc-error-status c)
                         :details (grpc-protocol:grpc-error-details c))))))

(defmethod rpc-protocol:backend-rpc-notify ((transport grpc-rpc-transport) method params)
  ;; gRPC has no notify; unary and drop the reply.
  (rpc-protocol:backend-rpc-call transport method params)
  t)

(defmethod rpc-protocol:backend-rpc-serve ((transport grpc-rpc-transport) handler &key)
  (declare (ignore handler))
  (error 'rpc-protocol:rpc-error
         :message "gRPC server serve is not implemented on rpc-protocol-grpc"
         :code rpc-protocol:+internal-error+))

(defun %open-stream (transport method mode metadata)
  (make-instance 'grpc-rpc-stream
                 :transport transport
                 :method method
                 :mode mode
                 :grpc-stream (grpc-protocol:grpc-stream
                               (grpc-rpc-channel transport)
                               method
                               :metadata metadata)))

(defmethod rpc-protocol:backend-rpc-call-stream ((transport grpc-rpc-transport) method params
                                                 &key timeout id metadata)
  (declare (ignore timeout id))
  (let ((stream (%open-stream transport method :call-stream metadata)))
    (rpc-protocol:backend-rpc-send stream params)
    stream))

(defmethod rpc-protocol:backend-rpc-client-stream ((transport grpc-rpc-transport) method
                                                   &key timeout id metadata)
  (declare (ignore timeout id))
  (%open-stream transport method :client-stream metadata))

(defmethod rpc-protocol:backend-rpc-bidi-stream ((transport grpc-rpc-transport) method
                                                 &key timeout id metadata)
  (declare (ignore timeout id))
  (%open-stream transport method :bidi-stream metadata))

(defmethod rpc-protocol:backend-rpc-send ((stream grpc-rpc-stream) message &key)
  (grpc-protocol:grpc-send (grpc-rpc-stream-inner stream) message))

(defmethod rpc-protocol:backend-rpc-recv ((stream grpc-rpc-stream) &key timeout)
  (grpc-protocol:grpc-recv (grpc-rpc-stream-inner stream) :timeout timeout))

(defmethod rpc-protocol:backend-rpc-close ((stream grpc-rpc-stream) &key)
  (grpc-protocol:grpc-close (grpc-rpc-stream-inner stream))
  (setf (rpc-protocol:rpc-stream-closed-p stream) t)
  stream)

(defmethod rpc-protocol:backend-rpc-close ((transport grpc-rpc-transport) &key)
  (grpc-protocol:grpc-close (grpc-rpc-channel transport))
  transport)
