(cl:defpackage #:memento-mori.example.misc
  (:use #:cl #:alexandria #:memento-mori))
(cl:in-package #:memento-mori.example.misc)

(defun speed-test (scheduler
                   &key
                     (message-count 100000)
                     (actor-count 10))
  (flet ((handler (x)
           (let ((counter (car x))
                 (start-time (cdr x)))
             (if (> counter 0)
                 (send (current-actor) (cons (1- counter) start-time))
                 (print `(stop time ,(/ (- (get-internal-real-time) start-time)
                                        internal-time-units-per-second 1.0)))))))
    (loop
       repeat actor-count
       for actor = (spawn #'handler :scheduler scheduler)
       for message = (cons message-count (get-internal-real-time))
       do (send actor message)))
  scheduler)

(defun selective-receive-test (scheduler)
  (let ((actor (spawn (lambda (msg)
                        (format t "~&Got a message: ~a~%" msg)
                        (receive-cond (msg)
                          ((eq msg 'two)
                           (format t "~&Got another message: ~a~%" msg)
                           (receive-cond (msg)
                             ((eq msg 'three)
                              (format t "~&Got a third message: ~a~%" msg)))))
                        (format t "~&This is never printed.~%"))
                      :scheduler scheduler)))
    (send actor 'one)
    (send actor 'two)
    (send actor 'three)
    (send actor 'four)))

(defun local-exit-test (scheduler)
  (let ((actor (spawn (lambda (msg)
                        (print "Got a message")
                        (exit msg)
                        (print "After exit"))
                      :scheduler scheduler)))
    (send actor 'fail)
    (send actor 'again)
    (sleep 1)
    actor)
  scheduler)

(defun remote-exit-test (scheduler)
  (let* ((victim (spawn (lambda (msg)
                          (print "Got a message")
                          (print msg)
                          (sleep 5)
                          (print "Completed!"))
                        :scheduler scheduler))
         (bad-guy (spawn (lambda (msg)
                           (print "I got scheduled, too!")
                           (exit msg victim)
                           (print "message sent"))
                         :scheduler scheduler)))
    (send victim 'hi)
    (send bad-guy 'mwahahaaaa)
    (sleep 1)
    (send victim 'rip)
    (sleep 1)
    (print (actor-alive-p victim))
    (print (actor-alive-p bad-guy)))
  scheduler)

(defun trap-exits-test (scheduler)
  (let ((trapping (spawn (lambda (msg)
                           (print msg)
                           (sleep 1)
                           (print "Done"))
                         :scheduler scheduler
                         :trap-exits-p t)))
    (send trapping 'hello)
    (sleep 1)
    (send (spawn (rcurry #'exit trapping) :scheduler scheduler) 'regular-exit)
    (sleep 1)
    (send trapping 'gonnadiesoon)
    (sleep 1)
    (kill trapping)
    (sleep 1)
    (actor-alive-p trapping)
    scheduler))

(defun links-test (n scheduler)
  (labels ((chain (n)
             (cond ((= n 0)
                    (error "I can't take this anymore!"))
                   (t
                    (send (spawn #'chain :linkp t) (1- n))))))
    (send
     (spawn (let ((start-time (get-internal-real-time)))
              (lambda (msg)
                (if (integerp msg)
                    (chain msg)
                    (let ((total (/ (- (get-internal-real-time) start-time)
                                    internal-time-units-per-second)))
                      (format t "~&Chain done. ~a actors in ~f seconds (~f/s).~%"
                              n total (/ n total))))))
            :trap-exits-p t
            :scheduler scheduler)
     n)
    scheduler))

(defun monitor-test (scheduler)
  (let ((observer (spawn (lambda (msg)
                           (if (monitor-exit-p msg)
                               (print msg)
                               (exit msg (spawn #'print :monitorp t))))
                         :scheduler scheduler)))
    (send observer 'bye)))

(defun debugger-test (scheduler)
  (let ((actor (spawn (lambda (msg)
                        (send (spawn (curry #'error "Dying from ~a."))
                              msg))
                      :scheduler scheduler
                      :debugp t
                      :trap-exits-p t)))
    (loop repeat 5 do (send actor 'fail))))
