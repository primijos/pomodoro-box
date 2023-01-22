#!/usr/bin/env ruby
# coding: utf-8

require 'bundler'
Bundler.require

$box_info={status: :unknown, time: 0}
$box_request=nil

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
          if not $box_request.nil?
            status = $box_request[:status]
            time = $box_request[:time]
            tty.puts "#{status} #{time}"
            sleep 0.5
            $box_request = nil
          end
          tty.puts "status"
          l = tty.readline
          status,time = $1,$2 if l =~ /status: (.+) (\d+)/
          time = time.to_i
          if status.nil? or time.nil?
            $box_info={status: :unknown, time: 0}
          else
            $box_info={status: status, time: time}
          end
          puts $box_info.inspect
          sleep 0.5
        end
      }
    rescue Errno::EIO
      $box_info={status: :unknown, time: 0}
    rescue Errno::ENOENT
      $box_info={status: :unknown, time: 0}
    rescue EOFError
      $box_info={status: :unknown, time: 0}
    rescue
      $box_info={status: :unknown, time: 0}
    ensure
      puts $box_info.inspect
      sleep 1
    end
  end
end

def close_box total
  puts "Sleeping box for #{total} seconds"
  $box_request = {status: :close, time: total}
  while !$box_request.nil?
    sleep 1
  end
end

def open_box
  puts "Opening box"
  $box_request = {status: :open, time: 0}
  while !$box_request.nil?
    sleep 1
  end
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
end

get "/" do
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
  redirect "/prepare"
end

get "/prepare" do
  erb :prepare
end

post "/prepare" do
  # TODO send close to box
  t = session[:limit_time]
  h,m,s = t.split(":").map{|x| x.to_i}
  m=m*60
  h=h*3600
  total = h+m+s
  close_box(total)
  redirect "/study"
end

get "/study" do
  @theme=session[:theme]
  erb :study
end

post "/study" do
  redirect "/eval"
end

get "/eval" do
  @show_results = false
  @theme=session[:theme]
  @questions = read_questions @theme
  erb :eval
end

post "/eval" do
  puts ">>"*20
  puts params.inspect
  @show_results = true
  ok = 0
  ko = 0
  @theme=session[:theme]
  @questions = read_questions @theme
  @questions.each_with_index{|question,qidx|
    response = params["question_#{qidx}"]
    if response.nil?
      response = response.to_i
      ko += 1
    else
      question[:responses][response][:checked] = "checked"
      if question[:responses][response][:good]
        question[:responses][response][:status] = :ok
        ok += 1
      else
        question[:responses][response][:status] = :ko
        ko += 1
      end
    end
  }
  total = ok+ko
  @pct = ((ok*1.0)/total).round(2)*10
  erb :eval
end

get "/debug" do
  erb :debug
end

get "/close-box" do
  close_box 30
  erb :debug
end

get "/open-box" do
  open_box
  erb :debug
end