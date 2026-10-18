(in-package :cl-mpm/examples/ice-buoyancy)
(defun plot (sim)
  ;No plotting
  (format t "~A ~%" (local-time:now))
  )
(defun plot-domain ()
  ;No plotting
  (format t "~A ~%" (local-time:now))
  )
(defparameter *nompi* t)

(defun domain-decompose (sim)
  (when (typep sim 'cl-mpm/mpi::mpm-sim-mpi)
    (let ((rank (cl-mpi:mpi-comm-rank)))
      (let ((height 1))
        (let* ((dsize (ceiling (cl-mpi:mpi-comm-size) height))
               (dsize-square (ceiling (sqrt (cl-mpi:mpi-comm-size)) 2)))
          (setf (cl-mpm/mpi::mpm-sim-mpi-domain-count sim)
                (list dsize height 1))))
      (when (= rank 0)
        (format t "Sim MPs: ~a~%" (length (cl-mpm:sim-mps sim)))
        (format t "Decompose~%"))
      (let ((mp-0 (aref (cl-mpm:sim-mps sim) 0)))
        (when (slot-exists-p mp-0 'cl-mpm/particle::local-length)
          (let ((dhalo-size (* 1 (cl-mpm/particle::mp-local-length mp-0))))
	          (setf (cl-mpm/mpi::mpm-sim-mpi-halo-damage-size sim) dhalo-size))))
      (cl-mpm/mpi::setup-domain-bounds *sim*)
      (cl-mpm/mpi::load-balance-algo *sim*
                                     :max-bounds 1.2d0
                                     :exchange-mps nil)
      (format t "Rank ~D - Sim MPs: ~a~%" rank (length (cl-mpm:sim-mps sim))))))

(setf lparallel:*debug-tasks-p* nil)

(let ((threads (parse-integer (if (uiop:getenv "OMP_NUM_THREADS") (uiop:getenv "OMP_NUM_THREADS") "16"))))
  (cl-mpm/utils::set-workers threads)
  (format t "Thread count ~D~%" threads))

(defparameter *name* (if (uiop:getenv "NAME") (uiop:getenv "NAME") "UNNAMED"))
(defparameter *ref* (parse-float:parse-float (if (uiop:getenv "REFINE") (uiop:getenv "REFINE") "1.0")))
(defparameter *height* (parse-float:parse-float (if (uiop:getenv "HEIGHT") (uiop:getenv "HEIGHT") "400")))
(defparameter *floatation* (parse-float:parse-float (if (uiop:getenv "FLOATATION") (uiop:getenv "FLOATATION") "0.9")))
(defparameter *slope* (let ((env (uiop:getenv "SLOPE"))) (parse-float:parse-float (if env env "0.0"))))
(defparameter *enable-viscosity* (if (uiop:getenv "VISC") (string= (uiop:getenv "VISC") "TRUE") nil))

(defparameter *stress* (let ((env (uiop:getenv "STRESS"))) (if env env "ELASTIC")))
(setf *stress*
      (cond ((string= *stress* "CRYO") :CRYO)
            ((string= *stress* "ELASTIC") :ELASTIC)
            (t :NONE)))

(format t "Running~%")

(defparameter *settings* (jonathan:parse (uiop:read-file-string "settings.json")))

;; (defparameter *top-dir* (merge-pathnames "/nobackup/rmvn14/thesis/mici-noremove/"))
;; (defparameter *top-dir* (merge-pathnames "./data/"))
(defparameter *top-dir* (merge-pathnames (getf *settings* :output-dir)))
(defparameter *delay-time* 1d5)
(defparameter *delay-exponent* 2d0)
(defparameter *angle* 38d0)
(defparameter *angle-r* 38d0)
(defparameter *angle-psi* 0d0)
(defparameter *rt* (- 1d0 1d-2))
(defparameter *pd-oversize* 1d-2)
(defparameter *rc* (- 1d0 *pd-oversize*))
(defparameter *gf* 10000d0)
(defparameter *length-scaler* 3d0)
(defparameter *enable-plastic-damage* nil)
(defparameter *ductility* 10d0)

(defparameter *tensile-strength* 0.1d6)
(defparameter *biot-coefficent* 1d0)
(defparameter *alpha* 0.5d0)
(defparameter *material-damping* 0d-3)


(case *stress*
  (:CRYO (setf *alpha* 1d0))
  (:ELASTIC (setf *alpha* 0.5d0)))
(setf *tensile-strength*
      (float
        (parse-float:parse-float (if (uiop:getenv "STRENGTH") (uiop:getenv "STRENGTH") "0.1e6"))
        0d0))





(defun run ()
  (let* ((density 918d0)
         (dt 1d3)
         (water-density 1028d0)
         (height *height*)
         (water-damping 20d0)
         (flotation *floatation*)
         (ratio (parse-float:parse-float (uiop:getenv "NOTCH")))
         (explicit-dt-scale 0.5d0)
         (ice-aspect 4d0)
         (erode nil)
         (debug nil)
         )
    (let* ((mps 3)
           (output-dir (merge-pathnames (format nil "./output-~A-~D-~f-~f-~A-~F/" *name* *ref* height flotation *stress* ratio) *top-dir*)))
      (format t "Outputting to ~A~%" output-dir)
      (format t "Problem ~f ~f~%" height flotation)
      (let* ()
        (setup :refine *ref*
               :multigrid-refines 0
               :friction 0.5d0
               :bench-length 0d0
               :ice-height height
               :bench-length (* ratio height)
               :mps mps
               :hydro-static nil
               :cryo-static (eq *stress* :CRYO) 
               :elastic-static (eq *stress* :ELASTIC)
               :melange nil
               :aspect ice-aspect
               :slope *slope*
               :floatation-ratio flotation)

        (when *nompi* 
          ;; (change-class *sim* 'cl-mpm/dynamic-relaxation::mpm-sim-dr-dynamic)
          (change-class *sim* 'cl-mpm/dynamic-relaxation::mpm-sim-dr-damage-ul)
          )
        (unless *nompi* 
          (change-class *sim* 'cl-mpm/dynamic-relaxation::mpm-sim-damage-quasi-static-mpi)
          (domain-decompose *sim*))

                                        ;(push (list :SCALAR "water-pressure" #'cl-mpm/particle::mp-pressure) (cl-mpm::sim-output-list *sim*))
        (cl-mpm::domain-sort-mps *sim*)
        (reduced-output-data *sim*)

        (plot-domain)

        (setf (cl-mpm/damage::sim-enable-ekl *sim*) nil)
        (setf (cl-mpm::sim-enable-fbar *sim*) t)
        (setf (cl-mpm/damage::sim-enable-length-localisation *sim*) t)
        (setf (cl-mpm::sim-allow-mp-split *sim*) t
              (cl-mpm::sim-max-split-depth *sim*) 3)

        (setf (cl-mpm/aggregate::sim-enable-aggregate *sim*)  t
              (cl-mpm::sim-ghost-factor *sim*) nil)

        (setf (cl-mpm:sim-settings *sim*)
              (list :OCEAN-HEIGHT *water-height*
                    :EXPLICIT-DT-SCALE explicit-dt-scale
                    :EKL  (cl-mpm/damage::sim-enable-ekl *sim*)
                    :LENGTH-LOCALISATION  (cl-mpm/damage::sim-enable-length-localisation *sim*)
                    :PLASTIC-DAMAGE-DRIVING *enable-plastic-damage* 
                    :PLASTIC-DAMAGE-OVERSIZE *pd-oversize*
                    :DELAY-TIME *delay-time*
                    :DELAY-EXP *delay-exponent*
                    :ANGLE *angle*
                    :ANGLE-R *angle-r*
                    :ANGLE-PSI *angle-psi*
                    :WATER-DAMPING water-damping
                    :ALPHA *alpha*
                    :BIOT *biot-coefficent*
                    :R-T *rt*
                    :R-C *rc*
                    :GF *gf*
                    :LENGTH-SCALER *length-scaler*))


        (cl-mpm/setup::set-mass-filter *sim* 918d0 :proportion 1d-15)

        (let ((step 0)
              (total-time 1d7)
              (substeps (* 1 (floor height 100) (floor (cl-mpm/mesh::mesh-resolution (cl-mpm:sim-mesh *sim*)) 10d0))))
          (format t "Substeps ~D~%" substeps)
          (cl-mpm/dynamic-relaxation::run-multi-stage
           *sim*
           :output-dir output-dir
           :dt dt
           :conv-dt-scale 0.9d0
           :dt-scale 0.9d0
           :damping-factor (sqrt 2d0)
           :conv-criteria 1d-3
           :conv-load-steps 1
           :min-adaptive-steps -20
           :max-adaptive-steps 20
           :adaption-constant 2
           :easy-step-adaption-constant 4
           :max-damage-inc 0.9d0
           :min-tangent-ratio 1d-1
           :max-deformation-gradient 2d0
           :max-plastic-inc nil
           ;; :max-inertia-norm 1d-3
           :stagger-damage :HYBRID-FULL
           :substeps substeps
           :sub-conv-steps 100
           :total-time total-time
           :save-vtk-loadstep t
           :save-vtk-dr nil
           :enable-plastic t
           :enable-damage t
           :plotter (lambda (sim))
           :explicit-conv-criteria 1d-3
           :elastic-dt-margin 1d2
           :explicit-mass-scaling nil
           :explicit-damping-factor 1d-4
           :explicit-dt-scale explicit-dt-scale
           :explicit-output-frequency 1
           :explicit-dynamic-solver 'cl-mpm/damage::mpm-sim-agg-damage
           :post-conv-step
           (lambda (sim)
             (setf (cl-mpm/bc::bc-enable *bc-erode*) erode)
             (cl-mpm/buoyancy::bc-viscous-damping *water-bc*) water-damping)
           :setup-quasi-static
           (lambda (sim)
             (setf
              (cl-mpm::sim-velocity-algorithm sim) :QUASI-STATIC)
             (setf
              (cl-mpm/buoyancy::bc-viscous-damping *water-bc*) water-damping))
           :setup-dynamic
           (lambda (sim)
             (setf
              (cl-mpm/damage::sim-damage-delocal-counter-max sim) 2
              (cl-mpm/buoyancy::bc-viscous-damping *water-bc*) water-damping
              (cl-mpm::sim-velocity-algorithm sim) :TBLEND)))
          )))))

(run)
