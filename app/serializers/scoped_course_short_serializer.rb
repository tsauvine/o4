class ScopedCourseShortSerializer < ActiveModel::Serializer
  attributes :id,
             :course_code,
             :credits,
             :localized_name,
             :studyplan_path

  def studyplan_path
    studyplan_course_path(object.id)
  end
end
