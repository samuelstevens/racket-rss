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
  racket/date
  json
  xml
  net/url 
  racket/serialize
  "readability.rkt")

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

(define (item->xexpr i)
  `(item () 
         (title () ,(item-title i))
         (link () ,(url->string (item-url i)))
         (description () ,(item-content i))
         (pubDate () ,(date->rfc-822 (item-date-added i)))
         (guid () ,(url->string (item-url i)))))

(define (url->filename u)
  (define path (path/param->filename (url-path u)))
  (if (empty? path) 
      (url-host u) 
      (string-append (url-host u) "-" path)))

(define (path/param->filename p)
  (string-join (map path/param-path p) "-"))


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
      (define content (parse-content (url->string url) html))
      (cond
        ((json-null? content) (item url 
                               (get-title html) 
                               (source-link url (get-title html))
                               (item-date-added prev-item)))
        (else
          (item url 
                (get-title html) 
                (add-read-more (clean-content content) url (get-title html))
                (item-date-added prev-item)))))))

(define (json-null? jsexpr)
  (eq? 'null jsexpr))

(define (clean-content content)
  (regexp-replace* #rx"(<br/>\\s*)+" content "<br/>"))

(define (source-link url title)
  (format "<a href=\"~a\">Source</a>" (url->string url)))

(define (add-read-more content url title)
  (string-append content (source-link url title)))

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

(define (make-json-feed items)
  (hash 'items (map item->jsexpr items) 
        'title "Reading List" 
        'version "https://jsonfeed.org/version/1.1"))

(define (make-xml-feed items)
  `(rss ((version "2.0")) 
        (channel ()
                 (title () "Reading List")
                 (link () "https://samuelstevens.me/readinglist.xml")
                 (description () "My personal reading list")
                 (language () "en-us")
                 (pubDate () ,(date->rfc-822 (current-date)))
                 (lastBuildDate () ,(date->rfc-822 (current-date)))
                 (docs () "https://cyber.harvard.edu/rss/rss.html")
                 (generator () "samuelstevens/racket-rss")
                 (managingEditor () "samuel.robert.stevens@gmail.com")
                 (webMaster () "samuel.robert.stevens@gmail.com")
                 ,@(map item->xexpr items))))

(define (date->rfc-822 d)
  ; https://www.w3.org/Protocols/rfc822/#z28
  (parameterize ((date-display-format 'rfc2822))
    (define time (format "~a:~a:~a ~a" 
                         (two-digits (date-hour d)) 
                         (two-digits (date-minute d))
                         (two-digits (date-second d))
                         "UT"))
    (format "~a ~a" (date->string d) time)))

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

; region SCRIPT

(define cache-dir (make-parameter (string->path "/users/samstevens/iCloud/reading-list-cache")))
(define feed-file (make-parameter (string->path "feed.json")))

(define (main filename)
  (define items (map (compose write-item get-item-content) (parse-link-file filename)))
  (display-to-file (xexpr->string (make-xml-feed items)) (feed-file) #:exists 'replace))

(define (script)
  (cond
    ((eq? (vector-length (current-command-line-arguments)) 0) 
     (displayln "pass a filename as an argument"))
    (else
      (parameterize ((feed-file (string->path "/users/samstevens/Development/personal-website/readinglist.xml")))
        (define filename (vector-ref (current-command-line-arguments) 0))
        (main filename)))))

(script)

; endregion

; region TEST

(module+ test
  (require rackunit)
  (check-equal? (two-digits 4) "04")
  (check-equal? (two-digits 10) "10")
  (check-equal? (date->rfc (seconds->date 0)) "1969-12-31T19:00:00-00:00")
  (check-equal? (url->filename (string->url "https://duckduckgo.com")) "duckduckgo.com")
  (check-equal? (path/param->filename (url-path (string->url "https://duckduckgo.com"))) "")
  (check-pred xexpr? (make-xml-feed '()))
  (check-pred xexpr? (make-xml-feed (list (item (string->url "https://google.com") "hello world" "" (current-date)))))
)

; endregion
