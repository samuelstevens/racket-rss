#lang racket/base

(require racket/contract racket/system racket/port json)
(provide (contract-out
           (parse-content (-> string? string? (or/c 'null string?)))))

(define readability.js "readability.js")

(define (parse-content url html) 
  (define node (find-executable-path "node"))
  (let-values (((sp o i _) 
                (subprocess #f #f 'stdout node readability.js url)))
    (displayln html i)
    (close-output-port i)
    ; (define err (port->string e))
    ; TODO: handle errors

    (define parsed (read-json o))
    (close-input-port o)
    (cond
      ((hash-has-key? parsed 'error) 'null)
      (else
        (hash-ref parsed 'content)))))

(module+ testing
  (require rackunit)
  (define (test-file)
    (open-input-file "lofi"))

  (define test-url "https://jblevins.org/log/lofi"))


