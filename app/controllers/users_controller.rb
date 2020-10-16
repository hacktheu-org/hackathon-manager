class UsersController < ApplicationController
  before_action :logged_in
  respond_to :json

  def logged_in
    authenticate_user!
  end

  def show
    respond_to do |format|
      # format.json { render json: current_user }
      j = current_user.as_json
      j[:name]     = current_user.first_name + " " + current_user.last_name
      format.json { render json: j }
    end
  end
end
