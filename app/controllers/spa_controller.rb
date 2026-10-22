# Page URLs (/, /postings/7, /settings/security, …) get the built React app;
# React Router shows the right page. Its hashed /assets files are served as
# static files (see config/environments/production.rb).
class SpaController < ActionController::API
  def show
    index = Rails.configuration.x.spa_root.join("index.html")
    unless index.exist?
      return render plain: "The frontend isn't built. In development open http://localhost:5173; " \
        "for a production build run `npm run build` in frontend/.", status: :not_found
    end

    # Always check for a new index.html, so a deploy shows up straight away;
    # the hashed assets it points to are cached for a year.
    response.headers["cache-control"] = "no-cache"
    render plain: index.read, content_type: "text/html"
  end
end
