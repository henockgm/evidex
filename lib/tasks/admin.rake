namespace :evidex do
  namespace :admin do
    # Admin rights are granted only here (or in the console), never through the API.
    # In production: bin/kamal app exec 'bin/rails "evidex:admin:grant[me@example.com]"'
    desc "Make the user with this email an admin"
    task :grant, [ :email ] => :environment do |_task, args|
      user = User.find_by!(email_address: User.normalize_value_for(:email_address, args.fetch(:email)))
      user.update!(admin: true)
      puts "#{user.email_address} is now an admin." \
        "#{' They need two-factor sign-in turned on before they can use the admin area.' unless user.two_factor_enabled?}"
    end

    desc "Take admin rights away from the user with this email"
    task :revoke, [ :email ] => :environment do |_task, args|
      user = User.find_by!(email_address: User.normalize_value_for(:email_address, args.fetch(:email)))
      user.update!(admin: false)
      puts "#{user.email_address} is no longer an admin."
    end

    desc "List admins"
    task list: :environment do
      admins = User.where(admin: true).order(:email_address)
      puts admins.any? ? admins.map(&:email_address) : "No admins."
    end
  end
end
