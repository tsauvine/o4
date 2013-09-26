# Check that i18n strings have been loaded before this file
if not O4.schedule.i18n
  throw "plan view i18n strings have not been loaded!"

class @PlanView

  @PERIOD_HEIGHT: 58
  @COURSE_WIDTH: 120
  @COURSE_MARGIN_X: 6
  @COURSE_MARGIN_Y: 6
  @COURSE_PADDING_Y: 3
  ISREADY: false
  I18N: O4.schedule.i18n

  constructor: (@planUrl) ->
    @selectedObject = ko.observable()
    @selectedObjectType = ko.observable()

    $('#infomsg').fadeOut(0)
    @showAsEditable = false
    #@showAsEditable = ko.observable(false)

    # List of courses to be saved and rejected when tried to save.
    @coursesToSave = []
    @coursesRejected = []


  showAsEditableInit: ->
    #dbg.lg("showAsEditableInit()!")
    @showAsEditable = false
    $('#credits #in, #grade #in, #length #in').hide()

  doShowAsEditable: ->
    if not @showAsEditable
      @showAsEditable = true
      $('#credits .out, #grade .out, #length .out').hide()
      $('#credits .in, #grade .in, #length .in').show()

  noShowAsEditable: ->
    if @showAsEditable
      @showAsEditable = false
      $('#credits .in, #grade .in, #length .in').hide()
      $('#credits .out, #grade .out, #length .out').show()


  loadPlan: () ->
    $.ajax
      url: @planUrl + '/old_schedule',
      dataType: 'json',
      success: (data) => this.loadJson(data)
    
    this.loadJson(schedule_data)


  # Loads the plan from JSON data
  loadJson: (data) ->
    @competences = []
    @courses = []
    @coursesByScopedId = {}
    @coursesByAbstractId = {}
    @periods = []
    @periodsById = {}
    @currentPeriod = undefined
  
    startTime = new Date().getTime()

    # Init before knockout hides related elements
    @showAsEditableInit()

    # Load periods
    periodCounter = 0
    previousPeriod = undefined

    for raw_period in data['periods']
      period = new Period(raw_period)
      period.sequenceNumber = periodCounter
      period.previousPeriod = previousPeriod
      previousPeriod.nextPeriod = period if previousPeriod
      previousPeriod = period
      periodCounter++
      @currentPeriod = period if period.isNow
      @periodsById[period.id] = period
      @periods.push(period)

    # Make sure we always have current period. (This is relevant if the studyplan begins in the future.)
    @currentPeriod ||= @periods[0]

    # Load courses
    for course_data in data['plan_courses']
      course = new Course(course_data, @periodsById)
      @courses.push(course)
      @coursesByScopedId[course.scopedId] = course
      @coursesByAbstractId[course.abstractId] = course

    # Load course prerequirements
    for course in @courses
      course.allPrereqsInPlan = true
      for prereqId in course.prereqIds
        prereq = @coursesByScopedId[prereqId]
        unless prereq
          console.log "Unknown prereqId #{prereqId}!"
          course.allPrereqsInPlan = false
          continue
        course.addPrereq(prereq)

    # Load competences
    for competence_data in data['competences']
      competence = new Competence()
      competence.loadJson(competence_data, @coursesById)
      @competences.push(competence)

    # Automatically schedule unscheduled (new) courses
    schedule = new Scheduler(@courses, @currentPeriod)
    schedule.scheduleUnscheduledCourses()


    # Set periods and save the 'originals'
    dbg.lg("Setting the courses to the periods...")
    for course in @courses
      # If the course was moved by the scheduler
      if schedule.moved[course.scopedId]
        course.resetOriginals()
        course.period = undefined
        course.setPeriod(schedule.schedule[course.scopedId], true)
      # Else if the course has a place to go to
      else if course.period
        period = course.period
        course.period = undefined
        course.setPeriod(period)
        course.resetOriginals()
      # Hmmh...?
      else
        dbg.lg("WARNING: A vagabond course: #{course}!")
        course.resetOriginals()

      # Update course ordering related warnings
      course.updateReqWarnings()


    # Apply ko bindings
    console.log "Applying bindings..."
    preBindTime = new Date().getTime()
    ko.applyBindings(this)
    postBindTime = new Date().getTime()

    # Update positions
    for course in @courses
      course.updatePosition() if course.period

    # Flag the PlanView as ready
    PlanView::ISREADY = true

    # Select the current period by default. Also sets the viewport to show it
    # if it's outside of the current viewport area.
    @selectObject(@currentPeriod)

    # Initialize tooltips
    #$('div#plan-container div.period div.credits span').tooltip(placement: 'left')
    #$('div#plan-container div.course').tooltip(placement: 'bottom', delay: 1500)
    #$('div.well div.progress').tooltip(placement: 'bottom', delay: 1000)

    # Autoscroll the viewport to show the current period and the near future
    dbg.lg("Autoscrolling the viewport...")
    topOffSet = $('div.period.now').offset()
    $(window).scrollTop(topOffSet.top - 2 * @constructor.PERIOD_HEIGHT) if topOffSet

    # Reconfigure the affixed sidebars height in static mode to a static value
    # instead of the default 'auto', which would cause irritable bouncing of the
    # plan div below it as the size of the former div changes.
    # The 'update' method is also called so that it can realize that the size of
    # the div it is to 'side' has changed as periods have been injected into it.
    affixedSidebar = affxd.Sidebar::get()
    affixedSidebar.reset('staticHeight', 600)

    # Log time used from start to bind and here
    endTime = new Date().getTime();
    dbg.lg("Parsing & modelling the plan data took #{preBindTime - startTime} (preBind) + #{postBindTime - preBindTime} (bind) + #{endTime - postBindTime} (postBind) = #{endTime - startTime} (total) milliseconds.")
    
    $('.loader').remove()


  unselectObjects: (data, event) ->
    @selectObject()


  selectObject: (object) ->
    # Deselect the old object
    selectedObject = @selectedObject()

    # Call the object's setSelected handler
    selectedObject.setSelected(false) if selectedObject

    # Select the new object
    # NB: undefined first to avoid ko autoupdate oddness
    @selectedObjectType(undefined)
    @selectedObject(undefined)
    @selectedObjectType('Course') if object instanceof Course
    @selectedObjectType('Period') if object instanceof Period
    @selectedObjectType('Competence') if object instanceof Competence
    @selectedObject(object)

    # Call the object's setSelected handler
    object.setSelected(true) if object

    # Scroll the scrollbar in order to have the selected object visible.
    # Important when using the keyboard.
    if @selectedObjectType() in ['Course', 'Period']
      # Load the viewports DOM data; using an approximation for scrollbar height
      viewPortTop = $(window).scrollTop()
      viewPortHeight = $(window).height()
      viewPortBottom = viewPortTop + viewPortHeight
      objectContainerTop = $('#themain').offset().top
      if @selectedObjectType() == 'Course'
        objectHeight = object.position().height
      else
        objectHeight = PlanView.PERIOD_HEIGHT
      # The 0.25's are added in order to not be too strict
      objectTop = object.position().y + objectContainerTop
      objectBottom = objectTop + objectHeight
      objectTopLimit = objectTop + objectHeight * 0.25
      objectBottomLimit = objectTop + objectHeight * 0.75

      #dbg.lg("topOffSet: #{objectTop} - #{objectBottom} vs #{viewPortTop} - #{viewPortBottom}.")

      # If 3/4ths of the object cannot be seen, we recenter the viewport
      if objectBottomLimit > viewPortBottom
        newViewPortTop = (objectBottom + objectTop) / 2 - viewPortHeight / 2
      else if objectTopLimit < viewPortTop
        newViewPortTop = (objectBottom + objectTop) / 2 - viewPortHeight / 2

      $(window).scrollTop(newViewPortTop)


  # Reset the coursesToSave array according to changes made since last save
  updateCoursesToSave: ->
    @coursesToSave = []
    for course in @courses
      if course.hasChanged()
        dbg.lg("Course \"#{course.name}\" was changed.")
        @coursesToSave.push(course)

    if @coursesToSave.length == 0
      dbg.lg('No essential changes on any course.')


  # Returns true if there is any nonsaved data
  anyUnsavedChanges: ->
    # Update coursesToSave according to made changes
    @updateCoursesToSave()
    # Check if any changes were made
    return @coursesToSave.length > 0


  save: ->
    # {
    #   "plan_courses": [
    #     {"scoped_course_id": 71, "period_id": 1, "course_instance_id": 45},
    #     {"scoped_course_id": 35, "period_id": 2},
    #     {"scoped_course_id": 45, "period_id": 2, "credits": 3, "length": 1},
    #     {"scoped_course_id": 60, "period_id": 3, "course_instance_id": 32, "credits": 8, "length": 2, "grade": 3},
    #     ...
    #   ]
    # }

    # Check if any changes should be saved
    if not @anyUnsavedChanges()
      @flashInfo('text-info', @I18N.no_unsaved_changes)
      dbg.lg('No unsaved data. No reason to put.')
      return

    # Calculate total credits
    total_credits = 0
    for course in @courses
      total_credits += course.credits()
    
    # Koeasetelma
    has_kjr = false
    has_eny = false
    for competence in @competences
      has_kjr = true if competence.id == 59
      has_eny = true if competence.id == 73

    # Load the data
    planCoursesToSave = []  # Array for course JSON representations for sending
    for course in @coursesToSave
      dbg.lg("Pushing \"#{course.name}\" to be saved.")
      planCoursesToSave.push(course.asHash())

    dbg.lg("A total of #{@coursesToSave.length} courses changed. Starting the put.")

    # For informing the user of potential unaccepted alterations / db failures
    @coursesRejected = []

    $.ajax
      url: @planUrl
      type: 'put'
      dataType: 'json'
      async: false
      data: { 'json': {'plan_courses_to_update': JSON.stringify(planCoursesToSave)} }
      error: @onSaveFailure()
      success: (data) =>
        dbg.lg("data: #{data}")
        dbg.lg("data: #{JSON.stringify(data)}")
        if data['status'] == 'ok'
          feedback = data['feedback']['plan_courses_to_update']
          if feedback
            for course in @coursesToSave
              if feedback[course.scopedId]
                dbg.lg("Course \"#{course.name}\" was successfully saved.")
                course.resetOriginals()
              else
                dbg.lg("ERROR: Course \"#{course.name}\" was rejected by the server! Saving failed!")
                @coursesRejected.push(course)
            if @coursesRejected.length > 0
              @onSaveFailure()
            else
              @flashInfo('text-success', @I18N.your_changes_have_been_saved)
          else
            dbg.lg("ERROR: No feedback returned!")
            @onSaveFailure()
            
          #console.log "Treatment: #{user_treatment}"
          #console.log "Total credits: #{total_credits}"
          #console.log "KJR: #{has_kjr}"
          #console.log "ENY: #{has_eny}"
          #if (user_treatment == 1 || user_treatment == 2) && total_credits >= 160 && (has_kjr || has_eny)
          #  window.location.href = "https://o4.cs.hut.fi/fi/surveys/1"
            
        else
          dbg.lg("ERROR: Put on server failed!")
          @onSaveFailure()


  flashInfo: (css, text) ->
    $('#infomsg').removeClass().addClass(css).text(text).fadeIn(2000)
    setTimeout(
      -> $('#infomsg').fadeOut(2000, => $('#infomsg').text('').removeClass())
      5000
    )


  onSaveFailure: ->
    $('#infomsg').removeClass().addClass('text-error').text(@I18N.on_save_failure_instructions).fadeIn(1000)
