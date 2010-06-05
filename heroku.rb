load File.join(File.dirname(root), File.dirname(template), "template_helpers.rb")

staff = ["bjeanes@mocra.com", "chendo@mocra.com", "odindutton@gmail.com", 
  "scottandrewharvey@gmail.com", "mark@mocra.com"]
  
file ".slugignore", <<-EOS.gsub(/^  /, '')
  *.psd
  *.pdf
  test
  spec
  features
  doc
  docs
EOS
git :add => '.'
git :commit => "-a -m 'Add heroku .slugignore'"
heroku_user = highline.ask("Heroku User?  ") { |q| q.default = default_heroku_user if default_heroku_user }
if heroku_user != default_heroku_user
  heroku_password = highline.ask("Heroku Password (for #{heroku_user})?   ") { |q| q.echo = false }
end

heroku :create, app_subdomain
if heroku_user != default_heroku_user
  heroku :"sharing:add", heroku_user
  heroku :"sharing:transfer", heroku_user
  git :config => "--add heroku.email #{heroku_user}"
  git :config => "--add heroku.password '#{heroku_password}'"
end
heroku :"addons:add", "custom_domains:basic"
heroku :"addons:add", "exceptional:basic"
heroku :"addons:add", "newrelic:bronze"
heroku :"addons:add", "cron:daily"
if highline.agree "Add all Mocra staff?  "
  staff.each do |user|
    heroku :"sharing:add", user
  end
end
git :push => "heroku master"
heroku :rake, "db:migrate"
heroku :open

# Success!
log "SUCCESS! Your app is running at http://#{app_url}"
