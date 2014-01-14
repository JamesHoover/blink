class Blink < Sinatra::Application

  # View jobs dashboard
  get '/jobs' do
    @working_jobs  = Resque.working.map{|j| Resque::Plugins::Status::Hash.get(j.job['payload']['args'].shift)}
    @queued_jobs   = Resque.peek('statused', 1, 20).map{|j| Resque::Plugins::Status::Hash.get(j['args'].shift)}

    respond_to do |wants|
      wants.html { haml :jobs, :locals => {:resque => Resque} }
    end
  end

  # Submit a new job
  post '/jobs' do

    # Load job specification
    job_spec = YAML::load(File.open(params['job']))

    # Load dependencies
    job_spec[:libs].each do |lib|
      require "./lib/#{lib}"
    end

    # Execute Job
    instance_eval(job_spec[:exec]) if job_spec[:exec]

    redirect to('/jobs')
  end

  get '/jobs/:id' do

    @job = Resque::Plugins::Status::Hash.get(params[:id])

    respond_to do |wants|
      wants.html { haml :job }
    end
  end

  # Specific SSE subscription endpoint
  get '/jobs/watch/:id', provides: 'text/event-stream' do

    job = Resque::Plugins::Status::Hash.get(params[:id])
    if job
      stream :keep_open do |out|
        loop do
          unless out.closed?
            job = Resque::Plugins::Status::Hash.get(params[:id])
            out << "data: #{job.pct_complete}\n\n"
          else
            break
          end
          sleep 1
        end
      end
    else
      out << "error: \"Job not found\""
    end

  end
end
