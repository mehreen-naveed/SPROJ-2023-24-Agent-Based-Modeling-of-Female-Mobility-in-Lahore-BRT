extensions [gis]

globals [women-stopped men-stopped passenger-bus0 total-travel-women total-travel-men total-travel bus-stop no-days women-intention women-stopped-brt women-intention-brt women-use-brt percent-women-brt prob-list]

breed [stations station ]
stations-own [ name ]

breed [buses bus]
buses-own [location reverse? label-of-bus]

;;look into people-own
breed [ people person ]
people-own [harasser? gender age income employment-status urgency feeling-of-safety confidence comfort awareness car-ownership? at-work? home-loc work-loc home-tehsil has-arrived? destination final-station BRT-use-score nearest-station]

patches-own [tehsil kind]


to setup
  ca
  import-gis-data ;;layout of map and metroline
  create-brt ;;creating the bus station links
  add-POIs ;;adding points of interest
  create-buses 1 [setxy 34 100 set shape "bus" set size 2 set color red set location station 0 set reverse? false set label-of-bus "bus0"]
  ;;num-people defined by user
  let lahore-city-ppl round ( 0.3286 * num-people );;32.86 % of total population
  let lahore-city-female round (0.4781 * lahore-city-ppl) ;;47.81% women
  let model-town-ppl round ( 0.2431 * num-people );;24.31 % of total population
  let model-town-female round (0.4741 * model-town-ppl) ;;47.41% women
  let shalimar-ppl round ( 0.2052 * num-people );;20.52 % of total population
  let shalimar-female round (0.4821 * shalimar-ppl) ;;48.21% women
  let raiwind-ppl round (0.0763 * num-people );;7.63 % of total population
  let raiwind-female round (0.4714 * raiwind-ppl) ;;47.14% women
  let lahore-cantt-ppl  num-people - ( lahore-city-ppl + model-town-ppl + shalimar-ppl + raiwind-ppl );;14.68% of total population
  let lahore-cantt-female round (0.4749 * lahore-cantt-ppl) ;;47.49% women
  ;;defining tehsils using patches. coordinates to be updated later!
  ask patches [
    if pxcor >= 0 and pxcor <= 50 and pycor >= 0 and pycor < 50 [set tehsil "Model Town"]
    if pxcor >= 0 and pxcor <= 50 and pycor >= 50 and pycor <= 75 [set tehsil "Shalimar"]
    if pxcor >= 0 and pxcor <= 50 and pycor >= 75 and pycor <= 100 [set tehsil "Raiwind"]
    if pxcor > 50 and pxcor <= 100 and pycor >= 0 and pycor < 50 [set tehsil "Lahore Cantonment"]
    if pxcor > 50 and pxcor <= 100 and pycor >= 50 and pycor <= 100 [set tehsil "Lahore City"]
  ]
  ;;setting up population
  ;;set-people-location [num-ppl-tehsil name-of-tehsil num-women-tehsil]
  set-people-location lahore-city-ppl "Lahore City" lahore-city-female
  set-people-location model-town-ppl "Model Town" model-town-female
  set-people-location shalimar-ppl "Shalimar" shalimar-female
  set-people-location raiwind-ppl "Raiwind" raiwind-female
  set-people-location lahore-cantt-ppl "Lahore Cantonment" lahore-cantt-female
  set-internal-vars
  setup-final-station ;;because it needs entire set of people
  calculate-prob-brt
  set prob-list []
  ask people [
    set prob-list lput BRT-use-score prob-list
  ]
  show prob-list
  show word "Minimum BRT-use score is: " min prob-list
  show word "Maximum BRT-use score is: " max prob-list
  show word (precision(((count people with [gender = "female" and BRT-use-score < mean prob-list])/ count people with [gender = "female"]) * 100)1 ) "% of women are below mean BRT-score"
  set women-stopped 0
  set passenger-bus0 0
  set total-travel-men 0
  set total-travel-women 0
  set total-travel 0
  set women-intention 0
  set bus-stop 1
  set no-days 0
  reset-ticks
end

to go
  ask people [move-to-nearest-station]
  move-bus;
  check-bus-capacity;
  calculate-prob-brt;; this recalculates the BRT-use-score at every iteration! not just setup
  if bus-stop = 53 [tick] ;;works
  if (ticks mod 8 = 0 and bus-stop mod 53 = 0) [
    set no-days no-days + 1
    if awareness-campaigns? = true [
      ask n-of (0.1 * num-people) people [ ;;every day, 10% of people are asked to increase awareness by 1
        set awareness awareness + 1;
        if awareness > 2 [
          set awareness 2;; max val
        ]
      ]
    ]
  ]
  if no-days = 10 [stop] ;;run the simulation for ten days
end

;;this function decreases comfort if overcrowding happens on the bus!
to check-bus-capacity
  let my-bus one-of buses;; to select the bus
  let passengers [out-link-neighbors] of my-bus ;; all the people on the bus (agents not count)
  if passenger-bus0 > bus-capacity [
    ask passengers with [gender = "female"][
      set comfort comfort - over-crowding-impact;
      if comfort < -2 [
        set comfort -2;
      ]
    ]
  ]
end

to move-to-nearest-station
  set prob-list [] ;;empties it at every run
  ask people [
    set prob-list lput BRT-use-score prob-list
  ]
  if has-arrived? = false [
    (ifelse pink-bus? = true [ ;;only women allowed to board the bus
      let women-prob-list [] ;;defining the BRT-use-score of women only
      ask people with [gender = "female"][
        set women-prob-list lput BRT-use-score women-prob-list
      ]
      (ifelse capacity-check? = true [ ;;implementing overcrowding check with pink-bus!
        ask people with [gender = "female"] [
          ifelse (BRT-use-score > mean (women-prob-list)) and (passenger-bus0 < bus-capacity) [
            set nearest-station nearest-station-to patch-here
            face nearest-station
            move-to nearest-station
            if gender = "female" [set women-intention women-intention + 1] ;;women who intended to travel and did travel
          ][
            ;;counting how many people were stopped from using the brt!
            if gender = "female" [set women-stopped women-stopped + 1 set women-intention women-intention + 1] ;;who who intended to travel and move to station
          ]
        ]
      ] capacity-check? = false [ ;;not implementing over-crowding check with pink-bus
        ask people with [gender = "female"] [
          ifelse BRT-use-score > mean (women-prob-list) [
            set nearest-station nearest-station-to patch-here
            face nearest-station
            move-to nearest-station
            if gender = "female" [set women-intention women-intention + 1] ;;women who intended to travel and move to station
          ][
            ;;counting how many people were stopped from using the brt!
            if gender = "female" [set women-stopped women-stopped + 1 set women-intention women-intention + 1] ;;who who intended to travel but couldn't
          ]
        ]
    ])
    ] pink-bus? = false [
      (ifelse capacity-check? = true [ ;;implementing overcrowding check!
        ask people [
          ifelse (BRT-use-score > mean (prob-list)) and (passenger-bus0 < bus-capacity) [
            set nearest-station nearest-station-to patch-here
            face nearest-station
            move-to nearest-station
            if gender = "female" [set women-intention women-intention + 1] ;;women who intended to travel and did travel
          ][
            ;;counting how many people were stopped from using the brt!
            if gender = "female" [set women-stopped women-stopped + 1 set women-intention women-intention + 1] ;;who who intended to travel and move to station
          ]
        ]
      ] capacity-check? = false [ ;;not implementing over-crowding check
        ask people [
          ifelse BRT-use-score > mean (prob-list) [
            set nearest-station nearest-station-to patch-here
            face nearest-station
            move-to nearest-station
            if gender = "female" [set women-intention women-intention + 1] ;;women who intended to travel and move to station
          ][
            ;;counting how many people were stopped from using the brt!
            if gender = "female" [set women-stopped women-stopped + 1 set women-intention women-intention + 1] ;;who who intended to travel but couldn't
          ]
        ]
      ])
    ])
    ask buses [
      let nearby-people people in-radius 1 with [not any? links with [breed = buses]]
      let harassers nearby-people with [harasser? = true] ;;no. of people with harasser attribute
      create-links-to nearby-people in-radius 1 [tie set color blue]

      ;;IMPACT OF HARASSMENT ON BUSES!
      if any? nearby-people with [gender = "female"][
        if count(harassers) > 0 [ ;;if a harraser is present in nearby-people
          ifelse pink-bus? = true [
            let new-harasser-impact harasser-impact
            let choice random 2;; this is to basically half the impact of harassment at stations (choice = 0 or 1)
            if choice = 0 [set new-harasser-impact 0] ;;else it stays the same
            ask one-of nearby-people with [gender = "female"] [
              set feeling-of-safety (feeling-of-safety - new-harasser-impact) ;;reduces feeling of safety by 1 unit (2 ->1, 0 -> -1)
              if feeling-of-safety < -2 [set feeling-of-safety -2]
              set comfort (comfort - new-harasser-impact) ;;reduces feeling of safety by 1 unit (2 ->1, 0 -> -1)
              if comfort < -2 [set comfort -2]
              set confidence (confidence - new-harasser-impact) ;;reduces feeling of safety by 1 unit (2 ->1, 0 -> -1)
              if confidence < -2 [set confidence -2]
            ]
          ]
          [ ;;if pink-bus? = false
            ask one-of nearby-people with [gender = "female"] [
              set feeling-of-safety (feeling-of-safety - harasser-impact) ;;reduces feeling of safety by 1 unit (2 ->1, 0 -> -1)
              if feeling-of-safety < -2 [set feeling-of-safety -2]
              set comfort (comfort - harasser-impact) ;;reduces feeling of safety by 1 unit (2 ->1, 0 -> -1)
              if comfort < -2 [set comfort -2]
              set confidence (confidence - harasser-impact) ;;reduces feeling of safety by 1 unit (2 ->1, 0 -> -1)
              if confidence < -2 [set confidence -2]
            ]
          ]
        ]
      ]
    ]
  ]

end

to move-bus
  ask buses [
    ifelse reverse? = false [
    ;;bus moving in forward direction
      let new-location one-of [out-link-neighbors] of location
      ifelse new-location != nobody [
        face new-location
        move-to new-location
        set bus-stop bus-stop + 1
        set location new-location
        untie-people
        set passenger-bus0 count my-out-links
      ][
        set reverse? true
      ]
    ][
    ;; bus moving in reverse direction
      let new-location one-of [in-link-neighbors] of location
      ifelse new-location != nobody [
        face new-location
        move-to new-location
        set bus-stop bus-stop + 1
        set location new-location
        untie-people
        set passenger-bus0 count my-out-links
      ][
        set reverse? false
        set bus-stop 1
      ]
    ]
  ]
end

to untie-people
  ask people [
    let my-bus one-of link-neighbors with [ any? my-links with [ end1 = myself or end2 = myself] and breed = buses ] ;;this is the bus they are linked to
    if my-bus != nobody and final-station = [location] of my-bus [ ;;if bus reaches the final station of the person
      ask my-bus [ask links with [end1 = myself or end2 = myself] [die]] ;;ask bus to remove the link with person who has reached station
      set has-arrived? true ;;person has arrived to final station!
      if gender = "female" [set total-travel-women total-travel-women + 1] ;;trips completed by women
      if gender = "male" [set total-travel-men total-travel-men + 1];; trips completed by men
      set total-travel total-travel + 1; ;;total trips being counted regardless of gender!
      move-to-final-destination
      ]
    ]
end

to move-to-final-destination
  face destination
  move-to destination ;;if destination is work, moves to work. if destination is home, moves to home.
    ;;do either or, not both!
  ifelse at-work? = false [
    set at-work? true ;;this means they are at work or at school!
    set destination home-loc
    wait 1.5 ;;to show them spend time at home
    set has-arrived? false ;;goes back into move-to-nearest station loop
  ][ ;;else
    set at-work? false ;; this means they are at home
    set destination work-loc
    wait 1.5;; to show them spend time at work
    set has-arrived? false ;;goes back into move-to-nearest station loop
  ]
end

to calculate-prob-brt
  let SN social-stigma;; social-stigma is a global var
  ask people[
    let APV 0;
    if car-ownership? = true [ ;;this is only applicable to those that have a car and prefer it to PT else no effect
      set APV 1;
    ]
    if gender = "male" [
      set SN (SN * gender-impact-disparity) ;;effect of SN is less on men as compared to women!
    ]
    if pink-bus? = true [
      set SN (SN * gender-impact-disparity) ;;effect of SN is same as for men in the case of pink-bus for women!
    ]
    let APT ((comfort * 0.153) + (income * weight_d))
    let PBC ((confidence * 1.00) + (feeling-of-safety * weight_a) + (awareness * weight_e))
    let intention ((APT * 0.28) + (APV * -0.49) + (PBC * 0.26) + (SN * -1 * (weight_c))) ;;intention is based on APT, APV, PBC, and SN
    set BRT-use-score precision ((intention * 0.63) + (urgency * weight_b)) 1;
 ]
end

to set-internal-vars
  let num-of-men count people with [gender = "male"] ;;number of men in the model
  let num-of-women count people with [gender = "female"] ;;number of women in the model
  ;;FOR HOUSEHOLD INCOME (BASED ON PHD THESIS DATA)
  let num-lower round (0.262 * num-people) ;;26.2% - 26
  let num-lowermid round (0.193 * num-people) ;;19.3% - 19
  let num-mid round (0.288 * num-people) ;;28.8% - 29
  let num-uppermid round (0.208 * num-people) ;;20.8% - 21
  let num-upper (num-people - num-lower - num-lowermid - num-mid - num-uppermid) ;;4.9% - 5
  ask n-of num-lower people with [income = nobody] [
    set income 0;
  ]
  ask n-of num-lowermid people with [income = nobody] [
    set income precision ((random-float 0.1) + 0.1) 1; 0.1,0.2
  ]
  ask n-of num-mid people with [income = nobody] [
    set income precision ((random-float 0.2) + 0.3) 1; 0.3,0.4,0.5
  ]
  ask n-of num-uppermid people with [income = nobody] [
    set income precision ((random-float 0.3) + 0.6) 1; 0.6,0.7,0.8,0.9
  ]
  ask people with [income = nobody] [
    set income 1.0;
  ]
  ;;FOR OCCUPATION MAN (PHD THESIS DATA)
  let num-students-men round (0.22 * num-of-men) ;;number of men who are students
  let num-employed-men round (0.73 * num-of-men) ;;number of men who are employed
  let num-unemployed-men num-of-men - (num-students-men + num-employed-men) ;;number of men who are employed
  ;;we want to ensure that all children are given status of students first, remaining children to be given unemployed. Then all remaining are employed
  ask n-of num-students-men people with [gender = "male" and age = "child" and employment-status = nobody] [
    set employment-status "student"
  ]
  ask n-of num-unemployed-men people with [gender = "male" and age = "child" and employment-status = nobody] [
    set employment-status "unemployed"
  ]
  ask people with [gender = "male" and employment-status = nobody][
    set employment-status "employed"
  ]
  ;;FOR OCCUPATION WOMAN (URRAN DATA)
  let num-students-women round (0.76 * num-of-women) ;;number of men who are students
  let num-employed-women round (0.15 * num-of-women) ;;number of men who are employed
  let num-unemployed-women num-of-women - (num-students-women + num-employed-women) ;;number of men who are employed
  ;;we want to ensure that all children are given status of students first, remaining children to be given unemployed. Then all remaining are employed
  ask n-of num-employed-women people with [gender = "female" and (age = "adult" or age = "senior") and employment-status = nobody][
    set employment-status "employed"
  ]
  ask n-of num-students-women people with [gender = "female" and (age = "child" or age = "adult") and employment-status = nobody] [
    set employment-status "student"
  ]
  ask people with [gender = "female" and employment-status = nobody] [
    set employment-status "unemployed"
  ]
  ;;FOR SAFETY (URRAN DATA) - How do we extrapolate this to men? For now we are using this data for entire population
  let num-very-unsafe round (0.04 * num-people) ;;number of people who feel very unsafe
  let num-unsafe round (0.11 * num-people) ;;number of people who feel unsafe
  let num-neutral round (0.23 * num-people) ;;number of people who feel neither safe nor unsafe
  let num-safe round (0.39 * num-people) ;;number of people who feel safe
  let num-very-safe num-people - (num-very-unsafe + num-unsafe + num-neutral + num-safe)
  ask n-of num-very-unsafe people with [feeling-of-safety = nobody][
    set feeling-of-safety -2;
  ]
  ask n-of num-unsafe people with [feeling-of-safety = nobody][
    set feeling-of-safety -1;
  ]
  ask n-of num-neutral people with [feeling-of-safety = nobody][
    set feeling-of-safety 0;
  ]
  ask n-of num-safe people with [feeling-of-safety = nobody][
    set feeling-of-safety 1;
  ]
  ask people with [feeling-of-safety = nobody][
    set feeling-of-safety 2;
  ]
  ;;FOR CAR OWNERSHIP MEN (PHD THESIS DATA)
  let men-own-car round (0.41 * num-of-men) ;;number of men who own cars
  ask n-of men-own-car people with [gender = "male"][
    set car-ownership? true
  ]
  ;;FOR CAR OWNERSHIP WOMEN (URRAN DATA)
  let women-own-car round (0.08 * num-of-women) ;;number of women who own cars
  ask n-of women-own-car people with [gender = "female"][
    set car-ownership? true
  ]
  ;;FOR COMFORT (Urran data + Gaussian randomized)
  let num-very-confident round (0.022 * num-people) ;; number of people who feel very comfortable in the BRT (7% total, 5% from Gaussian dist, 2% separately)
  ask n-of num-very-confident people with [comfort = nobody][
    set comfort 2;
  ]
  ask people with [comfort = nobody] [
    let comfort-val (random-normal 0 1) ;;generate random numbers from a Gaussian distribution with mean 0 and S.D. 1
    set comfort map-to-range comfort-val; ;;calling a function to map the distribution to -1, 0, 1, or 2
  ]
  ;;FOR CONFIDENCE (Gaussian randomized)
  ask people with [confidence = nobody] [
    let confidence-val (random-normal 0 1)
    set confidence map-to-range confidence-val; -2, -1, 0, 1, or 2
  ]
  ;;FOR AWARENESS (Urran data)
  let num-fully-aware round (0.2421 * num-people);;
  let num-slightly-aware round (0.5833 * num-people);;
  let num-not-aware (num-people - num-fully-aware - num-slightly-aware);;
  ask n-of num-fully-aware people with [awareness = nobody][
    set awareness 2;
  ]
  ask n-of num-slightly-aware people with [awareness = nobody][
    set awareness 0;
  ]
  ask people with [awareness = nobody][
    set awareness -2;
  ]
  ;;HOW MANY PEOPLE ARE HARASSERS
  let no-harassers round (harasser-percentage * num-people)
  ask n-of no-harassers people with [harasser? = false][
    set harasser? true
  ]
  gender-impact;; call function which changes gendered variable values for men
  if pink-bus? = true [ ;;incrementing feeling-of-safety and confidence of women at the start.
    ask people with [gender = "female"][
      set feeling-of-safety feeling-of-safety + 1;
      set confidence confidence + 1;
      if feeling-of-safety > 2 [
        set feeling-of-safety 2; max val
      ]
      if confidence > 2 [
        set confidence 2; max val
      ]
    ]
  ]
  if safety-check? = true [
    ask people with [gender = "female"][
      set feeling-of-safety (feeling-of-safety + ((random 2) + 1)) ;;can be increment of 1 or 2
      if feeling-of-safety > 2 [
        set feeling-of-safety 2;;
      ]
    ]
  ]
end

to gender-impact
  ;;gendered variables are social norm (done directly in calculate-prob-brt), comfort, feeling-of-safety, confidence
  ;;gender-impact-disaprity variable determines how male values are scalesd as compared to women. 0.575:1 (resources for women: resources for men)
  let scale-factor (1 + gender-impact-disparity) ;;we are increasing values for all men for comfort and feeling-of-safety
  ask people with [gender = "male"][
    ;;comfort and feeling-of-safety go between -2 uptil 2
    ifelse comfort > 0 [
      set comfort round (comfort * scale-factor)
      if comfort > 2 [
        set comfort 2 ;;max value
      ]
    ][
      set comfort round (comfort - (comfort * gender-impact-disparity))
    ]
    ifelse feeling-of-safety > 0 [
      set feeling-of-safety round (feeling-of-safety * scale-factor)
      if feeling-of-safety > 2 [
        set feeling-of-safety 2 ;;max value
      ]
    ][
      set feeling-of-safety round (feeling-of-safety - (feeling-of-safety * gender-impact-disparity))
    ]
    ifelse confidence > 0 [
      set confidence round (confidence * scale-factor)
      if confidence > 2 [
        set confidence 2 ;;max value
      ]
    ][
      set confidence round (confidence - (confidence * gender-impact-disparity))
    ]
  ]
end

to-report map-to-range [gaussian-dist-value]
  ifelse gaussian-dist-value < -1.5 [report -2]
  [ifelse gaussian-dist-value < -0.5 [report -1]
    [ifelse gaussian-dist-value < 0.5 [report 0]
      [ifelse gaussian-dist-value < 1.5 [report 1]
        [report 2]
      ]
    ]
  ]
end

;;this function creates people as per census data and assigns them a home location and age
to set-people-location [num-tehsil name-tehsil num-women]
  let i 0 ;; counter
  let num-men num-tehsil - num-women ;;variable defining number of men
  repeat num-tehsil [
    set i i + 1 ;; one person has been created.
    create-people 1 [
      set shape "person"
      let target-tehsil one-of patches with [tehsil = name-tehsil]
      setxy [pxcor] of target-tehsil [pycor] of target-tehsil
      set home-loc target-tehsil ;;home-loc is set as a random patch in tehsil and xy coordinates initialized to home location
      set pcolor blue - 3 ;;a really deep blue
      set destination home-loc
      set has-arrived? true
      ;;to be set in set-internal-vars fxn
      set employment-status nobody
      set feeling-of-safety nobody
      set income nobody
      set car-ownership? false
      set confidence nobody
      set comfort nobody
      set awareness nobody
      set harasser? false

      set urgency nobody
      set final-station nobody
      set BRT-use-score nobody
      set nearest-station nobody
      set at-work? false

      ifelse i <= num-women [
        set color magenta
        set gender "female"
        ;;AGE DIVISION FOR WOMEN BASED ON TEHSIL
        if name-tehsil = "Model Town"[
          if i <= round(0.39892 * num-women) [set age "child"]
          if i > round(0.39892 * num-women) and i <= round(0.9637 * num-women) [set age "adult"]
          if i > round(0.9637 * num-women) [set age "senior"]
        ]
        if name-tehsil = "Shalimar"[
          if i <= round(0.409300917 * num-women) [set age "child"]
          if i > round(0.409300917 * num-women) and i <= round(0.968262367 * num-women) [set age "adult"]
          if i > round(0.968262367 * num-women) [set age "senior"]
        ]
        if name-tehsil = "Raiwind"[
          if i <= round(0.441765763 * num-women) [set age "child"]
          if i > round(0.441765763 * num-women) and i <= round(0.968287458 * num-women) [set age "adult"]
          if i > round(0.968287458 * num-women) [set age "senior"]
        ]
        if name-tehsil = "Lahore Cantonment"[
          if i <= round(0.401860878 * num-women) [set age "child"]
          if i > round(0.401860878 * num-women) and i <= round(0.962137559 * num-women) [set age "adult"]
          if i > round(0.962137559 * num-women) [set age "senior"]
        ]
        if name-tehsil = "Lahore City"[
          if i <= round(0.399177972 * num-women)[set age "child"]
          if i > round(0.399177972 * num-women) and i <= round(0.965726716 * num-women) [set age "adult"]
          if i > round(0.965726716 * num-women)[set age "senior"]
        ]
      ][
        set color blue
        set gender "male"
        ;;AGE DIVISION FOR MEN BASED ON TEHSIL
        if name-tehsil = "Model Town"[
          if i <= (num-women + round(0.385643053 * num-men))[set age "child"]
          if i > (num-women + round(0.385643053 * num-men)) and i <= (num-women + round(0.961589147 * num-men)) [set age "adult"]
          if i > (num-women + round(0.961589147 * num-men))[set age "senior"]
        ]
        if name-tehsil = "Shalimar"[
          if i <= (num-women + round(0.406391933 * num-men))[set age "child"]
          if i > (num-women + round(0.406391933 * num-men)) and i <= (num-women + round(0.964471204 * num-men)) [set age "adult"]
          if i > (num-women + round(0.964471204 * num-men))[set age "senior"]
        ]
        if name-tehsil = "Raiwind"[
          if i <= (num-women + round(0.419189881 * num-men))[set age "child"]
          if i > (num-women + round(0.419189881 * num-men)) and i <= (num-women + round(0.966423061 * num-men)) [set age "adult"]
          if i > (num-women + round(0.966423061 * num-men))[set age "senior"]
        ]
        if name-tehsil = "Lahore Cantonment"[
          if i <= (num-women + round(0.386850115 * num-men))[set age "child"]
          if i > (num-women + round(0.386850115 * num-men)) and i <= (num-women + round(0.959547701 * num-men)) [set age "adult"]
          if i > (num-women + round(0.959547701 * num-men))[set age "senior"]
        ]
        if name-tehsil = "Lahore City"[
          if i <= (num-women + round(0.391991588 * num-men))[set age "child"]
          if i > (num-women + round(0.391991588 * num-men)) and i <= (num-women + round(0.962560883 * num-men)) [set age "adult"]
          if i > (num-women + round(0.962560883 * num-men))[set age "senior"]
        ]
      ]
    ]
  ]
end

;;sets up the initial final station based on urgency of trip (THIS ALSO NEEDS TO BE LOOKED INTO)
to setup-final-station
  let high-urgency-trips round (0.857 * num-people) ;;commuting to work/school and health (urgency 2)
  let low-urgency-trips round (0.071 * num-people) ;;leisure and shopping trips (urgency -2)
  let other-trips (num-people - (high-urgency-trips + low-urgency-trips))
  ;;high urgency trips
  ask n-of high-urgency-trips people with [has-arrived? = true and urgency = nobody][
    ifelse age = "child" [
      let target-patch one-of patches with [kind = "education" or kind = "health"]
      set work-loc target-patch
    ][
      let target-patch one-of patches with [kind = "work" or kind = "health"]
      set work-loc target-patch
    ]
    set destination work-loc
    set final-station nearest-station-to destination
    set has-arrived? false
    set urgency 2
  ]
  ;;low urgency trips
  ask n-of low-urgency-trips people with [has-arrived? = true and urgency = nobody][
    let target-patch one-of patches with [kind = "leisure" or kind = "shopping"]
    set work-loc target-patch
    set destination work-loc
    set final-station nearest-station-to destination
    set has-arrived? false
    set urgency -2
  ]
  ;;other trips
  ask people with [has-arrived? = true and urgency = nobody][
    let value_rand random 1 ;; a number that is 0 or 1
    ifelse value_rand = 1 [
      let target-patch one-of patches with [kind = "education" or kind = "work" or kind = "health"]
      set work-loc target-patch
      set destination work-loc
      set final-station nearest-station-to destination
      set has-arrived? false
      set urgency 2
    ][
      let target-patch one-of patches with [kind = "leisure" or kind = "shopping"]
      set work-loc target-patch
      set destination work-loc
      set final-station nearest-station-to destination
      set has-arrived? false
      set urgency -2
    ]
  ]
end

;;reports the nearest BRT station to a given patch.
to-report nearest-station-to [a-patch]
  ;;creates a list of all the turtles stations
  let stations-list stations
  ;;minimizing distance from station turtle to the destination patch
  let nearest-station-1 min-one-of stations-list [distance a-patch]
  report nearest-station-1
end

to add-POIs
  ;;education
  let education-xcor [62 63 42 65 56 34 39 29 55 39 37 56 30 43 54 51 56 54 40 63 64 61]
  let education-ycor [59 73 30 60 15 66 89 64 75 69 80 43 75 61 95 42 61 92 80 52 53 78]
  ;;food, supermarket
  let leisure-xcor [43 41 34 59 42 41 42 39 70 62 67 58 67 60 65 50 67 33 56 31 32 51 34 46 32 58 71 43 53 72 33 63 30 37 72 70]
  let leisure-ycor [88 63 77 76 95 36 28 17 26 53 11 15 62 73 59 29 18 01 93 82 79 85 73 61 62 58 40 29 32 11 14 00 00 99 82 97]
  ;;hospital and pharmacy
  let health-xcor [56 45 71 34 55 38 58 47 38 69 62 32 29 70 30 67 67 43 30 39 59 56]
  let health-ycor [92 79 65 66 64 39 38 26 16 10 20 5 94 93 76 7 16 18 57 27 58 92]
  ;; bank, police, shop
  let work-xcor [69 63 34 30 38 41 66 70 57 37 59 43 46 47 55 35 60 42 58 34 63 58 43 41 53 47 31 57 63 30 31 45 71 61 69 71 65 43 39 67 40 44 30 31 41 40]
  let work-ycor [05 17 18 12 26 32 33 42 52 45 57 77 83 87 90 04 20 24 35 37 35 52 55 76 83 84 98 98 93 75 66 61 84 51 40 44 34 28 17 03 02 16 72 66 66 63]
  (foreach education-xcor education-ycor [ [edux eduy] -> ask patch edux eduy [set kind "education" set pcolor red]])
  (foreach leisure-xcor leisure-ycor [ [lex ley] -> ask patch lex ley [set kind "leisure" set pcolor blue]])
  (foreach health-xcor health-ycor [ [hex hey] -> ask patch hex hey [set kind "health" set pcolor green]])
  (foreach work-xcor work-ycor [ [wox woy] -> ask patch wox woy [set kind "work" set pcolor pink]])
end

to create-brt
  create-stations 27;
  (foreach
   [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26]
   [34 38 38 41 41 41 40 41 43 45 47 48 50 51 53 54 56 57 60 62 62 63 64 65 65 66 66]
   [100 93 91 88 84 81 78 75 71 69 65 61 55 52 49 45 41 37 30 27 24 20 15 10 7 3 0]
   ["SHAHDARA" "NIAZI" "TIMBER MARKET" "AZADI CHOWK" "BHATTI" "KATCHEHRY" "CIVIL SECRETARIAT" "MAO COLLEGE" "JANAZGAH" "QARTABA CHOWK" "SHAMA"
    "ICHRA" "CANAL" "QADDAFI STADIUM" "KALMA" "MODEL TOWN" "NASEERABAD" "ITTEFAQ HOSPITAL" "QAINCHI" "GHAZI CHOWK" "CHUNGI AMAR SIDHU" "KAMAHAN"
    "ATTARI SAROBA" "NISHTAR COLONY" "YOUHANABAD" "DULLU KHURD" "GAJJUMATA"]
    [ [station-number x y station-name] -> ask station station-number [hide-turtle setxy x y set name station-name] ] )
  (foreach
    [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25]
    [[station-number] -> ask station station-number [create-link-to station (station-number + 1) [hide-link] ]])
end

to import-gis-data
  gis:load-coordinate-system (word "/Users/mehreennaveed/Downloads/Public Routes - Dr Aaamir/Shapefiles/Metro_line.prj")
  let metroline-dataset gis:load-dataset "/Users/mehreennaveed/Downloads/Public Routes - Dr Aaamir/Shapefiles/Metro_line.shp"
  let metrostation-dataset gis:load-dataset "/Users/mehreennaveed/Downloads/Public Routes - Dr Aaamir/Shapefiles/Metro_station.shp"
  ; Set the world envelope to the union of all of our dataset's envelopes
  gis:set-world-envelope (gis:envelope-union-of (gis:envelope-of metrostation-dataset) (gis:envelope-of metroline-dataset))
  ;;gis:import-wms-drawing server-url spatial-reference layers transparency
  gis:import-wms-drawing "https://ows.terrestris.de/osm/service?" "EPSG:4326" "OSM-WMS" 50
  ;;defining the colors for metroline and station datasets
  gis:set-drawing-color black
  gis:draw metroline-dataset 3
  gis:set-drawing-color green
  gis:fill metrostation-dataset 4
  gis:set-drawing-color black
  gis:draw metrostation-dataset 3
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
1228
1029
-1
-1
10.0
1
10
1
1
1
0
0
0
1
0
100
0
100
0
0
1
ticks
30.0

BUTTON
130
10
200
43
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
1

BUTTON
8
10
113
43
NIL
setup\n
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
5
65
205
215
BRT-use-score distribution 
Value
No. of ppl
-5.0
5.0
0.0
10.0
true
true
"" ""
PENS
"all" 0.1 1 -16777216 true "set-plot-x-range -4 4" "histogram [BRT-use-score] of people"
"female" 0.1 1 -5825686 true "set-plot-x-range -4 4" "histogram [BRT-use-score] of people with [gender = \"female\"]"

TEXTBOX
10
235
190
253
USER DEFINED VARIABLES
14
0.0
1

SLIDER
5
260
200
293
num-people
num-people
0
100
67.0
1
1
NIL
HORIZONTAL

SLIDER
5
305
200
338
social-stigma
social-stigma
0
1
0.8
0.1
1
NIL
HORIZONTAL

SLIDER
5
350
200
383
gender-impact-disparity
gender-impact-disparity
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
5
395
200
428
bus-capacity
bus-capacity
0
50
27.0
1
1
NIL
HORIZONTAL

SLIDER
5
485
200
518
harasser-impact
harasser-impact
0
2
1.0
1
1
NIL
HORIZONTAL

SLIDER
5
440
200
473
harasser-percentage
harasser-percentage
0
1
0.7
0.1
1
NIL
HORIZONTAL

TEXTBOX
1245
10
1395
28
WEIGHTS
14
0.0
1

TEXTBOX
1245
40
1395
58
Safety
10
0.0
1

SLIDER
1245
60
1475
93
weight_a
weight_a
0
1
0.5
0.1
1
NIL
HORIZONTAL

TEXTBOX
1245
105
1395
123
Urgency\n
10
0.0
1

SLIDER
1245
125
1475
158
weight_b
weight_b
0
1
0.8
0.1
1
NIL
HORIZONTAL

TEXTBOX
1240
170
1390
188
Social Norms
10
0.0
1

SLIDER
1245
190
1475
223
weight_c
weight_c
0
1
1.0
0.1
1
NIL
HORIZONTAL

TEXTBOX
1240
230
1390
248
Income
10
0.0
1

SLIDER
1245
250
1475
283
weight_d
weight_d
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1245
315
1475
348
weight_e
weight_e
0
1
1.0
0.1
1
NIL
HORIZONTAL

TEXTBOX
1240
295
1390
313
Awareness
10
0.0
1

SLIDER
5
530
200
563
over-crowding-impact
over-crowding-impact
0
2
1.0
1
1
NIL
HORIZONTAL

TEXTBOX
1240
370
1390
388
POLICIES
14
0.0
1

SWITCH
1240
415
1372
448
capacity-check?
capacity-check?
1
1
-1000

TEXTBOX
1240
395
1390
413
Implentation of capacity check
10
0.0
1

PLOT
1240
670
1490
885
Total Trips Completed By Women
Time
Total Trips Completed
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"women" 1.0 0 -5825686 true "" "plot total-travel-women"

TEXTBOX
1240
460
1390
478
Gender-segregated buses
10
0.0
1

SWITCH
1240
480
1342
513
pink-bus?
pink-bus?
1
1
-1000

TEXTBOX
1240
525
1390
543
Awareness initiatives
10
0.0
1

SWITCH
1240
545
1417
578
awareness-campaigns?
awareness-campaigns?
1
1
-1000

TEXTBOX
1240
595
1390
613
Safety Initiatives at Bus Stops
10
0.0
1

SWITCH
1240
615
1362
648
safety-check?
safety-check?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

pink-bus? 
- only women are allowed on the bus and to use bus, women must have value of prob-of-using greater than the mean of prob-of-using of all women (not men and women)
- harasser-impact is halfed in this scenario. Equal chance of harassment to happen and not happen. 
- dynamic change 
- Feeling-of-safety and confidence of all women increased by 1. 
capacity-check?
- this ensures that bus-capacity is followed. People are only allowed to board if passengers on bus is less than bus-capacity. This ensures that the comfort of women on bus is not decreased everytime bus-capacity is exceeded.
- dynamic-change  
safety-check? 
- change shown during setup! 
awareness-campaign? 
- dynamic change during run-time   
 

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

bus
false
0
Polygon -7500403 true true 15 206 15 150 15 120 30 105 270 105 285 120 285 135 285 206 270 210 30 210
Rectangle -16777216 true false 36 126 231 159
Line -7500403 false 60 135 60 165
Line -7500403 false 60 120 60 165
Line -7500403 false 90 120 90 165
Line -7500403 false 120 120 120 165
Line -7500403 false 150 120 150 165
Line -7500403 false 180 120 180 165
Line -7500403 false 210 120 210 165
Line -7500403 false 240 135 240 165
Rectangle -16777216 true false 15 174 285 182
Circle -16777216 true false 48 187 42
Rectangle -16777216 true false 240 127 276 205
Circle -16777216 true false 195 187 42
Line -7500403 false 257 120 257 207

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
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
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
