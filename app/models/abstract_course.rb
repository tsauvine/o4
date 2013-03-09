# Course that is not scoped to a specific curriculum or period.
class AbstractCourse < ActiveRecord::Base

  has_many :course_descriptions, :dependent => :destroy
  has_many :scoped_courses, :dependent => :destroy      # Courses in curriculums. e.g. "Course X-0.1010 according to the 2005 study guide"
  has_many :course_instances, :dependent => :destroy    # Course implementations, e.g. "Course X-0.1010 (spring 2011)"
  
  has_many :course_descriptions_with_locale, :class_name => "CourseDescription", 
           :conditions => proc { "locale = '#{I18n.locale}'" }
           
  has_one :course_description_with_locale, :class_name => "CourseDescription", 
           :conditions => proc { "locale = '#{I18n.locale}'" }

  has_many  :periods,
            :through  => :course_instances

  accepts_nested_attributes_for :course_descriptions
  accepts_nested_attributes_for :scoped_courses
  
  
  # Make sure that nested ScopedCourses create at the same time get the same course code
  before_create do |abstract_course|
    abstract_course.scoped_courses.each do |scoped_course|
      scoped_course.course_code = abstract_course.code
    end
  end
  
  def get_name(locale)
    description = CourseDescription.where(:abstract_course_id => self.id, :locale => locale.to_s).first
    description ? description.name : ''
  end
  
  # Returns CourseInstances
  def instances
    raise NotImplementedError, "AbstractCourse::instances not implemented"
  end
  
  # Returns the scoped course associated with this abstract course and the given curriculum
  # curriculum: Curriculum object or id
  def scoped_course(curriculum)
    if curriculum.is_a?(Numeric)
      curriculum_id = curriculum
    elsif curriculum.is_a?(Curriculum)
      curriculum_id = curriculum.id
    else
      raise ArgumentError("AbstractCourse::scoped_course needs a Curriculum object or id")
    end
    
    ScopedCourse.where(:curriculum_id => curriculum_id, :abstract_course_id => self.id).first
  end
end
