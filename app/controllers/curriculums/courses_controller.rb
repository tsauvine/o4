class Curriculums::CoursesController < CurriculumsController

  before_filter :load_curriculum

  respond_to :json
  # html for only show, new & create

  # GET /courses
  # GET /courses.xml
  def index
    #@courses = @curriculum.courses

    @courses = ScopedCourse.where(:curriculum_id => @curriculum.id)
                .joins(:course_descriptions)
                .where(["course_descriptions.locale = ?", I18n.locale]).includes(:strict_prereqs)
#                 .joins(<<-SQL
#                     INNER JOIN course_descriptions
#                       ON competence_nodes.abstract_course_id = course_descriptions.abstract_course_id
#                   SQL
#                 )

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @courses }
      format.json do
        render :json => @courses.select(<<-SQL
            competence_nodes.id,
            competence_nodes.course_code,
            course_descriptions.name AS translated_name
          SQL
        ).to_json(:methods => :strict_prereq_ids)

      end
    end
  end

  # GET /courses/1
  # GET /courses/1.xml
  # Returns JSON:
  #   {
  #     "scoped_course": {
  #       "course_code":"T-0.000",
  #       "id":5,
  #       "skills": [
  #         {
  #           "id":1231,
  #           "skill_descriptions":[
  #             {
  #               "id":1760,
  #               "locale": "en"
  #               "description": "in english",
  #             },
  #             {...}
  #           ]
  #         },
  #         { another skill... }
  #       ]
  #     }
  #   }
  def show
    @course = ScopedCourse.includes(:skills => [:skill_descriptions, :skill_prereqs, :prereq_to]).find(params[:id])
    @profile = Profile.find(params[:profile_id]) if params[:profile_id]  ## FIXME!?!

    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @course.to_json(
        :only => [:id, :course_code],
        :include => {
            :skills => {
              :only => [:id, :icon],
              :include => {
                :skill_descriptions => {
                  :only => [:id, :locale, :description]
                },
                :skill_prereqs => {:only => [:prereq_id, :requirement]},
                :prereq_to => {:only => [:id, :requirement, :icon]}
              }
            },
            :course_descriptions => {
              :only => [:id, :locale, :name]
            }
        }
      )}
    end
  end

  def prereqs
    @course = ScopedCourse.find(params[:id])

    render :action => 'prereqs', :layout => 'views/curriculums/bare'
  end

  def edit_prereqs
    @scoped_course = ScopedCourse.find(params[:id])
    @competence_node = @scoped_course
    authorize! :update, @curriculum

    @hide_help = cookies[:hide_edit_prereqs_help] == 't' ? true : false

    @competence_node_url = curriculum_course_path(:curriculum_id => @curriculum, :course_id => @course)

    render :action => 'edit_prereqs', :layout => 'views/curriculums/wide'
  end

  def edit_as_a_prereq
    @scoped_course = ScopedCourse.find(params[:id])
    @competence_node = @scoped_course
    authorize! :update, @curriculum

    @hide_help = cookies[:hide_edit_as_a_prereq_help] == 't' ? true : false

    @competence_node_url = curriculum_course_path(:curriculum_id => @curriculum, :course_id => @course)

    render :action => 'edit_as_a_prereq', :layout => 'views/curriculums/wide'
  end

  def comments
    @scoped_course = ScopedCourse.find(params[:id])
    @new_comment = Comment.new

    render :action => 'comments', :layout => 'views/curriculums/wide'
  end

  def create_comment
    @scoped_course = ScopedCourse.find(params[:id])
    authorize! :update, @curriculum

    @comment = Comment.new(params[:comment])
    @comment.commentable = @scoped_course
    @comment.user = current_user

    @comment.save

    redirect_to comments_curriculum_course_path(:curriculum_id => @curriculum, :id => @scoped_course)
  end

  def new
    authorize! :update, @curriculum

    @scoped_course = ScopedCourse.new
    @scoped_course.curriculum = @curriculum #Curriculum.find(params[:curriculum_id])
    #@scoped_course.abstract_course = @abstract_course

    # Create empty descriptions for each required locale
    REQUIRED_LOCALES.each do |locale|
      @scoped_course.course_descriptions << CourseDescription.new(:locale => locale)
    end

    @teaching_lang_options = REQUIRED_LOCALES.map do |locale|
      [t(locale + '_lang'), locale]
    end

    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    authorize! :update, @curriculum

    @scoped_course = ScopedCourse.new(params[:scoped_course])
    @scoped_course.curriculum = @curriculum

    # Find or create AbstractCourse
    @abstract_course = AbstractCourse.find_by_code(@scoped_course.course_code)
    @abstract_course = AbstractCourse.create(:code => @scoped_course.course_code) unless @abstract_course

    @scoped_course.abstract_course = @abstract_course

    respond_to do |format|
      format.html do
        if @scoped_course.save
          redirect_to edit_curriculum_path(@curriculum)
        else
          render :action => "new"
        end
      end
    end
  end

  def edit
    @scoped_course = ScopedCourse.find(params[:id])
    authorize! :update, @curriculum

    @localized_description = @scoped_course.localized_description

    render :action => 'edit', :layout => 'views/curriculums/wide'
  end

  def update
    @scoped_course = ScopedCourse.find(params[:id])
    authorize! :update, @curriculum

    @scoped_course.localized_description.update_attributes(params[:course_description])
    @scoped_course.update_comments(params[:comments])

    # Update AbstractCourse if changed
    new_course_code = params[:scoped_course]['course_code']
    if new_course_code != @scoped_course.abstract_course.code
      @scoped_course.abstract_course = AbstractCourse.find_by_code(new_course_code) || AbstractCourse.create(:code => new_course_code)
    end

    if @scoped_course.update_attributes(params[:scoped_course])
      flash[:success] = 'Information updated'
      redirect_to edit_curriculum_course_path(:curriculum_id => @curriculum, :id => @scoped_course)
    else
      render :action => "edit"
    end
  end

  def graph
    @scoped_course = ScopedCourse.find(params[:id])

    render :action => 'graph', :layout => 'views/curriculums/wide'
  end

end
