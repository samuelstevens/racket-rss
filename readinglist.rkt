#! /usr/bin/env racket
#lang racket/base

(require json net/url racket/string racket/date)

; json format
; "settings" : {}
; "link": {title, url, viewed}

(struct item (url title date-added))

(define (parse path)
  (define in (open-input-file path))
  (parse-json (read-json in)))

(define (parse-json json)
  ; want to get url, title and addedAt fields, then sort by addedAt
  (define url-keys (filter (lambda (x) (valid-url? (symbol->string x))) (hash-keys json)))
  (define items (map (lambda (url) (parse-item (hash-ref json url))) url-keys))
  (sort items #:key (compose date->seconds item-date-added) <))

(define (parse-item jsexpr)
  (define url (hash-ref jsexpr 'url))
  (define title (hash-ref jsexpr 'title))
  (define date-added (seconds->date (hash-ref jsexpr 'addedAt)))
  (item url title date-added))

(define (valid-url? url-str)
  (and (string-prefix? url-str "http") (regexp-match-positions url-regexp url-str)))

(define (write-items items path)
  (define out (open-output-file path #:exists 'replace))
  (map (lambda (item) 
         (fprintf out "~a,~a\n"
                  (item-url item) 
                  (date->seconds (item-date-added item)))) 
       items)
  (void))

(define (main)
  (cond
    ((eq? (vector-length (current-command-line-arguments)) 0) 
     (displayln "pass a filename as an argument"))
    (else
      (define filename (vector-ref (current-command-line-arguments) 0))
      (define items (parse filename))
      (define outfile "links.txt")
      (printf "Writing links to ~a\n" outfile)
      (write-items items outfile))))

(main)
