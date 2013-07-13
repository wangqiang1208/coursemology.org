module TrainingSubmissionsHelper
  require 'open3'
  # To change this template use File | Settings | File Templates.
  @@path_temp_folder = "#{Rails.root}/paths/tmp/"
  def get_tmp_file_name
    rand_str = ''
    begin
      rand_str = (0...20).map{ ('a'..'z').to_a[rand(26)] }.join
      full_path = @@path_temp_folder + rand_str
    end while File.exist?(full_path)

    full_path
  end

  def get_code_to_write(included_code,code_to_run)
    code_to_write =
        "#################
# Include code  #
#################
"<< included_code << "
#################
#  student code #
#################
"<< code_to_run;

  end

  def eval_python(file_path,code, data)
    tests = {publicTests:data["publicTests"],
             privateTests:data["privateTests"]}
    timeLimit = data["timeLimitInSec"]
    memoryLimit = data["memoryLimitInMB"]
    FileUtils.mkdir_p(@@path_temp_folder) unless File.exist?(@@path_temp_folder)
    summary ={publicTests:[],privateTests:[],errors:[]}
    for i in 0..1
      file = File.open(file_path, 'w+')
      if file
        file.write(code)
        case i
          when 0
            test_type = tests[:publicTests]
          when 1
            test_type = tests[:privateTests]
        end
        test_code = ''
        test_type.each do |test|
          test_code << "\nprint(#{test["expression"]} == #{test["expected"]})\n"
        end
        file.write(test_code)
        file.close

        #stdout,stderr,status = Open3.capture3("time python3 #{file_path}")
        #puts "out: ", stdout
        #puts "err: ", stderr
        #puts "status: ", status
        #Open3.pipeline_start("python3 #{file_path}") {|ts|
        #  sleep 10
        #  t = ts[0]
        #  Process.kill("TERM", t.pid)
        #  p t.value #=> #<Process::Status: pid 911 SIGTERM (signal 15)>
        #}
        @stdin,@stdout,@stderr = Open3.popen3("python3 #{file_path}")
        errors = @stderr.readlines
        results = @stdout.readlines.map{|r| if r.gsub("\n",'') == "True" then true else false end}
        @stdin.close
        @stderr.close
        @stdout.close
        File.delete(file_path)

        test_type = if i == 0 then :publicTests else :privateTests end
        summary[test_type] = results
        #puts "error: ", errors
        if errors.length > 0
          error_message = errors.join.scan(/", line \d*.*\n.*\n/).map{ |m| m[3,m.length - 1]} << errors.last
          summary[:errors] = error_message.join
          break
        end

      end
    end
    #puts "summary", summary
    summary
  end
end
