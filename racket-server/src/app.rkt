#lang racket
(require web-server/servlet-env
         web-server/http
         net/url-structs
         json
         racket/string)

(require "canonical-json.rkt"
         "transpiler.rkt"
         "syntax-checking.rkt"
         "sexpr-read.rkt"
         "zipper.rkt"
         "search-strategy.rkt"
         "search-runtime.rkt")

(provide step! back! reset! init! init-session!
         make-stepper step step-name
         session session-zipper session-stepper session-nqv session-search-strategy
         source-convert!)

(define (request->payload req)
  (bytes->jsexpr (request-post-data/raw req)))

(define (payload->source-options payload)
  (define source-mode
    (normalize-source-mode (hash-ref payload 'sourceMode default-source-mode)))
  (define compile-profile
    (normalize-compile-profile (hash-ref payload 'compileProfile #f)
                               source-mode))
  (values source-mode compile-profile))

(define (payload->search-strategy payload)
  (normalize-search-strategy (hash-ref payload 'searchStrategy #f)))

(define-struct step (name prog) #:transparent)
(define-struct session 
  ([zipper #:mutable] 
   [stepper #:mutable]
   [nqv #:mutable]
   [search-strategy #:mutable #:auto])
  #:transparent
  #:auto-value default-search-strategy)
(define session-table (make-hash))


;; init-session!: session program -> void
;; Purpose: Initializes all of the state variables
(define (init-session! s p)
  (let ([z (session-zipper s)])
    (zipper-init! z)
    (zipper-add! z (step "Initialize Program" p))
    (set-session-nqv! s (num-query-vars/canonical p))))


;; step->response: step nat nat-> response
;; Purpose: Creates a response with the given step and index
(define (step->response a-step a-idx nqv)
  (match-let ([(step name prog) a-step])
    (let ([response (hasheq 'stepName name
                            'step a-idx
                            'program (to-json/canonical prog nqv))])
      (response/jsexpr response #:mime-type #"application/json; charset=utf-8"))))


;; step->response/initial: step nqv -> response
;; Purpose: Sends the first tree in the history (init-state) with a header indicating it is the initial one
(define (step->response/initial a-step nqv)
  (match-let ([(step name prog) a-step])
    (let ([response (hasheq 'stepName name
                            'step 0
                            'program (to-json/canonical prog nqv))])
      (response/jsexpr response
                       #:mime-type #"application/json; charset=utf-8"
                       #:headers (list (make-header #"X-Is-Last" #"true"))))))


;; step/html->response: step string string nat -> response
;; Purpose: Send the initial tree and the html embedded program. Sets the cookies for the new session.
(define (step/html/cookie->response a-step tagged-prog session-id nqv)
  (match-let ([(step name prog) a-step])
    (let ([response (hasheq 'stepName name
                            'step 0
                            'program (to-json/canonical prog nqv)
                            'htmlGuids tagged-prog)])
      (response/jsexpr response
                       #:mime-type #"application/json; charset=utf-8"
                       #:headers (list (make-header #"Set-Cookie"
                                                    (string->bytes/utf-8 (format "session-id=~a; Path=/; SameSite=Lax" session-id))))))))


;; send-end-step: -> response
;; Purpose: Send a response with a header indicating the program can no longer step
(define (send-end-step)
  (response/jsexpr (json-null)
                   #:mime-type #"application/json; charset=utf-8"
                   #:headers (list (make-header #"X-Done" #"true"))))


;; [Term Nat -> [Listof [List String Term]]] -> [zipper -> response]
(define (make-stepper step-term)
  (lambda (z nqv)
    (let ([maybe-next (zipper-next! z)]
          [idx (zipper-idx z)])
      (if (false? maybe-next) ;; Nothing in forward cache
          (match (step-term (step-prog (zipper-curr z)))
            ['() (send-end-step)]
            [(cons (list name new-prog) _)
             (define new-step (step name new-prog))
             (zipper-add! z new-step)
             (step->response new-step (add1 idx) nqv)])
          (step->response maybe-next idx nqv)))))


;; step!: session -> response
;; Purpose: Applies one reduction step and sends the new JSON data of that tree
(define (step! ses) 
  (match-let ([(session zip step nqv _) ses])
    (step zip nqv)))

(define (bind-session-search-strategy! ses strategy)
  (define normalized (normalize-search-strategy strategy))
  (set-session-search-strategy! ses normalized)
  (set-session-stepper! ses (make-stepper (lookup-search-step-once normalized)))
  normalized)

;; init!: session request string -> response
;; Purpose: To initialize the given session
(define (init! ses req ses-id)
  (define payload (request->payload req))
  (define raw-prog (hash-ref payload 'text))
  (define-values (source-mode compile-profile)
    (payload->source-options payload))
  (define search-strategy
    (payload->search-strategy payload))
  (when (equal? source-mode "mini")
    (check-syntax-capture-error raw-prog))
  (define sexpr-prog (read-all-sexprs (open-input-string raw-prog)))   ;; Read the program into sexpressions
  (define-values (model-prog html-prog)
    (parse-prog/canonical sexpr-prog
                          #:source-mode source-mode
                          #:compile-profile compile-profile))
  (unless (canonical-target-in-domain? model-prog canonical-parser-target-id)
    (error 'init! (format "transpiler produced a program outside canonical target ~a"
                          canonical-parser-target-id)))
  (check-canonical-well-formed model-prog canonical-parser-target-id)
  (check-search-config search-strategy model-prog)
  (bind-session-search-strategy! ses search-strategy)
  (init-session! ses model-prog)                                       ;; Initialize all state variables
  (match-define (session zip _ nqv _) ses)                             ;; Get zipper and number query vars
  (define init-step (zipper-curr zip))                                ;; Get the initial program
  (step/html/cookie->response init-step html-prog ses-id nqv))        ;; Send the initial program and HTML


;; reset!: session hash string -> response
;; Purpose: Resets the given session to the initial state of its program
(define (reset! ses ses-table ses-id)
  (match-let ([(session zip _ nqv _) ses])
    (define response (match zip
                       [(zipper prev _ _ _) 
                        #:when (cons? prev)
                        (let ([init-prog (last prev)])
                          (zipper-init! zip)
                          (zipper-add! zip init-prog)
                          (step->response/initial (zipper-curr zip) nqv))]
                       [(zipper _ curr _ _) 
                        #:when (step? curr)
                        (step->response/initial curr nqv)]))
    (hash-remove! ses-table ses-id)
    response))


;; back!: session -> response
;; Purpose: Sends the previous step if it exists and updates the state.
;;          If there is no prevous step, sends the current step w/ header.
(define (back! ses)
  (let* ([zipper (session-zipper ses)]
         [nqv (session-nqv ses)]
         [maybe-back (zipper-back! zipper)]
         [idx (zipper-idx zipper)])
    (match maybe-back
      [(initial s) (step->response/initial s nqv)]
      [s #:when (step? s) (step->response s idx nqv)]
      [_ (step->response maybe-back idx nqv)])))

(define (source-convert! req)
  (define payload (request->payload req))
  (define raw-prog (hash-ref payload 'text))
  (define target-source-mode
    (normalize-source-mode (hash-ref payload 'targetSourceMode "micro")))
  (unless (equal? target-source-mode "micro")
    (error 'source-convert!
           (format "unsupported target source mode: ~a" target-source-mode)))
  (define-values (source-mode compile-profile)
    (payload->source-options payload))
  (when (equal? source-mode "mini")
    (check-syntax-capture-error raw-prog))
  (define sexpr-prog (read-all-sexprs (open-input-string raw-prog)))
  (response/jsexpr
   (hasheq 'source
           (render-micro-source sexpr-prog
                                #:source-mode source-mode
                                #:compile-profile compile-profile))
   #:mime-type #"application/json; charset=utf-8"
   #:code 200))


;; get-or-create-session-id: req -> string
;; Purpose: Gets the session id from cookies or creates a new one
(define (cookie-field->string v)
  (cond
    [(string? v) v]
    [(bytes? v) (bytes->string/utf-8 v)]
    [(symbol? v) (symbol->string v)]
    [else (format "~a" v)]))

(define (get-or-create-session-id req)
  (or
   (for/first ([c (in-list (request-cookies req))]
               #:when (string=? (cookie-field->string (client-cookie-name c))
                                "session-id"))
     (cookie-field->string (client-cookie-value c)))
   (symbol->string (gensym 'sess-))))


;; get-session: string -> session
(define (get-session session-id)
  (hash-ref session-table session-id
            (lambda ()
              (define new-session (session (zipper '() #f '() 0) 
                                           (make-stepper (lookup-search-step-once
                                                          default-search-strategy))
                                           1))
              (hash-set! session-table session-id new-session)
              new-session)))


;; get-path: request -> string
;; Purpose: Gets the path that was pinged as it was on the javascript side
(define (get-path req)
  (string-join (map path/param-path (url-path (request-uri req))) "/"))

;; dispatcher: request -> response
;; Purpose: Maps the input request to an output response
(define (dispatcher req)
  (let* ([session-id (get-or-create-session-id req)]
         [session (get-session session-id)])
    (match (get-path req)
      ["get/next"   (step! session)]
      ["post/init"  (init! session req session-id)]
      ["post/reset" (reset! session session-table session-id)]
      ["post/back"  (back! session)]
      ["post/source-convert" (source-convert! req)])))

(define (handled-dispatcher req)
  (with-handlers
      [(exn:fail?
        (λ (e)
          (response/jsexpr (hasheq 'error (exn-message e)) #:code 400)))]
    (dispatcher req)))



(module+ main
  ;; Start the server on port 5000
  (serve/servlet handled-dispatcher
                 #:port 5000
                 #:servlet-regexp #rx""
                 #:listen-ip "0.0.0.0" ; any
                 #:launch-browser? #f)
  )
