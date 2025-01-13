globals [
  grid-x-inc               ;; the amount of patches in between two roads in the x direction
  grid-y-inc               ;; the amount of patches in between two roads in the y direction
  ticks-at-last-change  ; value of the tick counter the last time a light changed

  current-intersection
  intersections
  roads
  non-priority-color
  total-waiting-time

  total-priority-waiting-time   ;; Sum of waiting times for priority vehicles
  average-priority-waiting-time ;; Average waiting time for priority vehicles
  total-priority-vehicles  ;; Global variable to store total number of priority vehicles ever created
  total-accidents
]

breed [ lights light ]
lights-own [
  traffic-input          ; number of cars arriving at this light
  traffic-output         ; number of cars passing through this light
  traffic-input-prioritary
  traffic-output-prioritary
  input-patch            ; the patch where the cars are coming from
  cars-waiting-time      ; how many ticks the cars have been waiting total
  avg-waiting-time       ; average waiting time of cars
  waiting-time           ; how many ticks the cars have been waiting since the last light change

  cars-waiting-time-reset ; average waiting time of cars that resets after lights-time-ticks ticks
  traffic-input-reset     ; traffic input that resets after lights-time-ticks ticks
  avg-wait-time-list     ; list of avg-waiting-time-reset values
]

breed [ accidents accident ]
accidents-own [
  clear-in              ; how many ticks before an accident is cleared
]

breed [ cars car ]
cars-own [
  speed                 ; how many patches per tick the car moves
  priority?             ; if the vehicle is prioritary
  last-light            ; the last light the car passed
  waiting-time          ; how many ticks the car has been waiting
]

patches-own [
  intersection?
  green-light-up?
  my-row
  my-col
  output-patch
  vehicles-here
]

;;;;;;;;;;;;;;;;;;;;
;;SETUP PROCEDURES;;
;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all

  random-seed 42

  ; Check if the number of neighbors asked is allowed by the grid size
  if ( multi-agent? and neighbors-asked > (grid-size-x - 1) and neighbors-asked > (grid-size-y - 1)) [
    print "The number of neighbors asked must be less than the grid_size-1 "
    stop
  ]

  if ((density-weight + waiting-time-weight + priority-vehicle-weight) > 100 or  (density-weight + waiting-time-weight + priority-vehicle-weight) < 100 )[
    print "Density, waiting-time and priority vehicle agent weights should add to 100% "
    stop
  ]



  set-default-shape lights "square"
  set-default-shape accidents "fire"
  set-default-shape cars "car"

  setup-globals
  setup-patches
  make-current one-of intersections
  label-current

  reset-ticks
end

to setup-globals
  set current-intersection nobody
  set ticks-at-last-change 0
  set grid-x-inc world-width / grid-size-x
  set grid-y-inc world-height / grid-size-y
  set non-priority-color  [blue green yellow orange cyan magenta turquoise violet]
  set total-waiting-time 0
  set total-priority-waiting-time 0
  set total-priority-vehicles 0
  set total-accidents 0

  random-seed 47822
end

to setup-patches
  ask patches [
    set intersection? false
    set green-light-up? true
    set my-row -1
    set my-col -1
    set pcolor green - 1
  ]

  set roads patches with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) or
    (floor((pycor + max-pycor) mod grid-y-inc) = 0) ]
  set intersections roads with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) and
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]

  ask roads [ set pcolor black ]
  setup-intersections
end

to setup-intersections
  ask intersections
  [
    set intersection? true
    set green-light-up? true
    set my-row (pycor + max-pycor) / grid-y-inc
    set my-col (pxcor + max-pxcor - floor(grid-x-inc - 1)) / grid-x-inc
    set-signal-colors
    set output-patch patch-at 0 0
    ;ask output-patch [ set pcolor yellow ]
    set vehicles-here 0
  ]
end

to set-signal-colors
  let y-dist floor(grid-y-inc - 2)  ; distance to start of the road
  let x-dist floor(grid-x-inc - 2) * -1 ; distance to start of the road in the x direction

  ifelse green-light-up? [
    ask patch-at -1 0 [
      sprout-lights 1 [
        set color red
        set traffic-input 0
        set traffic-output 0
        set traffic-input-prioritary 0
        set traffic-output-prioritary 0
        set input-patch patch-at x-dist 0
        ask input-patch [ set pcolor blue ]
        set cars-waiting-time 0
        set avg-waiting-time 0
        set waiting-time 0

        set cars-waiting-time-reset 0
        set avg-wait-time-list []
        set traffic-input-reset 0
      ]
    ]
    ask patch-at 0 1 [
      sprout-lights 1 [
        set color green
        set traffic-input 0
        set traffic-output 0
        set traffic-input-prioritary 0
        set traffic-output-prioritary 0
        set input-patch patch-at 0 y-dist
        ask input-patch [ set pcolor blue ]
        set cars-waiting-time 0
        set avg-waiting-time 0
        set waiting-time 0
        set cars-waiting-time-reset 0
        set avg-wait-time-list []
        set traffic-input-reset 0
      ]
    ]
  ] [
    ask patch-at -1 0 [
      sprout-lights 1 [
        set color green
        set traffic-input 0
        set traffic-output 0
        set traffic-input-prioritary 0
        set traffic-output-prioritary 0
        set input-patch patch-at x-dist 0
        ask input-patch [ set pcolor blue ]
        set cars-waiting-time 0
        set avg-waiting-time 0
        set waiting-time 0
        set cars-waiting-time-reset 0
        set avg-wait-time-list []
        set traffic-input-reset 0
      ]
    ]
    ask patch-at 0 1 [
      sprout-lights 1 [
        set color red
        set traffic-input 0
        set traffic-output 0
        set traffic-input-prioritary 0
        set traffic-output-prioritary 0
        set input-patch patch-at 0 y-dist
        ask input-patch [ set pcolor blue ]
        set cars-waiting-time 0
        set avg-waiting-time 0
        set waiting-time 0

        set cars-waiting-time-reset 0
        set avg-wait-time-list []
        set traffic-input-reset 0
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;
;;RUNTIME PROCEDURES;;
;;;;;;;;;;;;;;;;;;;;;;

to go
  ask cars [ move ]

  check-for-collisions
  spawn-car-on-road freq-north 180 "north"
  spawn-car-on-road freq-west 90 "west"

  if allow-priority? [
    check-priority-vehicles
  ]

  if adaptive-density? [
    adaptive-adjustment
  ]

  if adaptive-waiting-time? [
    adaptive-adjustment-time
  ]

  if priority-score? [
    adaptive-priority-score
  ]

  ;ask cars[print (word "X: " pxcor " Y: " pycor)]
  ; Display input/output for each light
  ask lights [
    set label (word "In: " traffic-input " Out: " traffic-output)
    if (traffic-input > 0) [
      set avg-waiting-time cars-waiting-time / traffic-input
      ; If enough ticks have passed, store the average waiting time and reset the counters
      if( ticks mod lights-time-ticks = 0) [
        let temp-time 0
        ifelse (traffic-input-reset = 0) [ set temp-time 1 ] [ set temp-time traffic-input-reset ]
        let temp-avg cars-waiting-time-reset / temp-time
        set avg-wait-time-list lput temp-avg avg-wait-time-list
        set cars-waiting-time-reset 0
        set traffic-input-reset traffic-input - traffic-output
      ]
    ]
  ]

  if multi-agent? [
    mult-agent
  ]

  ; Handle light changes
  if auto? and elapsed? green-length [
    change-to-yellow
  ]
  if any? lights with [ color = yellow ] and elapsed? yellow-length [
    change-to-red
  ]
  tick
end

to mult-agent
  ask intersections[
    let info nobody
    set info get-intersections-info self

    let left-score item 0 info
    let up-score item 1 info

    if left-score > up-score [
      let north-light one-of lights-on patch-at 0 1
      if north-light != nobody and ([color] of north-light = green) [
        ask north-light [ set color yellow ]
      ]
    ]
    if left-score < up-score [
      let east-light one-of lights-on patch-at -1 0
      if east-light != nobody and ([color] of east-light = green) [
        ask east-light [ set color yellow ]
      ]
    ]
  ]
end

to adaptive-adjustment ; adjust the lights based on the traffic density
  ask intersections [
    let south-density intersection-traffic-density-south self
    let east-density intersection-traffic-density-east self
    ;print (word "For intersection at x: " my-col " y: " my-row)
    ;print (word "South density: " south-density " East density: " east-density)
    if south-density > east-density [
      let east-light one-of lights-on patch-at -1 0
      if east-light != nobody and ([color] of east-light = green) [
        ask east-light [ set color yellow ]
      ]
    ]
    if south-density < east-density [
      let south-light one-of lights-on patch-at 0 1
      if south-light != nobody and ([color] of south-light = green) [
        ask south-light [ set color yellow ]
      ]
    ]
  ]
end

to adaptive-adjustment-time
  ask intersections [
    let north-light one-of lights-on patch-at 0 1
    let east-light one-of lights-on patch-at -1 0

    ;print (word "North light waiting time: " [waiting-time] of north-light)
    ;print (word "East light waiting time: " [waiting-time] of east-light)

    if [waiting-time] of north-light > [waiting-time] of east-light [
      if [color] of east-light = green [
        ask east-light [ set color yellow ]
      ]
    ]
    if [waiting-time] of north-light < [waiting-time] of east-light [
      if [color] of north-light = green [
        ask north-light [ set color yellow ]
      ]
    ]
  ]
end

to adaptive-priority-score
  ; ask each intersection the to-report priority-score [intersection-patch]
  ask intersections [
    ; print the priority score for each intersection
    ; print (word "Priority score for intersection at x: " my-col " y: " my-row " is: " priority-score self)
    let left-score item 0 priority-score self
    let up-score item 1 priority-score self

    if left-score > up-score [
      let north-light one-of lights-on patch-at 0 1
      if north-light != nobody and ([color] of north-light = green) [
        ask north-light [ set color yellow ]
      ]
    ]
    if left-score < up-score [
      let east-light one-of lights-on patch-at -1 0
      if east-light != nobody and ([color] of east-light = green) [
        ask east-light [ set color yellow ]
      ]
    ]
  ]
end

to spawn-car-on-road [ freq h direction ]
  ;; Choose a random road patch in the desired direction to spawn cars
  if random-float 100 < freq [
    let candidate-patch nobody

    if direction = "north" [
      set candidate-patch one-of roads with [ pycor = max-pycor ]  ;; Top row of roads
    ]
    if direction = "west" [
      set candidate-patch one-of roads with [ pxcor = min-pxcor ]  ;; Right column of roads
    ]

    if candidate-patch != nobody and not any? turtles-on candidate-patch [
      create-cars 1 [
        setxy [pxcor] of candidate-patch [pycor] of candidate-patch
        set heading h
        set color one-of non-priority-color
        set last-light nobody
        set waiting-time 0
        adjust-speed
        set priority? random-float 100 < 2  ;; 2% chance to be a priority vehicle
        if priority? [ set color red ] ;; A car with priority is red
        if priority? [  ;; If the turtle has priority, increase the global count
            set total-priority-vehicles total-priority-vehicles + 1
       ]
      ]
    ]
  ]
end

to move ; turtle procedure
  adjust-speed
  repeat speed [ ; move ahead the correct amount
    let car-pos patch-here
    let car-color color
    ; Update traffic and output count
    if any? lights-here [
      let current-light one-of lights-here
      ask current-light [
        ;if color = green or ((color = yellow ) and (car-pos = patch-here)) [
          set traffic-output traffic-output + 1 ; Car passed
          if (car-color = red)[
            set traffic-output-prioritary traffic-output-prioritary + 1
          ]
        ;]
      ]
    ]

    fd 1
    if not can-move? 1 [ die ] ; die when I reach the end of the world
    if any? accidents-here [
      ; if I hit an accident, I cause another one
      ask accidents-here [ set clear-in 5 ]
      die
    ]
  ]

  if speed = 0 [
      set waiting-time waiting-time + 1
      set total-waiting-time total-waiting-time + 1

    if priority?[
      set total-priority-waiting-time total-priority-waiting-time + 1
    ]
  ]

  let car-x pxcor
  let car-y pycor
  let car-last-light last-light
  let car-speed speed
  let car-color color
  ; Update traffic input
  ; Check if the car is on a light and if it's not the same light as the last one
    ask lights [
      if (car-last-light != self)[ ;; if the car is not on the same light
        let light-x [pxcor] of self
        let light-y [pycor] of self
        let input-patch-x [pxcor] of input-patch
        let input-patch-y [pycor] of input-patch
        ; see if the car is between the light and the input patch
        if (car-x >= min (list light-x input-patch-x) and car-x <= max (list light-x input-patch-x)) and
           (car-y >= min (list light-y input-patch-y) and car-y <= max (list light-y input-patch-y)) [
          set traffic-input traffic-input + 1
          set traffic-input-reset traffic-input-reset + 1
          set car-last-light self
        ]
        if (car-x >= min (list light-x input-patch-x) and car-x <= max (list light-x input-patch-x)) and
           (car-y >= min (list light-y input-patch-y) and car-y <= max (list light-y input-patch-y)) and (car-color = red)[
          set traffic-input-prioritary traffic-input-prioritary + 1
        ]
      ]
      if (car-last-light = self ) and (car-speed = 0) [
        ; if the car is on the same light as the last one, update the last-light-waiting variable
          set cars-waiting-time cars-waiting-time + 1
          set waiting-time waiting-time + 1
          set cars-waiting-time-reset cars-waiting-time-reset + 1
      ]
    ]
    set last-light car-last-light


end

to adjust-speed
  ; calculate the minimum and maximum possible speed I could go
  let min-speed max (list (speed - max-brake) 0)
  let max-speed min (list (speed + max-accel) speed-limit)

  let target-speed max-speed ; aim to go as fast as possible

  let blocked-patch next-blocked-patch
  if blocked-patch != nobody [
    ; if there is an obstacle ahead, reduce my speed
    ; until I'm sure I won't hit it on the next tick
    let space-ahead (distance blocked-patch - 1)
    while [
      breaking-distance-at target-speed > space-ahead and
      target-speed > min-speed
    ] [
      set target-speed (target-speed - 1)
    ]
  ]

  set speed target-speed
end

to-report breaking-distance-at [ speed-at-this-tick ] ; car reporter
  ; If I was to break as hard as I can on the next tick,
  ; how much distance would I have travelled assuming I'm
  ; currently going at `speed-this-tick`?
  let min-speed-at-next-tick max (list (speed-at-this-tick - max-brake) 0)
  report speed-at-this-tick + min-speed-at-next-tick
end

to-report next-blocked-patch ; turtle procedure
  ; check all patches ahead until I find a blocked
  ; patch or I reach the end of the world
  let patch-to-check patch-here
  while [ patch-to-check != nobody and not is-blocked? patch-to-check ] [
    set patch-to-check patch-ahead ((distance patch-to-check) + 1)
  ]
  ; report the blocked patch or nobody if I didn't find any
  report patch-to-check
end

to-report is-blocked? [ target-patch ] ; turtle reporter
  report
    any? other cars-on target-patch or
    any? accidents-on target-patch or
    any? (lights-on target-patch) with [ color = red ] or
    (any? (lights-on target-patch) with [ color = yellow ] and
      ; only stop for a yellow light if I'm not already on it:
      target-patch != patch-here)
end

to-report traffic-light-affecting
  ;; Reports the light affecting the current vehicle (self)
  let relevant-light nobody
  let target-patch patch-ahead 1

  ;; If the vehicle is already at a traffic light
  ifelse any? lights-on patch-here [
    set relevant-light one-of lights-on patch-here
  ]
  [  ;; Loop through patches in the direction of travel to find a light
    while [target-patch != nobody and relevant-light = nobody] [
      if any? lights-on target-patch [
        set relevant-light one-of lights-on target-patch
      ]
      set target-patch patch-ahead (distance target-patch + 1)
  ]
]

  report relevant-light
end


;; To check if a priority vehicle is in the queue for the given traffic light
to-report priority-vehicle-waiting?
  let is-priority-waiting false

  ask cars with [priority? and speed = 0] [
    ; Car aligned with any northbound light
    if any? patches with [pxcor = [xcor] of myself and pycor < [ycor] of myself] [
      set is-priority-waiting true
    ]

    ; Car aligned with any westbound light
    if any? patches with [pycor = [ycor] of myself and pxcor > [xcor] of myself] [
      set is-priority-waiting true
    ]
  ]

  if is-priority-waiting [
    ;print "Priority vehicle waiting!"
  ]

  report is-priority-waiting
end


;; Change color to green asap
to check-priority-vehicles

  ask lights [
    let priority-vehicle-detected false

;; Check all cars to see if they are affected by this light
    ask cars [
      let affecting-light traffic-light-affecting
      if affecting-light = myself and priority? [ ;; only for prioritary
        set priority-vehicle-detected true
      ]

    ]

if priority-vehicle-detected and color != green [
      ;print (word "Priority vehicle detected at light " who ". Changing to green.")
      set color green

       ;; Turn intersecting lights red
      ask lights-on neighbors [
        if color != red [
          ;print (word "Setting neighboring light " who " to red.")
          set color red
        ]
      ]
    ]
  ]
end

to update-lights-for-priority
  let priority-vehicle one-of cars with [priority?] ; assuming red cars are priority vehicles

 if priority-vehicle != nobody [
    let vehicle-heading [heading] of priority-vehicle  ;; Get the heading of the priority vehicle
    let vehicle-pxcor [pxcor] of priority-vehicle     ;; Get the pxcor of the priority vehicle
    let vehicle-pycor [pycor] of priority-vehicle     ;; Get the pycor of the priority vehicle

    ;print (word "Priority vehicle detected with heading: " vehicle-heading)

    ; Update lights based on the heading
    if vehicle-heading = 180 [  ;; Vehicle is heading north
      ask lights with [pxcor > vehicle-pxcor] [set color green]  ;; Turn lights green on the right
      ask lights with [pxcor < vehicle-pxcor] [set color red]    ;; Turn lights red on the left
    ]
    ; Add other directional handling if necessary
  ]
end

to-report get-intersections-info [ intersection-patch ]
  let info []
  let x-cord [pxcor] of intersection-patch
  let y-cord [pycor] of intersection-patch

  ; Get the left and up intersections
  let left-intersections []
  ask intersections [
    if ([pxcor] of self < x-cord )and ([pycor] of self = y-cord )[
      set left-intersections lput (self) left-intersections
    ]
  ]

  let up-intersections []
  ask intersections [
    if ([pxcor] of self = x-cord )and ([pycor] of self > y-cord )[
      set up-intersections lput (self) up-intersections
    ]
  ]

  ; print size of left-intersections
  ;print(word "X: " x-cord " Y: " y-cord)
  ;print (word "Size of left-intersections: "  length left-intersections)
  ;print (word "Size of up-intersections: " length up-intersections)
  ;print("\n")

  ;; Get the possible number of neighbors to ask for info
  let possible-left 0

  ifelse (length left-intersections > neighbors-asked) [
    set possible-left neighbors-asked
  ]
   [
    set possible-left length left-intersections
  ]

  let possible-up 0
  ifelse (length up-intersections > neighbors-asked) [
    set possible-up neighbors-asked
  ]
    [
    set possible-up length up-intersections
  ]


  ;; Get the info for the left and up intersections
  let left-global-score 0
  let up-global-score 0
  let i 0
  while [i < possible-left] [
    let current-neighbor item i left-intersections
    let x [pxcor] of current-neighbor

    let score priority-score current-neighbor
    let left-score item 0 score
    let dist abs (x-cord - x)

    set left-global-score left-global-score + (left-score * (1 / dist)) ;; distance to intersection

    set i i + 1
  ]
  let j 0
  while [j < possible-up] [
    let current-neighbor item j up-intersections
    let y [pycor] of current-neighbor

    let score priority-score current-neighbor
    let up-score item 1 score
    let dist abs (y - y-cord)

    set up-global-score up-global-score + (up-score * (1 / dist))       ;; distance to intersection

    set j j + 1
  ]

  let score priority-score intersection-patch
  let left-score item 0 score
  let up-score item 1 score

  ; add the global scores to the list
  set left-global-score left-global-score + left-score
  set up-global-score up-global-score + up-score

  ;print (word "Patch x: " x-cord " y: " y-cord)
  ;print (word "Left global score: " left-global-score)
  ;print (word "Up global score: " up-global-score)
  set info (list left-global-score up-global-score)

  report info
end


to-report has-priority-vehicles
  let priority-vehicle-detected false

  ask lights [
    ; Check all cars to see if they are affected by this light
    ask cars [
      let affecting-light traffic-light-affecting
      if affecting-light = myself and priority? [ ;; only for priority vehicles
        set priority-vehicle-detected true
      ]
    ]
  ]

  report priority-vehicle-detected  ;; return true or false
end

to check-for-collisions
  ask accidents [
    set clear-in clear-in - 1
    if clear-in = 0 [ die ]
  ]
  ask patches with [ count cars-here > 1 ] [
    sprout-accidents 1 [
      set size 1.5
      set color yellow
      set clear-in 5
    ]
    set total-accidents total-accidents + 1
    ask cars-here [ die ]
  ]
end

to change-current
  ; change the nearest green light within a radius of 1 block to yellow
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let nearest-light one-of nearby-lights with [color = green] ; find any green light in the radius
    if nearest-light != nobody [ ; ensure there's a green light in the radius
      ask nearest-light [ set color yellow ]
      set ticks-at-last-change ticks
    ]
  ]
end

to change-to-yellow
  ask lights with [ color = green ] [
    set color yellow
    set ticks-at-last-change ticks
  ]
end

to change-to-red
  ask lights with [ color = yellow ] [
    ; change the light neighbors with red color to green
    ask neighbors [
      ask lights-here with [ color = red ] [
        set color green
        set waiting-time 0
      ]
    ]
    set color red
    ; ask other lights [ set color green ]
    set ticks-at-last-change ticks
  ]
end

; reports `true` if `time-length` ticks
; has elapsed since the last light change
to-report elapsed? [ time-length ]
  report (ticks - ticks-at-last-change) > time-length
end

to choose-current
  if mouse-down?
  [
    let x-mouse mouse-xcor
    let y-mouse mouse-ycor
    if [intersection?] of patch x-mouse y-mouse
    [
      unlabel-current
      make-current patch x-mouse y-mouse
      label-current
      stop
    ]
  ]
end

to make-current [ new-intersection ]
  set current-intersection new-intersection
  ;print (word "New current intersection at x: " [my-col] of new-intersection " y: " [my-row] of new-intersection)
end

;; label the current light
to label-current
  ask current-intersection
  [
    ask patch-at -1 2
    [
      set plabel-color black
      set plabel "current"
    ]
  ]
end

to unlabel-current
  ask current-intersection
  [
    ask patch-at -1 2
    [
      set plabel ""
    ]
  ]
end

to-report current-intersection-traffic-input-south
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-input 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 1] ; find any green light in the radius
    set temp-input [traffic-input] of current-light
  ]
  report temp-input
end

to-report current-intersection-traffic-input-east
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-input 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 0] ; find any green light in the radius
    set temp-input [traffic-input] of current-light
  ]
  report temp-input
end

to-report intersection-traffic-density-south [intersection-patch]
  if intersection-patch = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-density 0
  ask intersection-patch [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 1] ; find any green light in the radius
    set temp-density ( [traffic-input] of current-light - [traffic-output] of current-light )
  ]
  report temp-density
end

to-report intersection-traffic-density-east [intersection-patch]
  if intersection-patch = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-density 0
  ask intersection-patch [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 0] ; find any green light in the radius
    set temp-density ( [traffic-input] of current-light - [traffic-output] of current-light )
  ]
  report temp-density
end

to-report current-intersection-traffic-density-south
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-density 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 1] ; find any green light in the radius
    set temp-density ( [traffic-input] of current-light - [traffic-output] of current-light )
  ]
  report temp-density
end

to-report current-intersection-traffic-density-east
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-density 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 0] ; find any green light in the radius
    set temp-density ( [traffic-input] of current-light - [traffic-output] of current-light )
  ]
  report temp-density
end

;; Talvez mudar para a variavel que guarda o total de veiculos na intersecao
to-report current-intersection-traffic-density-overall
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-density 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    ask nearby-lights [
      set temp-density (temp-density + [traffic-input] of self - [traffic-output] of self)
    ]
  ]
  report temp-density
end

to-report total-traffic-input
  let temp-input 0
  ask lights [
    let input-patch-xcord [pxcor] of input-patch
    let input-patch-ycord [pycor] of input-patch
    if (input-patch-xcord = (max-pxcor * (-1))) or (input-patch-ycord = max-pycor) [
      set temp-input (temp-input + traffic-input)
    ]
  ]
  report temp-input
end

to-report total-traffic-output
  let temp-output 0
  ask lights [
    if (pxcor = (max-pxcor - 1)) or (pycor = ((max-pycor - 1)*(-1))) [
      set temp-output (temp-output + traffic-output)
    ]
  ]
  report temp-output
end

to-report car-total-waiting-time
  let temp-waiting 0
  ask cars [
    set temp-waiting (temp-waiting + waiting-time)
  ]
  report temp-waiting
end

to-report report-total-waiting-time
  report total-waiting-time
end

to-report average-total-waiting-time
  report total-waiting-time / total-traffic-input
end

;; Basicamente Igual à current-intersection-traffic-density-overall
to-report current-intersection-vehicles
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-vehicles 0
  ask current-intersection [
    set temp-vehicles vehicles-here
  ]
  report temp-vehicles
end

to-report current-intersection-avg-waiting-time-east
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-waiting 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 0] ; find any green light in the radius
    set temp-waiting ( [avg-waiting-time] of current-light )
  ]
  report temp-waiting
end

to-report current-intersection-avg-waiting-time-south
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-waiting 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 1] ; find any green light in the radius
    set temp-waiting ( [avg-waiting-time] of current-light )
  ]
  report temp-waiting
end

to-report current-intersection-cars-waiting-time-east
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-waiting 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 0] ; find any green light in the radius
    set temp-waiting ( [cars-waiting-time] of current-light )
  ]
  report temp-waiting
end

to-report current-intersection-cars-waiting-time-south
  if current-intersection = nobody [ report 0 ]  ;; Handle the case where no intersection is selected

  let temp-waiting 0
  ask current-intersection [
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    let current-light one-of nearby-lights with [who mod 2 = 1] ; find any green light in the radius
    set temp-waiting ( [cars-waiting-time] of current-light )
  ]
  report temp-waiting
end

to-report get-lights

  let who-list []
  let traffic-input-list []
  let traffic-output-list []
  let cars-waiting-time-list []
  let avg-waiting-time-list []
  let patch-xcord-list []
  let patch-ycord-list []
  ask lights[
    set who-list lput ([who] of self) who-list
    set traffic-input-list lput ([traffic-input] of self) traffic-input-list
    set traffic-output-list lput ([traffic-output] of self) traffic-output-list
    set cars-waiting-time-list lput ([cars-waiting-time]) of self cars-waiting-time-list
    set avg-waiting-time-list lput ([avg-waiting-time]) of self avg-waiting-time-list
    set patch-xcord-list lput ([xcor] of self) patch-xcord-list
    set patch-ycord-list lput ([ycor] of self) patch-ycord-list
  ]
  report (list who-list patch-xcord-list patch-ycord-list traffic-input-list traffic-output-list cars-waiting-time-list avg-waiting-time-list)
end

to-report lights-avg-wait-time-list
  let temp []  ;; Initialize an empty list to store combined results
  ask lights [
    let who-light [who] of self
    let tem-avg [avg-wait-time-list] of self
    ;; Combine `who-light` and `tem-avg` into a sublist and append to `temp`
    set temp lput (list who-light tem-avg) temp
  ]

  let a (word temp)
  report temp  ;; Report the combined list
end

to write-lights-avg-list-to-csv

  let data-list lights-avg-wait-time-list  ;; Get the data list
  let file-name "output.csv"

  ; Open the file for writing
  file-open file-name

  ; Write the header if necessary
  file-type "who,avg-wait-list"
  file-print "" ; New line after the header

  ; Loop through the data and write it into the file
  let i 0
  while [i < length data-list] [
    let item-list item i data-list  ;; Get the sublist at index `i`
    print (word "Item list: " item-list)
    let index item 0 item-list  ;; Get the index from the sublist
    let value item 1 item-list  ;; Get the value from the sublist
    file-type (word index "," value) ; Write the index and value
    file-print "" ; New line after each entry
    set i i + 1
  ]

  ; Close the file
  file-close


end

to-report get-intersections-density

  let vehicles-here-list []
  let x-cord-list []
  let y-cord-list []
  ask intersections[

    set vehicles-here-list lput ([vehicles-here] of self) vehicles-here-list
    set x-cord-list lput ([pxcor] of self) x-cord-list
    set y-cord-list lput ([pycor] of self) y-cord-list
  ]
  report (list x-cord-list y-cord-list vehicles-here-list)
end


to update-priority-waiting-time
  ;; Calculate the average waiting time for priority vehicles
  ifelse total-priority-vehicles > 0 [
    set average-priority-waiting-time total-priority-waiting-time / total-priority-vehicles
  ]
  [
    set average-priority-waiting-time 0  ;; No priority vehicles, so average is 0
  ]
end

to-report report-average-priority-vehicles
  report total-priority-waiting-time / total-priority-vehicles
end

to-report report-total-accidents
  report total-accidents
end
;; VALUES FROM INTERSECTIONS

to-report color-to-name [name_color]
  if name_color = black [report "black"]
  if name_color = white [report "white"]
  if name_color = red [report "red"]
  if name_color = green [report "green"]
  if name_color = blue [report "blue"]
  if name_color = yellow [report "yellow"]
  if name_color = cyan [report "cyan"]
  if name_color = magenta [report "magenta"]
  if name_color = gray [report "gray"]
  if name_color = orange [report "orange"]
  if name_color = brown [report "brown"]
  if name_color = pink [report "pink"]
  if name_color = violet [report "violet"]
  if name_color = turquoise [report "turquoise"]
  report "unknown"
end

to-report report-left-and-up-streets-with-traffic-lights [intersection-patch]
  ; Traffic light to the left and above

  let left-traffic-light nobody
  let up-traffic-light nobody
  ask intersection-patch[
    let nearby-lights lights in-radius 1 ; select lights within 1 block
    set left-traffic-light one-of nearby-lights with [who mod 2 = 0] ; find any green light in the radius
    set up-traffic-light one-of nearby-lights with [who mod 2 = 1] ; find any green light in the radius
  ]

  if ([breed = lights] of left-traffic-light and [breed = lights] of up-traffic-light)[
    ; Initialize variables for roads
    let left-road nobody;
    let up-road nobody

    ; Traffic Light Color
    let left-light-color "none";
    let up-light-color "none";

    let left-light-avg-waiting-time [avg-waiting-time] of left-traffic-light;
    let up-light-avg-waiting-time [avg-waiting-time] of up-traffic-light;

    let left-light-waiting-time [waiting-time] of left-traffic-light;
    let up-light-waiting-time [waiting-time] of up-traffic-light;
    ; Check for traffic light and find road beyond it
    if left-traffic-light != nobody [
      set left-road [input-patch] of left-traffic-light
      set left-light-color [color-to-name color] of left-traffic-light

    ]

    if up-traffic-light != nobody [
      set up-road [input-patch] of up-traffic-light
      set up-light-color [color-to-name color] of up-traffic-light

    ]

    ; To save results
    let result []

    let cars-left ([traffic-input] of left-traffic-light - [traffic-output] of  left-traffic-light)
    let cars-up ([traffic-input] of up-traffic-light - [traffic-output] of  up-traffic-light)

    let priority-cars-left ([traffic-input-prioritary] of left-traffic-light - [traffic-output-prioritary] of  left-traffic-light)
    let priority-cars-up ([traffic-input-prioritary] of up-traffic-light - [traffic-output-prioritary] of  up-traffic-light)

    ; Report roads or absence of roads
    ifelse left-road != nobody [
        set result lput left-traffic-light result
        set result lput cars-left result
        set result lput priority-cars-left result
        set result lput left-light-color result
        set result lput left-light-avg-waiting-time result
        set result lput left-light-waiting-time result
    ] [
      ;show "No street to the left beyond the traffic light."
    ]

    ifelse up-road != nobody  [
        set result lput up-traffic-light result
        set result lput cars-up result
        set result lput priority-cars-up result
        set result lput up-light-color result
        set result lput up-light-avg-waiting-time result
        set result lput up-light-waiting-time result
    ] [
      ;show "No street above beyond the traffic light."
    ]

    ; show result
    report result ; (0- left road, 1- total cars on left, 2- priority cars on left, 3- traffic light color left, 4- avg waiting time left, 5 - last waiting time left , 5 - up road, 6- total cars on up, 7- priority cars on up, 8- traffic light color up, 9- avg waiting time up, 10 - last waiting time up  )
  ]
  report [];
end

to-report priority-score [intersection-patch]
  let info report-left-and-up-streets-with-traffic-lights intersection-patch

  let left-score 0
  let up-score 0

  let left-cars (item 1 info)
  let left-priority-cars (item 2 info)
  let left-light-color (item 3 info)
  let left-light-avg-waiting-time (item 4 info)
  let left-light-waiting-time (item 5 info)

  set left-score density-weight * (left-cars) + waiting-time-weight * (left-light-waiting-time) + priority-vehicle-weight * (left-priority-cars)
  set left-score left-score / 100
  ;print (word "Left score: " left-score)

  let up-cars (item 7 info)
  let up-priority-cars (item 8 info)
  let up-light-color (item 9 info)
  let up-light-avg-waiting-time (item 10 info)
  let up-light-waiting-time (item 11 info)

  set up-score density-weight * (up-cars) + waiting-time-weight * (up-light-waiting-time) + priority-vehicle-weight * (up-priority-cars)
  set up-score up-score / 100
  ;print (word "Up score: " up-score)

  let result []
  set result lput left-score result
  set result lput up-score result

  report result
end


; Copyright 1998 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
405
10
958
564
-1
-1
15.57143
1
10
1
1
1
0
0
0
1
-17
17
-17
17
1
1
1
ticks
30.0

SLIDER
105
15
202
48
grid-size-y
grid-size-y
1
9
3.0
1
1
NIL
HORIZONTAL

SLIDER
10
15
105
48
grid-size-x
grid-size-x
1
9
3.0
1
1
NIL
HORIZONTAL

BUTTON
210
15
300
48
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
330
15
395
48
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
235
130
382
163
switch all lights
change-to-yellow
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
420
176
453
green-length
green-length
1
50
10.0
1
1
NIL
HORIZONTAL

SLIDER
15
226
176
259
speed-limit
speed-limit
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
15
269
176
302
max-accel
max-accel
1
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
15
302
176
335
max-brake
max-brake
1
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
15
344
176
377
freq-north
freq-north
0
100
50.0
5
1
%
HORIZONTAL

SLIDER
15
377
176
410
freq-west
freq-west
0
100
50.0
5
1
%
HORIZONTAL

SWITCH
15
65
105
98
auto?
auto?
1
1
-1000

SLIDER
15
453
176
486
yellow-length
yellow-length
0
10
3.0
1
1
NIL
HORIZONTAL

MONITOR
980
220
1085
265
waiting overall
count cars with [ speed = 0 ]
0
1
11

MONITOR
1090
220
1195
265
waiting-westbound
count cars with [ heading = 90 and speed = 0 ]
0
1
11

MONITOR
1200
220
1305
265
waiting-northbound
count cars with [ heading = 180 and speed = 0 ]
0
1
11

PLOT
980
10
1305
215
Waiting
time
waiting cars
0.0
100.0
0.0
10.0
true
true
"" ""
PENS
"overall" 1.0 0 -16777216 true "" "plot count cars with [ speed = 0 ]"
"westbound" 1.0 0 -13345367 true "" "plot count cars with [ heading = 90 and speed = 0 ]"
"northbound" 1.0 0 -2674135 true "" "plot count cars with [ heading = 180 and speed = 0 ]"

BUTTON
330
55
395
88
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
235
210
390
243
Select intersection
choose-current
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
235
170
402
203
switch current light
change-current
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
980
275
1645
480
Current Intersection Traffic Density
Time
Density
0.0
10.0
0.0
5.0
true
true
"" ""
PENS
"Overall" 1.0 0 -16777216 true "" "plot current-intersection-traffic-density-overall"
"Southbound" 1.0 0 -10649926 true "" "plot current-intersection-traffic-density-south"
"Eastbound" 1.0 0 -2674135 true "" "plot current-intersection-traffic-density-east"

MONITOR
405
580
565
625
Total Traffic Input
total-traffic-input
17
1
11

MONITOR
405
635
565
680
Total Traffic Output
total-traffic-output
17
1
11

MONITOR
590
635
750
680
Cars Total Waiting Time
car-total-waiting-time
17
1
11

MONITOR
590
580
750
625
Total Waiting Time
report-total-waiting-time
17
1
11

MONITOR
1320
220
1645
265
Current Average Total Waiting Time
average-total-waiting-time
4
1
11

SWITCH
15
95
177
128
allow-priority?
allow-priority?
1
1
-1000

MONITOR
780
695
995
740
Avg Waiting Time Priority Vehicles
report-average-priority-vehicles
17
1
11

MONITOR
590
695
750
740
Total Priority Vehicles
total-priority-vehicles
17
1
11

MONITOR
405
695
565
740
NIL
total-priority-waiting-time
17
1
11

SWITCH
15
125
187
158
adaptive-density?
adaptive-density?
1
1
-1000

SWITCH
15
155
222
188
adaptive-waiting-time?
adaptive-waiting-time?
1
1
-1000

MONITOR
780
580
940
625
Number of accidents
report-total-accidents
17
1
11

SLIDER
10
495
182
528
neighbors-asked
neighbors-asked
1
8
2.0
1
1
NIL
HORIZONTAL

SWITCH
120
60
237
93
multi-agent?
multi-agent?
0
1
-1000

SLIDER
210
265
380
298
density-weight
density-weight
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
210
295
380
328
waiting-time-weight
waiting-time-weight
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
210
325
380
358
priority-vehicle-weight
priority-vehicle-weight
0
100
70.0
1
1
NIL
HORIZONTAL

SWITCH
15
185
177
218
priority-score?
priority-score?
1
1
-1000

SLIDER
210
415
382
448
lights-time-ticks
lights-time-ticks
50
500
50.0
10
1
NIL
HORIZONTAL

PLOT
980
490
1645
695
Current Intersection's Priority Score Variation
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"West priority score" 1.0 0 -13345367 true "" "plot item 0 priority-score current-intersection"
"North priority score" 1.0 0 -2674135 true "" "plot item 1 priority-score current-intersection"

PLOT
1320
10
1645
215
Average Waiting Time Variation
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot average-total-waiting-time"

@#$#@#$#@
## WHAT IS IT?

In this model the turtles are cars traveling through an intersection.  The user has the ability to control the frequency of cars coming from each direction, the speed of the cars, and the timing of the light at the traffic intersection.  Once the frequency and speed of cars is selected, the user should run the simulation and adjust the timing of the traffic light so as to minimize the amount of waiting time of cars traveling through the intersection.

## HOW IT WORKS

The rules for each car are:

- I can only go in the direction I started in, or stop.

- I stop for cars in front of me and red lights, and I stop for a yellow light if I'm not already on it.

- If I am moving quickly and I see that I will have to stop soon, I try to slow down enough to make sure I can stop in time, up to MAX-BRAKE.

- If I see that I have free space in front of me, I speed up towards the SPEED-LIMIT, up to MAX-ACCEL.

- If I am on the same space as another car, we crash and die.

## HOW TO USE IT

WAIT-TIME-OVERALL shows how many cars are waiting during the given clock tick.

WAIT-TIME-westBOUND shows how many westbound cars are waiting during the given clock tick.

WAIT-TIME-NORTHBOUND shows how many northbound cars are waiting during the given clock tick.

CLOCK shows how many ticks have elapsed.

Use the FREQ-west slider to select how often new westbound cars travel on the road.

Use the FREQ-NORTH slider to select how often new northbound cars travel on the road.

Use the SPEED-LIMIT slider to select how fast the cars will travel.

Use the MAX-ACCEL slider to determine how fast the cars can accelerate.

Use the MAX-BRAKE slider to determine how fast the cars can decelerate.

Use the GREEN-LENGTH slider to set how long the light will remain green.

Use the YELLOW-LENGTH slider to set how long the light will remain yellow.

Press GO ONCE to make the cars move once.

Press GO to make the cars move continuously.

To stop the cars, press the GO button again.

## THINGS TO NOTICE

Cars start out evenly spaced but over time, they form bunches. What kinds of patterns appear in the traffic flow?

Under what conditions do the cars appear to be moving backwards?

Gridlock happens when cars are unable to move because cars from the other direction are in their path.  What settings cause gridlock in this model?  What settings can be changed to end the gridlock?

## THINGS TO TRY

Try to answer the following questions before running the simulations.

Record your predictions.

Compare your predicted results with the actual results.

- What reasoning led you to correct predictions?

- What assumptions that you made need to be revised?

Try different numbers of westbound cars while keeping all other slider values the same.

Try different numbers of northbound cars while keeping all other slider values the same.

Try different values of SPEED-LIMIT while keeping all other slider values the same.

Try different values of MAX-ACCEL while keeping all other slider values the same.

Try different values of GREEN-LENGTH and YELLOW-LENGTH while keeping all other slider values the same.

For all of the above cases, consider the following:

- What happens to the waiting time of westbound cars?

- What happens to the waiting time of northbound cars?

- What happens to the overall waiting time?

- What generalizations can you make about the impact of each variable on the waiting time of cars?

- What kind of relationship exists between the number of cars and the waiting time they experience?

- What kind of relationship exists between the speed of cars and the waiting time they experience?

- What kind of relationship exists between the number of ticks of green light and the waiting time cars experience?

Use your answers to the above questions to come up with a strategy for minimizing the waiting time of cars.

What factor (or combination of factors) has the most influence over the waiting time experienced by the cars?

## EXTENDING THE MODEL

Find a realistic way to eliminate all crashes by only changing car behavior.

Allow different light lengths for each direction in order to control wait time better.

Is there a better way to measure the efficiency of an intersection than the current number of stopped cars?

## RELATED MODELS

- "Traffic Basic": a simple model of the movement of cars on a highway.

- "Traffic Basic Utility": a version of "Traffic Basic" including a utility function for the cars.

- "Traffic Basic Adaptive": a version of "Traffic Basic" where cars adapt their acceleration to try and maintain a smooth flow of traffic.

- "Traffic Basic Adaptive Individuals": a version of "Traffic Basic Adaptive" where each car adapts individually, instead of all cars adapting in unison.

- "Traffic 2 Lanes": a more sophisticated two-lane version of the "Traffic Basic" model.

- "Traffic Grid": a model of traffic moving in a city grid, with stoplights at the intersections.

- "Traffic Grid Goal": a version of "Traffic Grid" where the cars have goals, namely to drive to and from work.

- "Gridlock HubNet": a version of "Traffic Grid" where students control traffic lights in real-time.

- "Gridlock Alternate HubNet": a version of "Gridlock HubNet" where students can enter NetLogo code to plot custom metrics.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1998).  NetLogo Traffic Intersection model.  http://ccl.northwestern.edu/netlogo/models/TrafficIntersection.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1998 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2002.

<!-- 1998 2002 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
true
0
Polygon -7500403 true true 180 15 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 285 165 285 225 285 225 15 180 15
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fire
false
0
Polygon -7500403 true true 151 286 134 282 103 282 59 248 40 210 32 157 37 108 68 146 71 109 83 72 111 27 127 55 148 11 167 41 180 112 195 57 217 91 226 126 227 203 256 156 256 201 238 263 213 278 183 281
Polygon -955883 true false 126 284 91 251 85 212 91 168 103 132 118 153 125 181 135 141 151 96 185 161 195 203 193 253 164 286
Polygon -2674135 true false 155 284 172 268 172 243 162 224 148 201 130 233 131 260 135 282

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
