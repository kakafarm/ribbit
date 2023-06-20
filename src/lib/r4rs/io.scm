(##include-once "./error.scm")
(##include-once "./char.scm")
(##include-once "./pair-list.scm")
(##include-once "./vector.scm")
(##include-once "./types.scm")
(##include-once "./bool.scm")

(cond-expand
  ((host js)

   (define-primitive
     (##stdin)
     (use js/node/fs)
     "() => push(0),")

   (define-primitive
     (##stdout)
     (use js/node/fs)
     "() => push(1),")

   (define-primitive 
     (##get-fd-input-file filename)
     (use js/node/fs scm2str)
     "prim1(filename => fs.openSync(scm2str(filename), 'r')),")

   (define-primitive
     (##get-fd-output-file filename)
     (use js/node/fs scm2str)
     "prim1(filename => fs.openSync(scm2str(filename), 'w')),")

   (define-primitive
     (##read-char fd)
     (use js/node/fs)
     "prim1(fd => {
     let buf=Buffer.alloc(1); 
     let ch=fs.readSync(fd, buf) === 0 ? NIL : buf[0]; 
     return ch;
     }),")

   (define-primitive
     (##write-char ch fd)
     (use js/node/fs)
     "prim2((fd, ch) => fs.writeSync(fd, String.fromCodePoint(ch), null, 'utf8')),")

   (define-primitive
     (##close-input-port fd)
     (use js/node/fs)
     "prim1(fd => fs.closeSync(fd)),")

   (define-feature 
     ##close-output-port
     (use ##close-input-port))

   (define ##close-output-port ##close-input-port))
   
  ((host c)

   (define-primitive
     (##stdin)
     (use c/stdio)
     "{
     FILE* file = fdopen(0, \"r\");
     push2((long) file | 1, PAIR_TAG);
     break;
     }")

   (define-primitive
     (##stdout)
     (use c/stdio)
     "{
     FILE* file = fdopen(1, \"w\");
     push2((long) file | 1, PAIR_TAG);
     break;
     }")

   (define-primitive 
     (##get-fd-input-file filename)
     (use c/stdio scm2str)
     "{
     PRIM1();
     char* filename = scm2str(x);
     FILE* file = fopen(filename, \"r\");
     if (file == NULL) perror(\"Couldn't open the file\\n\");
     push2((long) file | 1, PAIR_TAG);
     free((void*) filename);
     break;
     }")

   (define-primitive
     (##get-fd-output-file filename)
     (use c/stdio scm2str)
     "{
     PRIM1();
     char* filename = scm2str(x);
     FILE* file = fopen(filename, \"w\");
     push2((long) file | 1, PAIR_TAG);
     free((void *) filename);
     break;
     }")

   (define-primitive
     (##read-char fd)
     (use c/stdio)
     "{
     PRIM1();
     FILE* file = (FILE*) ((long) x ^ 1);
     char buffer[1];
     int bytes_read = fread(buffer, 1, 1, file);
     if (!bytes_read) push2(NIL, PAIR_TAG);
     else push2(TAG_NUM(buffer[0]), PAIR_TAG);
     break;
     }")

   (define-primitive
     (##write-char ch fd)
     (use c/stdio)
     "{
     PRIM2();
     FILE* file = (FILE*) ((long) y ^ 1);
     char buffer[1] = {(char) NUM(x)};
     int success = fwrite(buffer, 1, 1, file);
     if (success != 1) {
     perror(\"WHAT\");
     }
     fflush(file);
     push2(TRUE, PAIR_TAG);
     break;
     }")

   (define-primitive
     (##close-input-port fd)
     (use c/stdio)
     "{
     PRIM1();
     FILE* file = (FILE*) ((long) x ^ 1);
     fclose(file);
     break;
     }")

   (define ##close-output-port ##close-input-port))

  ((host hs)

   (define-feature hs/io-handle (hs/foreign-type "    | RibHandle !Handle"))

   (define-primitive
     (##stdin)
     (use hs/io-handle)
     " , push . RibForeign $ RibHandle stdin")

   (define-primitive
     (##stdout)
     (use hs/io-handle)
     " , push . RibForeign $ RibHandle stdout")

   (define-primitive 
     (##get-fd-input-file filename)
     (use hs/io-handle scm2str)
     " , prim1 $ \\filename -> scm2str filename >>= (\\x -> openFile x ReadMode) >>= (pure . RibForeign . RibHandle)")

   (define-primitive
     (##get-fd-output-file filename)
     (use hs/io-handle scm2str)
     " , prim1 $ \\filename -> scm2str filename >>= (\\x -> openFile x WriteMode) >>= (pure . RibForeign . RibHandle)")

   (define-primitive
     (##read-char fd)
     (use hs/io-handle)
     " , prim1 $ \\(RibForeign (RibHandle handle)) -> hIsEOF handle >>= \\eof -> if eof then return ribNil else hGetChar handle >>= (pure . RibInt . ord)")

   (define-primitive
     (##write-char ch fd)
     (use hs/io-handle)
     " , prim2 $ \\(RibInt ch) (RibForeign (RibHandle handle)) -> hPutChar handle (chr ch) >> pure ribTrue")

   (define-primitive
     (##close-input-port fd)
     (use hs/io-handle)
     " , prim1 $ \\(RibForeign (RibHandle handle)) -> hClose handle >> pure ribTrue")

   (define ##close-output-port ##close-input-port)))

;; ---------------------- EOF & TYPES ---------------------- ;;

(define ##eof (##rib 0 0 5))

(define (eof-object? obj)
  (##eqv? obj ##eof))

(define stdin-port
  (##rib (##stdin) (##rib 0 '() #t) input-port-type)) ;; stdin

(define stdout-port
  (##rib (##stdout) #t output-port-type))  ;; stdout


;; ---------------------- INPUT ---------------------- ;;

(define (open-input-file filename)
  ;; (file_descriptor, (cursor, last_char, is_open), input_file_type)
  (##rib (##get-fd-input-file filename) (##rib 0 '() #t) input-port-type))

(define (close-input-port port)
  (if (##field2 (##field1 port))
    (begin 
      (##field2-set! (##field1 port) #f)
      (##close-input-port (##field0 port)))))

(define (##get-last-char port)
  (##field1 (##field1 port)))

(define (##set-last-char port ch)
  (##field1-set! (##field1 port) ch))

(define (input-port-close? port)
  (not (##field2 (##field1 port))))

(define (current-input-port)
  stdin-port)

(define (call-with-input-file filename proc)
  (let* ((port (open-input-file filename))
         (result (proc port)))
    (close-input-port port)
    result))

(define (read-char (port (current-input-port))) 
  (if (input-port-close? port) (crash))
  (let ((last-ch (##get-last-char port)))
    (if (null? last-ch)

      (let ((ch (##read-char (##field0 port))))
        (if (null? ch) ##eof (integer->char ch)))

      (begin
        (##set-last-char port '())
        last-ch))))

(define (peek-char (port (current-input-port)))
  (let ((ch (read-char port)))
    (##set-last-char port ch)
    ch))

;; ---------------------- READ ---------------------- ;;

(define special-chars '(("newline" #\newline) 
                        ("space" #\space) 
                        ("tab" #\tab)
                        ("return" #\return)))

(define (read (port (current-input-port)))

  (let ((c (peek-char-non-whitespace port)))
    (cond ((eof-object? c) c)
          ((##eqv? c 40)            ;; #\(
           (read-char port)
           (read-list port))
          ((##eqv? c 35)            ;; #\#
           (read-char port) ;; skip "#"
           (let ((c (##field0 (peek-char port))))
             (cond ((##eqv? c 102)  ;; #\f
                    (read-char port) ;; skip "f"
                    #f)
                   ((##eqv? c 116)     ;; #\t
                    (read-char port) ;; skip "t"
                    #t)
                   ((##eqv? c 92)        ;; #\\
                    (read-char port) ;; skip "\\"
                    (let ((ch (peek-char port)))
                      (if (char-whitespace? ch) 
                        (read-char port)
                        (let* ((str (##list->string (read-symbol port)))
                               (ch (assoc str special-chars)))
                          (if (not ch)
                            (integer->char (caar str))
                            (cadr ch))))))
                   (else
                     (list->vector (read port))))))
          ((##eqv? c 39)      ;; #\'
           (read-char port) ;; skip "'"
           (list 'quote (read port)))
          ((##eqv? c 96)      ;; #\`
           (read-char port) ;; skip "`"
           (list 'quasiquote (read port)))
          ((##eqv? c 44)      ;; #\,
           (read-char port) ;; skip ","
           (let ((c (##field0 (peek-char port))))
             (if (##eqv? c 64)  ;; #\@
               (begin
                 (read-char port) ;; skip "@"
                 (list 'unquote-splicing (read port)))
               (list 'unquote (read port)))))
          ((##eqv? c 34)      ;; #\"
           (read-char port) ;; skip """
           (##list->string (read-chars '() port)))
          (else
            ;; (read-char port) ;; skip first char
            (let ((s (##list->string (read-symbol port))))
              (let ((n (string->number s)))
                (or n
                    (string->symbol s))))))))

(define (read-list port)
  (let ((c (peek-char-non-whitespace port)))
    (cond 
      ((##eqv? c 41) ;; #\)
       (read-char port) ;; skip ")"
       '())
      (else (let ((first (read port)))
              (if (and (symbol? first) (equal? (symbol->string first) "."))
                (let ((result (read port)))
                  (read-char port)
                  result)
                (cons first (read-list port))))))))

(define (read-symbol port)
  ;; FIXME: change char-downcase to char-upcase
  (let ((c (##field0 (char-downcase (peek-char port)))))
    (if (or (##eqv? c 40)  ;; #\(
            (##eqv? c 41)  ;; #\)
            (##eqv? c 0)   ;; eof
            (##< c 33))    ;; whitespace
        '()
        (begin
          (read-char port)
          (cons c (read-symbol port))))))

(define (read-chars lst port)
  (let ((c (##field0 (read-char port))))
    (cond ((##eqv? c 0) '())   ;; eof
          ((##eqv? c 34) (reverse lst))  ;; #\"
          ((##eqv? c 92)                 ;; #\\
           (let ((c2 (##field0 (read-char port))))
             (read-chars
              (##rib (cond
                     ;#; ;; support for \n in strings
                     ((##eqv? c2 110) 10) ;; #\n
                     ;#; ;; support for \r in strings
                     ((##eqv? c2 114) 13) ;; #\r
                     ;#; ;; support for \t in strings
                     ((##eqv? c2 116) 9)  ;; #\t
                     (else          c2))
                    lst 0)
              port)))
          (else
           (read-chars (cons c lst) port)))))

(define (peek-char-non-whitespace port)
  (let ((c (peek-char port)))
    (if (eof-object? c) ;; eof?
      c
      (if (char-whitespace? c) 
        (begin
          (read-char port)
          (peek-char-non-whitespace port))
        (if (##eqv? (##field0 c) 59) ;; #\;
          (skip-comment port)
          (##field0 c))))))  ;; returns the code point of the char

(define (skip-comment port)
  (let ((c (read-char port)))
    (if (eof-object? c)
        c
        (if (##eqv? (##field0 c) 10) ;; #\newline
            (peek-char-non-whitespace port)
            (skip-comment port)))))


;; ---------------------- OUTPUT ---------------------- ;;

(define (open-output-file filename)
  ;; (file_descriptor, is_open, write_file_type)
  (##rib (##get-fd-output-file filename) #t output-port-type))

(define (close-output-port port)
  (if (##field1 port)
    (begin
      (##field1-set! port #f)
      (##close-output-port (##field0 port)))))

(define (current-output-port) stdout-port)

(define (output-port-close? port)
  (not (##field1 port)))

(define (call-with-output-file filename proc)
  (let* ((port (open-output-file filename))
         (result (proc port)))
    (close-output-port port)
    result))

(define (write-char ch (port (current-output-port)))
  (##write-char (##field0 ch) (##field0 port)))

(define (newline (port (current-output-port)))
  (##write-char 10 (##field0 port)))  ;; #\newline

(define (write o (port (current-output-port)))
  (let ((port-val (##field0 port)))
    (cond ((string? o)
           (##write-char 34 port-val)     ;; #\"
           (write-chars (##field0 o) port-val)
           (##write-char 34 port-val))    ;; #\"
          ((char? o)
           (##write-char 35 port-val)     ;; #\#
           (##write-char 92 port-val)     ;; #\\
           (let ((name (assoc o (map reverse special-chars)))) 
             (if (not name)
               (##write-char (##field0 o) port-val)
               (display (cadr name) port))))
          (else
            (display o port)))))

(define (display o (port (current-output-port)))
  (let ((port-val (##field0 port)))
    (cond ((not o)
           (##write-char 35 port-val)     ;; #\#
           (##write-char 102 port-val))   ;; #f

          ((##eqv? o #t)
           (##write-char 35 port-val)     ;; #\#
           (##write-char 116 port-val))   ;; #t

          ((eof-object? o)
           (##write-char 35 port-val)     ;; #\#
           (##write-char 101 port-val))   ;; #e

          ((null? o)
           (##write-char 40 port-val)  ;; #\(
           (##write-char 41 port-val)) ;; #\)

          ((integer? o)
           (display (number->string o) port))

          ((input-port? o)
           (display (vector (##field0 o) (##field2 (##field1 o)) (##field2 o))))

          ((output-port? o)
           (display (vector (##field0 o) (##field1 o) (##field2 o))))

          ((char? o)
           (##write-char (##field0 o) port-val))

          ((pair? o)
           (##write-char 40 port-val)  ;; #\(
           (write (##field0 o) port) ;; car
           (write-list (##field1 o) port) ;; cdr
           (##write-char 41 port-val)) ;; #\)

          ((symbol? o)
           (write-chars (##field0 (##field1 o)) port-val))

          ((string? o)
           (write-chars (##field0 o) port-val)) ;; chars

          ((vector? o)
           (##write-char 35 port-val)  ;; #\#
           (##write-char 40 port-val)  ;; #\(
           (if (##< 0 (##field1 o))
             (let ((l (##field0 o)))   ;; vector->list
               (write (##field0 l) port)
               (write-list (##field1 l) port)))
           (##write-char 41 port-val)) ;; #\)

          ((procedure? o)
           (##write-char 35 port-val)  ;; #\#
           (##write-char 112 port-val)) ;; #p

          (else
            (crash)))))

(define (write-list lst port)
  (cond 
    ((pair? lst)
     (##write-char 32 (##field0 port)) ;; #\space
     ;; (if (pair? lst)
     ;;   (begin
         (write (##field0 lst) port) ;; car
         (write-list (##field1 lst) port))  ;; cdr
       ;; #f))

    ((null? lst) #f)

    (else
      (let ((port-val (##field0 port)))
        (##write-char 32 port-val) ;; #\space
        (##write-char 46 port-val) ;; #\.
        (##write-char 32 port-val)) ;; #\space
      (write lst port))))


(define (write-chars lst port-val)
  (if (pair? lst)
      (let ((c (##field0 lst))) ;; car
        (##write-char c port-val)
        (write-chars (##field1 lst) port-val)))) ;; cdr

