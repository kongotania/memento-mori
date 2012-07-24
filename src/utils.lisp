(cl:defpackage #:memento-mori.utils
  (:use :cl)
  (:export
   #:compare-and-swap
   #:without-interrupts
   #:with-interrupts))
(cl:in-package #:memento-mori.utils)

(defmacro compare-and-swap (place old-value new-value)
  #+sbcl
  (let ((old-val-var (gensym "OLD-VALUE-")))
    ` (let ((,old-val-var ,old-value))
        (eq ,old-val-var (sb-ext:compare-and-swap ,place ,old-val-var ,new-value))))
  #+ccl
  `(ccl::conditional-store ,place ,old-value ,new-value)
  #+lispworks
  `(system:compare-and-swap ,place ,old-value ,new-value)
  #+allegro
  `(excl:atomic-conditional-setf ,place ,new-value ,old-value)
  #-(or allegro lispworks ccl sbcl) `(error "Not supported."))

(defmacro without-interrupts (&body body)
  #+sbcl
  `(sb-sys:without-interrupts ,@body)
  #+ccl
  `(ccl:without-interrupts ,@body)
  #-(or ccl sbcl)
  (error "NOT SUPPORTED"))

(defmacro with-interrupts (&body body)
  #+sbcl
  `(sb-sys:allow-with-interrupts
    (sb-sys:with-interrupts
      ,@body))
  #+ccl
  `(ccl:with-interrupts-enabled ,@body)
  #-(or ccl sbcl)
  (error "NOT SUPPORTED"))
