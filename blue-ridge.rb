load File.join(File.dirname(root), File.dirname(template), "template_helpers.rb")

plugin 'blue_ridge', :git => 'git://github.com/drnic/blue-ridge.git'
generate "blue_ridge"
