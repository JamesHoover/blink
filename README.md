blink
=====

THIS IS CURRENTLY ALPHA SOFTWARE;  YE BE WARNED

BLINK is meant to be an easy to use, web based interface for visualizing data out of the IMS Biospecimen Inventory System&copy;

BLINK is a ruby/sinatra application that is meant to sit on top of ElasticSearch.  Currently it is setup to look for data in an index named bsi and expects 2 types within that index, specimen and subject.  This specific configuration is simply the current state of the system which would likely change (if I had the time...) for a production version.

Screen shots are available http://imgur.com/a/2QPFr

A test dataset is included.  To install test data, make sure elasticsearch is up and running on port 9200 and run:

```bash
ruby init_db.rb
```

