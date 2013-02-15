require 'bundler/capistrano'
set :application, "blink.cancer.northwestern.edu"
set :repository,  "code.nubic.northwestern.edu/git/coblink.git"

set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :user, 'edc236'
set :use_sudo, false
# set :deploy_to, "where dong wants to put it"
set :deploy_via, :remote_cache

role :web, "blink.cancer.northwestern.edu"                          # Your HTTP server, Apache/etc
role :app, "blink.cancer.northwestern.edu"                          # This may be the same as your `Web` server
role :db,  "blink.cancer.northwestern.edu", :primary => true # This is where Rails migrations will run

# if you want to clean up old releases on each deploy uncomment this:
# after "deploy:restart", "deploy:cleanup"

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

 If you are using Passenger mod_rails uncomment this:
 namespace :deploy do
   task :start do ; end
   task :stop do ; end
   task :restart, :roles => :app, :except => { :no_release => true } do
     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
   end
 end
