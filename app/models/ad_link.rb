# The comparable form of a job ad's link, used to spot a posting saved twice.
# Two links to the same ad usually differ only in case, a trailing slash, a
# #fragment or tracking parameters added by the site that shared them, so those
# are dropped. Parameters that pick the job (Ashby's ashby_jid, say) are kept.
module AdLink
  TRACKING_PARAMS = %w[
    gclid gbraid wbraid dclid fbclid msclkid yclid igshid mc_cid mc_eid _hsenc _hsmi
    feedid trk trackingid refid
  ].to_set.freeze

  def self.normalize(url)
    return nil if url.blank?

    uri = URI.parse(url.strip)
    return nil unless uri.is_a?(URI::HTTP) && uri.host.present?

    scheme = uri.scheme.downcase
    port = uri.port == uri.default_port ? "" : ":#{uri.port}"
    path = uri.path.delete_suffix("/")
    query = uri.query && comparable_query(uri.query)
    "#{scheme}://#{uri.host.downcase}#{port}#{path}#{"?#{query}" if query.present?}"
  rescue URI::InvalidURIError
    nil
  end

  def self.comparable_query(query)
    params = URI.decode_www_form(query).reject { |name, _| tracking?(name) }
    URI.encode_www_form(params.sort)
  rescue ArgumentError
    query
  end
  private_class_method :comparable_query

  def self.tracking?(name)
    name = name.downcase
    name.start_with?("utm_") || TRACKING_PARAMS.include?(name)
  end
  private_class_method :tracking?
end
