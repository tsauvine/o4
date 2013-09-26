class AbstractCoursesController < ApplicationController
  respond_to :json
  
  def search
    queryID    = params[:queryID]
    do_star      = params[:star] || true
    max_matches  = params[:max_matches] || 100
    
    # Form the query
    # Replace whitespace with stars ('diff eq' -> '*diff* *eq*')
    query = '*' + Riddle::Query.escape(params[:query].strip()).gsub(/\s+/, '* *') + '*'
    
    unless query
      response_data = { status: 'error', queryID: queryID }
    else query
      log("search_course #{params[:query]}")

      abstract_courses = AbstractCourse.search(
        query,
        ranker:      :proximity_bm25,
        max_matches: max_matches,
        per_page:    max_matches,
        sql:         { :include => [:localized_description] }
      )

      abstract_courses_json = abstract_courses.map do |abstract_course|
        localized_description = abstract_course.localized_description || {}
        {
          'id' => abstract_course.id,
          'course_code'=> abstract_course.code,
          'name' => localized_description.name,
          'min_credits' => abstract_course.min_credits,
          'max_credits' => abstract_course.max_credits,
          'noppa_url' => localized_description.noppa_url,
          'oodi_url' => localized_description.oodi_url,
          'default_period' => localized_description.default_period,
          'period_info' => localized_description.period_info,
        }
      end
      
      response_data = {
        status: 'ok',
        queryID:  queryID,
        courses: abstract_courses_json
      }
    end

    respond_to do |format|
      format.js do
        render :json => response_data.to_json(:root => false)
      end
    end
  end
end
