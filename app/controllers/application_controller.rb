# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  helper_method :current_store

  before_action :authenticate_user!

  def current_store
    @current_store ||= begin
      if params[:store_id]
        Store.find(params[:store_id])

      elsif params[:article_id]
        Article.find(params[:article_id]).store

      elsif params[:aisle_id]
        Aisle.find(params[:aisle_id]).pair.store

      elsif params[:section_id]
        Section.find(params[:section_id]).aisle.pair.store

      elsif params[:id]
        case controller_name
        when "aisles"
          Aisle.find(params[:id]).pair.store
        when "sections"
          Section.find(params[:id]).aisle.pair.store
        when "articles"
          Article.find(params[:id]).store
        end
      end
    end
  end
end

