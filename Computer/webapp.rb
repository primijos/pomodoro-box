#!/usr/bin/env ruby
# coding: utf-8

require 'bundler'
Bundler.require

$box_info={status: :unknown, time: 0}
$box_request=nil

$theme_names = %w|Tecnologia Matemàtiques Català Robòtica Biologia|
$theme_codes = %w|tec mat cat rob bio|
$all_themes=[]
$code_to_name={}

$theme_names.zip($theme_codes).each{|tt|
  $code_to_name[tt[1]] = tt[0]
  $all_themes << {
    name: tt[0],
    code: tt[1]
  }
}

def loren_ipsum name, howmany
  "Loren ipsum blabla del tema #{name}. " * howmany
end

def build_theme theme_code
  theme_name = $code_to_name[theme_code]
  content = ["<h2>Tema de #{theme_name}</h2>"]
  10.times{|p|
    content << "<h3>Subtema #{p} de #{theme_name}</h3>"
    li = loren_ipsum(theme_name.downcase,rand(5)+5)
    content << "<p>#{li}</p>"
  }
  [theme_name,content.join]
end


debug_enabled = false

if !debug_enabled
	def read_tty_line tty
	  retry_read = true
	  l = nil
	  while retry_read
	    l = tty.readline.chomp
	    puts "Read |#{l}|"
	    if l == ""
	      # pass
	    elsif l =~ /^echo: /
	      puts l
	      # pass
	    else
	      retry_read = false
	    end
	  end
	  return l
	end
	
	Thread.new do
	  while true
	    begin
	      res = system("stty -F /dev/ttyACM0 cs8 115200 ignbrk -brkint -icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke noflsh -ixon -crtscts")
	      if res.nil? or !res
	        puts "Error calling stty #{res}"
	        raise Errno::EIO
	      end
	      File.open("/dev/ttyACM0","r+"){|tty|
	        while true
	          puts "="*80
	          if not $box_request.nil?
	            status = $box_request[:status]
	            time = $box_request[:time]
	            tty.puts "#{status} #{time}"
	            #sleep 1
	            $box_request = nil
	          end
	          tty.puts "status"
	          l = read_tty_line tty
	          puts "Received |#{l}|"
            status,time,last_command = $1.to_sym,$2 if l =~ /status: (.+) (\d+).*/
	          time = time.to_i
	          if status.nil? or time.nil?
	            $box_info={status: :unknown, time: 0, last_command: :unknown}
	          else
	            $box_info={status: status, time: time, last_command: last_command}
	          end
	          puts $box_info.inspect
	          #sleep 0.5
	        end
	      }
	    rescue Errno::EIO
	      $box_info={status: :unknown, time: 0, last_command: :unknown}
	    rescue Errno::ENOENT
	      $box_info={status: :unknown, time: 0, last_command: :unknown}
	    rescue EOFError
	      $box_info={status: :unknown, time: 0, last_command: :unknown}
	    rescue Exception => e
	      puts e
	      $box_info={status: :unknown, time: 0, last_command: :unknown}
	    ensure
	      puts "Caught error ============="
	      puts $box_info.inspect
	      sleep 1
	    end
	  end
	end
end


if debug_enabled

$debug_box_info={status: :open, time: 0, closed_at: nil}

  def box_status
    tmp_status = $debug_box_info.clone
    if tmp_status[:status] == :closed
      now = Time.now
      t = now - tmp_status[:closed_at]
      t = t * 1000
      r = tmp_status[:time] - t
      if r > 0
        tmp_status[:time]=r
      else
        $debug_box_info=tmp_status={status: :open, time: 0, closed_at: nil}
      end
    end
    tmp_status
  end

  def close_box total
    puts "Sleeping box for #{total} seconds"
    now = Time.now
    $debug_box_info={status: :closed, time: total * 1000, closed_at: now}
  end

  def open_box
    puts "Opening box"
    $debug_box_info={status: :open, time: 0, closed_at: nil}
  end

else

  def box_status
    $box_info
  end

  def close_box total
    puts "Sleeping box for #{total} seconds"
    $box_request = {status: :close, time: total}
    while !$box_request.nil?
      sleep 0.2
    end
  end
  
  def open_box
    puts "Opening box"
    $box_request = {status: :open, time: 0}
    while !$box_request.nil?
      sleep 0.2
    end
  end

end

def build_questions theme_code
  num_questions=10
  num_answers=4
  theme_name = $code_to_name[theme_code]
  rgen = Random.new(theme_name.sum)
  questions = []
  num_questions.times{|i|
    correct = rgen.rand num_answers
    question = "Aquesta és la pregunta #{i} sobre el tema: #{theme_name}. Selecciona la resposta correcta:"
    responses = []
    num_answers.times{|j|
      responses << {text: "Resposta #{j} a la pregunta #{i}.", good: j==correct, status: "", checked: ""}
    }
    questions << {text: question, responses: responses}
  }
  questions
end

def read_questions theme
  questions = []
  current_r = ""
  File.readlines("questions/#{theme}.txt").each{|l|
    if l =~ /^$/
      next
    elsif l =~ /(R|r):(.+)/
      response = {text: $2, good: $1=="r", status: "", checked: ""}
      questions[-1][:responses] << response
    elsif l =~ /P:(.+)/
      questions << {text: $1, responses: []}
    else
      tmp = questions[-1][:responses][-1][:text]
      questions[-1][:responses][-1][:text] = tmp + l
    end
  }
  questions.each{|q|
    c = 0
    q[:responses].each{|response|
      if response[:good]
        c+=1
      end
    }
    raise "Bad resonses at #{theme}" if c!=1
  }
  questions
end

configure do
  set :port, 1234
  enable :sessions
  set :session_secret, "abcde"
  set :static, true
  set :public_folder, "public"
end

get "/" do
  @themes = $all_themes
  erb :home
end

get "/theme/:tema" do |tema|
  session[:theme] = tema
  redirect "/time"
  erb :time
end

get "/time" do
  puts "In time with #{session[:theme]}"
  erb :time
end

post "/time" do
  # TODO check time
  [:study,:limit].each{|prefix|
    h_key = "#{prefix}_hours".to_sym
    m_key = "#{prefix}_minutes".to_sym
    s_key = "#{prefix}_seconds".to_sym
    t_key = "#{prefix}_time".to_sym
    hours = params[h_key]
    minutes = params[m_key]
    seconds = params[s_key]
    t="#{hours}:#{minutes}:#{seconds}"
    session[t_key] = t
    puts "In time (post) with #{prefix} #{session[t_key]} t=#{t}"
  }
  session[:percent] = params[:percent]
  puts "In time (post) with percent #{session[:percent]}"
  redirect "/prepare"
end

def to_time_str t
  t.split(":").map{|x| x.to_s}.zip(["h","m","s"]).map{|x| x.join}.join(":")
end

get "/prepare" do
  ts = session[:study_time]
  tl = session[:limit_time]
  @study_time_str = to_time_str ts
  @limit_time_str = to_time_str tl
  @percent = session[:percent]
  erb :prepare
end

def to_secs t
  h,m,s = t.split(":").map{|x| x.to_i}
  m=m*60
  h=h*3600
  total = h+m+s
  total
end

post "/prepare" do
  total = to_secs session[:limit_time]
  close_box(total)
  now = Time.now
  lt = now + total
  ld = lt.strftime "%Y/%m/%d %H:%M:%S"
  session[:limit_date]=ld

  total = to_secs session[:study_time]
  st = now + total
  sd = st.strftime "%Y/%m/%d %H:%M:%S"
  session[:study_date]=sd

  redirect "/study"
end

def to_date str
end

get "/study" do
  @study_date = session[:study_date]
  @limit_date = session[:limit_date]
  puts "Session: #{session.inspect}"
  puts "Study date: #{@study_date}"
  @theme=session[:theme]
  @theme_name, @theme_content = build_theme @theme
  erb :study
end

post "/study" do
  @study_date = session[:study_date]
  @limit_date = session[:limit_date]
  redirect "/eval"
end

get "/eval" do
  @study_date = session[:study_date]
  @limit_date = session[:limit_date]
  @show_results = false
  @theme=session[:theme]
  #@questions = read_questions @theme
  @questions = build_questions @theme
  erb :eval
end

post "/eval" do
  @study_date = session[:study_date]
  @limit_date = session[:limit_date]
  puts ">>"*20
  puts params.inspect
  @show_results = true
  ok = 0
  ko = 0
  @theme=session[:theme]
  #@questions = read_questions @theme
  @questions = build_questions @theme
  @questions.each_with_index{|question,qidx|
    response = params["question_#{qidx}"]
    question[:status] = :ko
    if response.nil?
      ko += 1
    else
      response = response.to_i
      question[:responses][response][:checked] = "checked"
      if question[:responses][response][:good]
        question[:responses][response][:status] = :ok
        question[:status] = :ok
        ok += 1
      else
        question[:responses][response][:status] = :ko
        ko += 1
      end
    end
  }
  total = ok+ko
  @pct = (((ok*1.0)/total)*100).round(2)
  @percent = session[:percent].to_i
  erb :eval
end

get "/box-status" do
  statuses = {
    open: "oberta",
    closed: "tancada",
    unknown: "??",

  }
  val = statuses[box_status[:status]]
  puts "Returning #{val}"
  content_type :json
  {status: val}.to_json
end

get "/open-box" do
  open_box
  redirect "/"
end

get "/debug" do
  @status = box_status
  erb :debug
end

get "/debug-close-box" do
  close_box 30
  @status = box_status
  erb :debug
end

get "/debug-open-box" do
  open_box
  @status = box_status
  erb :debug
end

get "/debug-box-status" do
  @status = box_status
  erb :debug
end
