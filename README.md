# rpc-protocol-grpc

gRPC **binding** for [`rpc-protocol`](https://github.com/egao1980/rpc-protocol): an `rpc-transport` over [`grpc-protocol`](https://github.com/egao1980/grpc-protocol).

Wire backends stay where they are (`grpc-backend-http2`, `grpc-backend-native`). This repo only maps interaction modes.

| Mode | rpc-protocol | gRPC |
|------|--------------|------|
| `:call-response` | `rpc-call` | unary |
| `:notify` | `rpc-notify` | unary, reply dropped |
| `:call-stream` | `rpc-call-stream` | server stream |
| `:client-stream` | `rpc-client-stream` | client stream |
| `:bidi-stream` | `rpc-bidi-stream` | bidi (`grpc-backend-http2` **0.2.0+** flush-on-first-recv) |

```lisp
(asdf:load-system "grpc-backend-http2")   ; or grpc-backend-native
(asdf:load-system "rpc-protocol-grpc")

(let ((tr (rpc-protocol-grpc:grpc-rpc-connect "localhost:50051"
                                              :credentials :insecure)))
  (unwind-protect
       (rpc-protocol:rpc-invoke "/pkg.Svc/Ping" request :transport tr)
    (rpc-protocol:rpc-close tr)))
```

JSON-RPC is a different repo: [`rpc-protocol-json`](https://github.com/egao1980/rpc-protocol-json).

## License

MIT
