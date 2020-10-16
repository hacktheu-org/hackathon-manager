FactoryBot.define do
  factory :questionnaire do
    phone { "(123) 456-7890" }
    international { false }
    date_of_birth { Date.today - 20.years }
    experience { "first" }
    interest { "software" }
    school_id { create(:school).id }
    shirt_size { "Unisex - M" }
    dietary_restrictions { "" }
    special_needs { "" }
    agreement_accepted { true }
    code_of_conduct_accepted { true }
    data_sharing_accepted { true }
    can_share_info { true }
    gender { "Male" }
    major { "Computer Science" }
    level_of_study { "University (Undergraduate)" }
    graduation_semester { "Summer " + Date.today.year.to_s }
    race_ethnicity { "Other" }
    why_attend { "This sounds cool" }

    association :user
  end
end
