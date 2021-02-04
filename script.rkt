#! /usr/bin/env racket
#lang racket/base

(require "main.rkt" json)

; main entry point for the script

(define (main)
  (cond
    ((eq? (vector-length (current-command-line-arguments)) 0) 
     (displayln "pass a filename as an argument"))
    (else
      (define filename (vector-ref (current-command-line-arguments) 0))
      (define items (map get-item-content (parse-link-file filename)))
      (define feed (make-feed items))
      (define out (open-output-file "feed.json"))
      (displayln (jsexpr->string feed) out))))

(main)

