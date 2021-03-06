class Event < ActiveRecord::Base
  include DirtyColumns
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  
  belongs_to :venue
  has_many :event_days, -> { order('date desc').order('start_time desc') }
  has_many :attendees
  has_many :users, through: :attendees
  has_and_belongs_to_many :candidates #TODO add ordering through people
  has_and_belongs_to_many :people, -> { order('last_name').order('nickname').order('first_name').order('middle_name') }
  
  attr_reader :venue_name
    
  scope :joins_event_days, -> {
    joins('inner join event_days on event_days.event_id = events.id')
      .order('event_days.date desc')
      .order('event_days.start_time desc') }
  
  scope :upcoming, -> {
    joins_event_days.where('event_days.start_time > now()') }

  scope :past, -> {
    joins_event_days.where('event_days.end_time < now()') }
  
  #configure elastic search
  def as_indexed_json(options = {})
    as_json(only: [:title, :description],
            methods: [:format_candidates, :format_speakers, :format_location])
  end
  
  #roll up the statements from all the event days
  def statements
    Statement.approved
      .joins('inner join event_days on statements.event_day_id = event_days.id')
      .joins('inner join events on event_days.event_id = events.id')
      .where(['events.id = ?', self.id])
  end
  
  def start_time 
    start_day = self.event_days.first
    start_day ? start_day.start_time : nil
  end
  
  def format_start_date
    start_day = self.event_days.first
    (start_day ? (start_day.date ? AMERICA_NEW_YORK_TIME_ZONE.format_date(start_day.date) : '') : '').gsub(' ', '&nbsp;').html_safe
  end
  
  def format_speakers
    self.people.map(&:full_name).join(', ')
  end
  
  def format_people
    (self.candidates.map(&:person_name) + self.people.map(&:full_name)).uniq.join(', ')
  end 
  
  def format_location
    v = self.venue
    if v
      [v.name, v.city, v.state, v.postal_code].delete_if { |d| d.nil? or d.blank? }.join(", ")
    else
      ""
    end
  end
  
  def add_candidate(candidate_id)
    candidate = Candidate.find(candidate_id)
    self.candidates << candidate if candidate
    candidate
  end
  
  def remove_candidate(candidate_id)
    candidate = Candidate.find(candidate_id)
    self.candidates.delete(candidate) if candidate
    candidate
  end

  def add_person(person_id)
    person = Person.find(person_id)
    self.people << person if person
    person
  end
  
  def remove_person(person_id)
    person = Person.find(person_id)
    self.people.delete(person) if person
    person
  end
end