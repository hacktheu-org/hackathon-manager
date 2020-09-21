class ChangeGradYearToGradSemester < ActiveRecord::Migration[5.2]
  def change
    remove_column :questionnaires, :graduation_year
    add_column    :questionnaires, :graduation_semester, :string
  end
end
