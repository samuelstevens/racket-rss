#lang racket/base

(require 
  racket/sequence 
  racket/port
  racket/format
  racket/string
  racket/function
  racket/contract
  html 
  json
  net/url 
  "readability.rkt")

; region PROVIDE

(define (optional/c type?)
  (or/c 'null type?))

(provide (contract-out
           (struct item 
                   ((url url?)
                    (title (optional/c string?))
                    (content (optional/c string?))
                    (date-added date?)))))

(provide (contract-out
           (parse-link-file (-> (or/c path? string?) (listof item?)))
           (get-item-content (-> item? item?))
           (make-feed (-> (listof item?) jsexpr?))))

; endregion

(struct item (url title content date-added))

(define (parse-link-file path)
  (define in (open-input-file path))
  (define line-seq (sequence-filter (compose not empty?) (in-lines in)))
  (define lines (map (lambda (s) (string-split s ",")) (sequence->list line-seq)))
  (map (curry apply parse-article-to-read) lines))

(define (empty? s)
  (eq? (string-length s) 0))

(define (parse-article-to-read link date)
  (cond
    ((string? date) (parse-article-to-read link (string->number date)))
    (else
      (item (string->url link) 'null 'null (seconds->date date)))))

; region HTML

(define (get-item-content prev-item)
  (define url (item-url prev-item))
  (define html (get-html url))
  (item url (get-title html) (parse-content (url->string url) html) (item-date-added prev-item)))

(define (get-html url)
  (cond 
    ((not (url? url)) (get-html (string->url url))) 
    (else
      (port->string (get-pure-port url)))))

(define (get-title html-str)
  (define regexp #rx"<title>(.*)</title>")
  (define match (regexp-match regexp html-str))
  (cond
    ((eq? match #f) "")
    (else (car (cdr match)))))

; endregion

; region FEED

(define (make-feed items)
  (hash 'items (map item->jsexpr items) 
        'title "Reading List" 
        'version "https://jsonfeed.org/version/1.1"))

(define (item->jsexpr item) 
  (hash 'id (url->string (item-url item))
        'title (item-title item)
        'content_text (item-content item)
        'date_published (date->rfc (item-date-added item))))

(define (two-digits number)
  (~a number #:min-width 2 #:align 'right #:left-pad-string "0"))

(define (date->rfc date)
  (apply (curry format "~a-~a-~aT~a:~a:~a-00:00" (date-year date))
         (map two-digits
              (list
                (date-month date)
                (date-day date)
                (date-hour date)
                (date-minute date)
                (date-second date)))))

; endregion

; region TEST

(module+ test
  (require rackunit)
  (check-equal? (two-digits 4) "04")
  (check-equal? (two-digits 10) "10")
  (check-equal? (date->rfc (seconds->date 0)) "1969-12-31T19:00:00-00:00"))

; endregion
