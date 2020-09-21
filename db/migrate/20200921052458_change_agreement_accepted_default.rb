class ChangeAgreementAcceptedDefault < ActiveRecord::Migration[5.2]
  def change
    change_column_default :questionnaires, :agreement_accepted, from: false, to: true
  end
end
