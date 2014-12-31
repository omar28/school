require "addressable/uri"
require 'httparty'

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :async

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me,
                  :name, :hide_last_name, :homepage, :github_username,
                  :school_id, :subscribe_lesson_notifications,
                  :subscribe_badge_notifications, :codewars_username

  has_many :attendances
  has_many :user_answers
  has_many :user_badges
  #has_many :answers
  has_many :lessons, :through => :attendances
  has_many :lessons_taught, class_name: "Lesson", foreign_key: :teacher_id
  belongs_to :school

  before_save :generate_unsubscribe_token, :canonicalize_homepage
  validates_uniqueness_of :email

  def generate_unsubscribe_token
    # don't generate unsubscribe token for dummy users
    #   (IE users with no encrypted password)
    if unsubscribe_token.blank? && encrypted_password.present?
      self.unsubscribe_token = (0..15).map{(65+rand(26)).chr}.join
    end
  end

  def canonicalize_homepage
    if homepage_changed?
      self.homepage = Addressable::URI.heuristic_parse(homepage).to_s
    end
  end

  def attend?(class_id)
    Attendance.where(:lesson_id => class_id, :user_id => id).any?
  end

  def answered?(poll)
    UserAnswer.where(:poll_id => q.id, :user_id => id).any?
  end

  def next_unanswered_poll
    if user_answers.any?
      Poll.where(['id not in (?)', user_answers.map(&:poll_id)]).first
    else
      Poll.first
    end
  end

  def rsvp_for(lesson)
    attendances.create(lesson_id: lesson.id) unless lesson.teacher == self
  end

  def badges
    user_badges.map { |user_badge|
      Badge.find_by_badge_id(user_badge.badge_id).new
    }
  end

  def codewars_completed
    if codewars_username.present?
      response = HTTParty.get("https://www.codewars.com/api/v1/users/#{codewars_username}/code-challenges/completed")
      response['data'].count
    else
      0
    end
  end
end
