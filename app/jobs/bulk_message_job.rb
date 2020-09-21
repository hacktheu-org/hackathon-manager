class BulkMessageJob < ApplicationJob
  queue_as :default

  def perform(message)
    return unless message.status == "queued"

    message.update_attribute(:started_at, Time.now)

    recipients = self.class.build_recipients(message.recipients)

    recipients.each do |recipient|
      UserMailer.bulk_message_email(message.id, recipient).deliver_later
    end

    message.update_attribute(:delivered_at, Time.now)
  end

  def self.build_recipients(recipient_types)
    recipients = Set.new
    recipient_types.each do |type|
      recipients += user_ids(type)
    end
    recipients
  end

  # rubocop:disable CyclomaticComplexity
  def self.user_ids(type)
    case type
    when "all"
      # Everyone, including organizers that completed a questionnaire
      User.non_organizer.pluck(:id) + Questionnaire.pluck(:user_id)
    when "incomplete"
      # Incomplete applications, excluding organizers that don't have a questionnaire
      User.non_organizer.pluck(:id) - Questionnaire.pluck(:user_id)
    when "complete"
      Questionnaire.pluck(:user_id)
    when "accepted"
      Questionnaire.where(acc_status: "accepted").pluck(:user_id)
    when "denied"
      Questionnaire.where(acc_status: "denied").pluck(:user_id)
    when "waitlisted"
      Questionnaire.where(acc_status: "waitlist").pluck(:user_id)
    when "late-waitlisted"
      Questionnaire.where(acc_status: "late_waitlist").pluck(:user_id)
    when "rsvp-confirmed"
      Questionnaire.where(acc_status: "rsvp_confirmed").pluck(:user_id)
    when "rsvp-denied"
      Questionnaire.where(acc_status: "rsvp_denied").pluck(:user_id)
    when "checked-in"
      Questionnaire.where("checked_in_at IS NOT NULL").pluck(:user_id)
    when "non-checked-in"
      Questionnaire.where("(acc_status = 'accepted' OR acc_status = 'rsvp_confirmed' OR acc_status = 'rsvp_denied') AND checked_in_at IS NULL").pluck(:user_id)
    when "non-checked-in-excluding"
      Questionnaire.where("acc_status != 'accepted' AND acc_status != 'rsvp_confirmed' AND acc_status != 'rsvp_denied' AND checked_in_at IS NULL").pluck(:user_id)
    when /(.*)::(\d*)/
      user_ids_from_query(type)
    else
      raise "Unknown recipient type: #{type.inspect}"
    end
  end
  # rubocop:enable CyclomaticComplexity

  def self.user_ids_from_query(type)
    # Parse the query
    # See app/models/message_recipient_query.rb for how this works
    recipient_query = MessageRecipientQuery.parse(type)
    model = recipient_query.model

    # Build the recipients query
    case recipient_query.type
    when "bus-list"
      model.passengers.pluck(:user_id)
    when "school"
      Questionnaire.where("school_id = ? AND (acc_status = 'rsvp_confirmed' OR acc_status = 'accepted')", model.id).pluck(:user_id)
    when "blazer"
      result = Blazer::RunStatement.new.perform(Blazer.data_sources[model.data_source], model.statement)
      user_id_column = result.columns.index("user_id")
      raise "Blazer query is missing required \"user_id\" column" unless user_id_column.present?

      result.rows.map { |row| row[user_id_column] }
    else
      raise "Unknown recipient query type: #{recipient_query.type.inspect} (in message recipient query: #{type.inspect}"
    end
  end
end
