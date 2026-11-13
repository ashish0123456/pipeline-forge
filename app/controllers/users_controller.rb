class UserController < ApplicationController

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to root_path, notice: "Account Created!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private 

  def user_params
  end
end