class AddShippingAddressToQuestionnaires < ActiveRecord::Migration[5.2]
  def change
    add_column :questionnaires, :shipping_address, :string
  end
end
