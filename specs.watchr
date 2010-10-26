def growl(title, msg, img)
  %x{growlnotify -m #{ msg.inspect} -t #{title.inspect} --image ~/.watchr/#{img}.png}
end

def form_growl_message(str)
  results = str.split("\n").last
  if results =~ /[1-9]\s(failure|error)s?/
    growl "Test Results", "#{results}", "fail"
  elsif results != ""
    growl "Test Results", "#{results}", "pass"
  end
end

def run(cmd)
  puts(cmd)
  output = ""
  IO.popen(cmd) do |com|
    com.each_char do |c|
      print c
      output << c
      $stdout.flush
    end
  end
  form_growl_message output
end

def run_test_file(file)
  run %Q(ruby -I"lib:test" -rubygems #{file})
end

def run_all_tests
  run "rake test"
end

def related_test_files(path)
  puts File.basename(path).split(".").first
  Dir['test/*.rb'].select { |file| file =~ /#{File.basename(path).split(".").first}_test/ }
end

watch('lib/.*.rb') { system('clear'); run_all_tests }
watch('test/helper\.rb')  { system('clear'); run_all_tests }
watch('test/.*test\.rb') { |m| system('clear'); run_test_file(m[0]) }
# watch('lib/.*')             { |m| related_test_files(m[0]).each { |file| run_test_file(file) } }

# Ctrl-\
Signal.trap('QUIT') do
  puts " --- Running all tests ---\n\n"
  run_all_tests
end

# Ctrl-C
Signal.trap('INT') { abort("\n") }
puts "BOO"