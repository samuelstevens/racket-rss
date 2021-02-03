#lang racket/base

(require racket/sequence)

; the module is the main entry point

(struct item (id ; typically url
              url ; optional
              title
              content ; either content_html or content_text
              summary ; optional
              date-published ; date in RFC 3339 "2010-02-07T14:04:00-05:00"
              ))

(define (parse-input path)
  (define in (open-input-file path))
  (sequence-map parse-link 
                (sequence-filter 
                  (lambda (line) (not (equal? "" line))) 
                  (in-lines in))))

(define (parse-link link)
  ; TODO: remove # at the end of urls
  ; TODO: verify that it is in fact a link
  link)


(struct article (link title content))

; link -> article
(define (get-article link) 
  (error "not implemented"))
  
