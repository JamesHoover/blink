web: bundle exec thin -R config.ru -p $PORT start
resque: env TERM_CHILD=1 COUNT=3 QUEUE=* bundle exec rake resque:workers
