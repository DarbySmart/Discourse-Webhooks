# name: notifications_webhooks
# about: Make HTTP requests when user has new notification
# version: 0.1
# authors: Karl Mendes
# url: https://github.com/DarbySmart/Discourse-Webhooks

after_initialize do
  add_model_callback :notification, :after_create do
    return unless SiteSetting.webhooks_enabled

    params = {}

    if SiteSetting.webhooks_include_api_key
      api_key = ApiKey.find_by(user_id: nil)
      if not api_key
        Rails.logger.warn('Webhooks configured to include the "All User" API key, but it does not exist.')
      else
        params[:api_key] = api_key.key
      end
    end

    user = self.user
    params[:user_id] = user.external_id
    params[:unread_notifications] = user.total_unread_notifications

    uri = URI.parse(SiteSetting.webhooks_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless SiteSetting.webhooks_verify_ssl

    request = Net::HTTP::Post.new(uri.path)
    request.add_field('Content-Type', 'application/json')
    request.body = params.to_json

    response = http.request(request)
    case response
    when Net::HTTPSuccess then
      # nothing
    else
      Rails.logger.error("#{uri}: #{response.code} - #{response.message}")
    end
  end
end
