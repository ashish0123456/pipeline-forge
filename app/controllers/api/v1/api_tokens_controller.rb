module Api
  module V1
    class ApiTokensController < BaseController
      def create
        token = ApiToken.issue!(current_user, name: params.require(:name), expires_at: expires_at)
        render json: { data: { id: token.id, name: token.name, token: token.raw_token, expires_at: token.expires_at } }, status: :created
      end

      private

      def expires_at
        return if params[:expires_at].blank?

        parsed = Time.zone.parse(params[:expires_at].to_s)
        raise ActionController::BadRequest, "expires_at must be a valid timestamp" unless parsed

        parsed
      end
    end
  end
end
