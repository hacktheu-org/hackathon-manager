class ChangeShareInfoDefault < ActiveRecord::Migration[5.2]
  def change
    change_column_default :questionnaires, :can_share_info, from: false, to: true
  end
end
