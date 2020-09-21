class Manage::DashboardController < Manage::ApplicationController
  before_action :require_director_or_organizer

  def index
  end

  def map_data
    @schools = School.where("questionnaire_count", 1..Float::INFINITY).select([:name, :address, :city, :state, :questionnaire_count])
  end

  def todays_activity_data
    where_filter = nil
    types = ["Applications", "Confirmations", "Denials"]
    if params[:school_id]
      where_filter = { school_id: params[:school_id] }
    else
      types << "Incomplete Applications"
    end
    render json: activity_chart_data(types, "hour", Time.zone.today.beginning_of_day..Time.zone.today.end_of_day, where_filter)
  end

  def todays_stats_data
    date_min = Time.zone.today.beginning_of_day
    render json: {
      "Applications" => Questionnaire.where("created_at >= :date_min", date_min: date_min).count,
      "Confirmations" => Questionnaire.where("acc_status = \"rsvp_confirmed\" AND acc_status_date >= :date_min", date_min: date_min).count,
      "Denials" => Questionnaire.where("acc_status = \"rsvp_denied\" AND acc_status_date >= :date_min", date_min: date_min).count,
      "Incomplete Applications" => User.without_questionnaire.where("users.created_at >= :date_min", date_min: date_min).count,
    }
  end

  def checkin_activity_data
    render json: activity_chart_data(["Checked In", "Boarded Bus"], "hour", 3.days.ago..Time.zone.now)
  end

  def confirmation_activity_data
    where_filter = nil
    if params[:school_id]
      where_filter = { school_id: params[:school_id] }
    end
    render json: activity_chart_data(["Confirmations", "Denials"], "day", 3.week.ago..Time.zone.now, where_filter)
  end

  def application_activity_data
    render json: activity_chart_data(["Away Applications", "Home Applications", "Incomplete Applications"], "day", 3.week.ago..Time.zone.now)
  end

  def user_distribution_data
    total_stats_data = {}
    total_count = Questionnaire.count
    rit_count = Questionnaire.joins(:school).where("schools.is_home = true").count
    total_stats_data["Incomplete Applications"] = User.without_questionnaire.count
    total_stats_data["Away Applications"] = total_count - rit_count
    total_stats_data["Home Applications"] = rit_count
    render json: total_stats_data
  end

  def application_distribution_data
    counts = Questionnaire.group(:acc_status).count
    results = Questionnaire::POSSIBLE_ACC_STATUS.map { |acc_status, status_title| [status_title, counts[acc_status] || 0] }
    render json: results
  end

  def schools_confirmed_data
    schools = Questionnaire.joins(:school).group("schools.name").where("acc_status = 'rsvp_confirmed'").order("schools.name ASC").count
    schools_riding = Questionnaire.joins(:school).group("schools.name").where("acc_status = 'rsvp_confirmed' AND bus_list_id").count
    schools = schools.map do |name, count|
      bus_count_row = schools_riding.select { |school_bus_name, _| school_bus_name == name }
      bus_count = bus_count_row ? bus_count_row[name] || 0 : 0
      count_without_bus = count - bus_count
      [name, count_without_bus, bus_count]
    end
    render json: [
      { name: "Not riding bus", data: schools.sort_by { |_, no_bus, bus| [bus, no_bus] }.reverse },
      { name: "Riding bus", data: schools_riding },
    ]
  end

  def schools_applied_data
    counted_schools = {
      "pending" => {},
      "denied" => {},
      "rsvp_denied" => {},
      "late_waitlist" => {},
      "waitlist" => {},
      "accepted" => {},
      "rsvp_confirmed" => {},
    }
    # Temporary fix
    # result = Questionnaire.joins(:school).group(:acc_status, "schools.name").where("schools.questionnaire_count >= 5").order("schools.questionnaire_count DESC").order("schools.name ASC").count
    query = Questionnaire.joins(:school).group(:acc_status, "schools.name", "schools.questionnaire_count").order("schools.questionnaire_count DESC")
    if School.where("questionnaire_count >= 5").count > 0
      query = query.where("schools.questionnaire_count >= 5")
    end
    result = query.count
    result.each do |group, count|
      counted_schools[group[0]][group[1]] = count
    end
    render json: [
      { name: "RSVP Confirmed", data: counted_schools["rsvp_confirmed"] },
      { name: "Accepted", data: counted_schools["accepted"] },
      { name: "Waitlisted", data: counted_schools["waitlist"] },
      { name: "Late Waitlisted", data: counted_schools["late_waitlist"] },
      { name: "RSVP Denied", data: counted_schools["rsvp_denied"] },
      { name: "Denied", data: counted_schools["denied"] },
      { name: "Pending", data: counted_schools["pending"] },
    ]
  end

  private

  def activity_chart_data(types, group_type, range, where_filter = nil)
    chart_data = []
    types.each do |type|
      case type
      when "Applications"
        data = Questionnaire.send("group_by_#{group_type}", :created_at, range: range)
      when "Home Applications"
        data = Questionnaire.joins(:school).where("schools.is_home = true").send("group_by_#{group_type}", :created_at, range: range)
      when "Away Applications"
        data = Questionnaire.joins(:school).where("schools.is_home != true").send("group_by_#{group_type}", :created_at, range: range)
      when "Confirmations"
        data = Questionnaire.where(acc_status: "rsvp_confirmed").send("group_by_#{group_type}", :acc_status_date, range: range)
      when "Denials"
        data = Questionnaire.where(acc_status: "rsvp_denied").send("group_by_#{group_type}", :acc_status_date, range: range)
      when "Incomplete Applications"
        data = User.without_questionnaire.send("group_by_#{group_type}", "users.created_at", range: range)
      when "Checked In"
        data = Questionnaire.where("checked_in_at > 0").send("group_by_#{group_type}", :checked_in_at, range: range)
      when "Boarded Bus"
        data = Questionnaire.where("boarded_bus_at > 0").send("group_by_#{group_type}", :boarded_bus_at, range: range)
      end
      data = data.where(where_filter) if where_filter && type != "Incomplete Applications"
      chart_data << { name: type, data: data.count }
    end
    chart_data
  end
end
