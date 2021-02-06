#! /usr/bin/env racket
#lang racket/base

(require 
  racket/sequence 
  racket/port
  racket/format
  racket/string
  racket/function
  racket/contract
  racket/file
  html 
  json
  net/url 
  racket/serialize
  "readability.rkt")

; region PROVIDE

(define (optional/c type?)
  (or/c 'null type?))

(provide (contract-out
          (parse-link-file (-> (or/c path? string?) (listof item?)))
          (get-item-content (-> item? item?))
          (make-feed (-> (listof item?) jsexpr?))))

; endregion

; region ITEM

(serializable-struct item (url title content date-added))

(define (item-cache-file item)
  (build-path (cache-dir) (string->path (url->filename (item-url item)))))

(define (item->jsexpr item) 
  (hash 'id (url->string (item-url item))
        'url (url->string (item-url item))
        'title (item-title item)
        'content_text (item-content item)
        'date_published (date->rfc (item-date-added item))))

(define (url->filename u)
  (define path (path/param->filename (url-path u)))
  (if (empty? path) 
      (url-host u) 
      (string-append (url-host u) "-" path)))

(define (path/param->filename p)
  (string-join (map path/param-path p) "-"))

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

(define (rfc->date) (void))

; endregion

(define (parse-link-file path)
  (map (curry apply parse-article-to-read) 
       (map (lambda (s) (string-split s ",")) 
            (sequence->list (sequence-filter (compose not empty?) 
                                             (in-lines (open-input-file path)))))))

(define (parse-article-to-read link date)
  (cond
    ((string? date) (parse-article-to-read link (string->number date)))
    ((> date 32503680000) (parse-article-to-read link (/ date 1000))) ; if past year 3000, it's probably in milliseconds.
    (else
     (item (string->url link) 'null 'null (seconds->date date)))))

(define (empty? s)
  (eq? (string-length s) 0))

; region DISK

(define (write-item i)
  (write-to-file (serialize i) (item-cache-file i) #:exists 'replace)
  i)

; endregion

; region HTML

(define (get-item-content prev-item)
  (cond
    ((downloaded? prev-item) (get-cached prev-item))
    (else
      (define url (item-url prev-item))
      (define html (get-html url))
      (item url 
            (get-title html) 
            (parse-content (url->string url) html) 
            (item-date-added prev-item)))))

(define (downloaded? item)
  (cond
    ((not (directory-exists? (cache-dir))) (make-directory (cache-dir)) 
                                         (downloaded? item))
    (else (file-exists? (item-cache-file item)))))

(define (get-cached prev-item)
  (deserialize (read (open-input-file (item-cache-file prev-item)))))

(define (get-html url)
  (cond 
    ((not (url? url)) (get-html (string->url url))) 
    (else
     (port->string (get-pure-port url #:redirections 5)))))

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


; endregion

; region SCRIPT

(define cache-dir (make-parameter (string->path "/users/samstevens/iCloud/reading-list-cache")))
(define feed-file (make-parameter (string->path "feed.json")))

(define (main)
  (cond
    ((eq? (vector-length (current-command-line-arguments)) 0) 
     (displayln "pass a filename as an argument"))
    (else
      (define filename (vector-ref (current-command-line-arguments) 0))
      (define items (map (compose write-item get-item-content) (parse-link-file filename)))
      (parameterize ((feed-file (string->path "/users/samstevens/Development/personal-website/readinglist.json")))
        (display-to-file (jsexpr->string (make-feed items)) (feed-file) #:exists 'replace)))))

(main)

; endregion

; region TEST

(module+ test
  (require rackunit)
  (check-equal? (two-digits 4) "04")
  (check-equal? (two-digits 10) "10")
  (check-equal? (date->rfc (seconds->date 0)) "1969-12-31T19:00:00-00:00")
  (check-equal? (url->filename (string->url "https://duckduckgo.com")) "duckduckgo.com")
  (check-equal? (path/param->filename (url-path (string->url "https://duckduckgo.com"))) "")
)

; endregion
