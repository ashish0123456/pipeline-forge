module Api
  module V1
    class BaseController < ApplicationController
      skip_forgery_protection

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Resource not found" }, status: :not_found
      end

      rescue_from ActionController::ParameterMissing do |error|
        render json: { error: error.message }, status: :bad_request
      end

      rescue_from ActionController::BadRequest do |error|
        render json: { error: error.message }, status: :bad_request
      end

      private

      def page
        [ params.fetch(:page, 1).to_i, 1 ].max
      end

      def per_page
        [ [ params.fetch(:per_page, 25).to_i, 1 ].max, 100 ].min
      end

      def pagination(collection)
        { page: page, per_page: per_page, total: collection.count }
      end
    end
  end
end
