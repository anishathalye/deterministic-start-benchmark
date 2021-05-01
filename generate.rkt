#lang racket/base

(require "soc.rkt"
         racket/match racket/cmdline racket/string
         racket/port racket/format
         (prefix-in @ (combine-in rosette rosutil))
         yosys shiva)

(@gc-terms!)

(define DEFAULT-TRY-VERIFY-AFTER 0)

(overapproximate-symbolic-load-threshold 64)
(overapproximate-symbolic-store-threshold 64)

(define inputs-symbolic
  '(gpio_pin_in
    uart_rx))

(define inputs-default
  `((gpio_pin_in . ,(@bv 0 8))
    (uart_rx . ,(@bv #xf 4))))

(define statics
  ; for some reason, the picorv32 has a physical register for x0/zero,
  ; cpuregs[0], whose value can never change in practice
  '((cpu.cpuregs 0)))

(define (hints-default q . args)
  (match q
    ['statics statics]
    [_ #f]))

(define abstract-command
  (let ([all-fields (fields (new-zeroed-soc_s))])
    (cons 'abstract (filter (lambda (f) (string-contains? (symbol->string f) "uart.recv_")) all-fields))))

(define (hints-symbolic q . args)
  (match q
    ['statics statics]
    ['general
     (match-define (list cycle sn) args)
     (cond
       [(zero? (modulo cycle 100)) (list abstract-command 'collect-garbage)]
       [else '#f])]))

(define start (make-parameter DEFAULT-TRY-VERIFY-AFTER))
(define limit (make-parameter #f))
(define exactly (make-parameter #f))
(define inputs (make-parameter inputs-default))
(define hints (make-parameter hints-default))
(define output-getters (make-parameter '()))

(command-line
 #:once-each
 [("-s" "--start") s
                   "Start invoking the SMT solver beyond this point"
                   (start (min (start) (string->number s)))]
 [("-l" "--limit") l
                   "Limit number of cycles to try"
                   (limit (string->number l))]
 [("-x" "--exactly") x
                     "Run for exactly this many cycles and then try to verify"
                     (exactly (string->number x))]
 [("-i" "--inputs") "Analyze symbolic inputs"
                    (inputs inputs-symbolic)
                    (hints hints-symbolic)]
 [("-o" "--outputs") "Analyze outputs"
                     (output-getters outputs)])

(define state-getters
  (let ([all-getters (append registers memories)])
    (filter (match-lambda [(cons name _) (regexp-match #rx"^cpu\\." (symbol->string name))])
            all-getters)))

(define racket-template (port->string (open-input-file "verify-template.rkt.tmpl")))
(define sby-template (port->string (open-input-file "verify_template.sby.tmpl")))
(define sv-template (port->string (open-input-file "verify_template.sv.tmpl")))

(define (string-replace* s . args)
  (cond
    [(null? args) s]
    [(apply string-replace* (string-replace s (car args) (cadr args)) (cddr args))]))

(define (debug cycle sn res)
  (define racket-getters '())
  (define sv-assertions '())
  (for ([name (fields sn)])
    (when (and
           (regexp-match #rx"^cpu\\." (symbol->string name))
           (not (regexp-match #rx"alu_out_q" (symbol->string name))))
      (define name-strip (substring (symbol->string name) 4))
      (define value (get-field sn name))
      (cond
        [(vector? value)
         ;; cpuregs
         (for ([reg (in-range 1 32)])
           (define reg-value (vector-ref value reg))
           (when (@unsat? (@concrete reg-value))
             (define upper (sub1 (* 32 (add1 reg))))
             (define lower (* 32 reg))
             (set! sv-assertions (cons (format "assert(cpu1_~a[~a:~a] == cpu2_~a[~a:~a]);"
                                               name-strip
                                               upper
                                               lower
                                               name-strip
                                               upper
                                               lower)
                                       sv-assertions))
             (set! racket-getters
                   (cons (format "(cons '|~a| (lambda (s) (vector-ref (get-field s '|~a|) ~a)))"
                                 name
                                 name
                                 reg)
                         racket-getters))))]
        [else
         ;; bitvec
         (when (@unsat? (@concrete value))
           (set! sv-assertions (cons (format "assert(cpu1_~a == cpu2_~a);" name-strip name-strip) sv-assertions))
           (set! racket-getters (cons
                                 (format "(cons '|~a| (lambda (s) (get-field s '|~a|)))" name name)
                                 racket-getters)))])))
  (define cycles-pad (~r cycle #:min-width 3 #:pad-string "0"))
  (with-output-to-file (format "verify-cycles-~a.rkt" cycles-pad)
    #:exists 'replace
    (lambda ()
      (display
       (string-replace* racket-template
                        "{verify-cycles}" (format "~a" cycle)
                        "{getters}" (format "(list ~a)" (string-join racket-getters))))))
  (with-output-to-file (format "verify_cycles_~a.sby" cycles-pad)
    #:exists 'replace
    (lambda ()
      (display
       (string-replace* sby-template
                        "{skip}" (format "~a" (+ cycle 2))
                        "{depth}" (format "~a" (+ cycle 3))
                        "{sv_filename}" (format "verify_cycles_~a.sv" cycles-pad)))))
  (with-output-to-file (format "verify_cycles_~a.sv" cycles-pad)
    #:exists 'replace
    (lambda ()
      (display
       (string-replace* sv-template
                        "{cycle_count}" (format "~a" (add1 cycle))
                        "{assertions}" (string-join sv-assertions "\n")))))
  #f)

(define cycles
  (verify-deterministic-start
   new-symbolic-soc_s
   #:debug debug
   #:invariant soc_i
   #:step soc_t
   #:reset 'resetn
   #:reset-active 'low
   #:inputs (inputs)
   #:state-getters state-getters
   #:output-getters (output-getters)
   #:hints (hints)
   #:print-style 'names
   #:try-verify-after (or (exactly) (start))
   #:limit (or (exactly) (limit))))

(exit (if cycles 0 1))
