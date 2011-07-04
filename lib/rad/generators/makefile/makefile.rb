require 'erb'
require 'yaml'

class Makefile
  class << self
    
    # build the sketch Makefile for the given template based on the values in its software and hardware config files
    def compose_for_sketch(build_dir)
      params = hardware_params.merge software_params
      params['serial_port'] = serial_port if params['serial_port'] == "/dev/tty.usbserial*"
      if @software_params['experimental'] == true
        @experimental_mode = true
        puts "#################################### running in experimental mode"
        if @software_params['arduino_root'] == "/Applications/arduino-0015"
          @software_params['arduino_root'] = "/Applications/Arduino.app/Contents/Resources/Java"
        end
        board_config = board_configuration(@software_params['arduino_root'], @hardware_params['mcu'], "/arduino")
      else
        board_config = board_configuration(@software_params['arduino_root'], @hardware_params['mcu'], "")
      end
      params = params.merge board_config
      params['target'] = build_dir.split("/").last
           
      params['libraries_root'] = "#{File.expand_path(RAD_ROOT)}/vendor/libraries"
      params['libraries'] = $load_libraries # load only libraries used 
      
      # needed along with ugly hack of including another copy of twi.h in wire, when using the Wire.h library
      params['twi_c'] = $load_libraries.include?("Wire") ? "#{params['arduino_root']}/hardware/libraries/Wire/utility/twi.c" : "" 
      
      params['asm_files'] = Dir.entries( File.expand_path(RAD_ROOT) + "/" + PROJECT_DIR_NAME ).select{|e| e =~ /\.S/}            
            
      e = ERB.new File.read("#{File.dirname(__FILE__)}/#{"better_" if @experimental_mode == true}makefile.erb")
      
      File.open("#{build_dir}/Makefile", "w") do |f|
        f << e.result(binding)
      end
    end
        
    def hardware_params
      return @hardware_params if @hardware_params
      return @hardware_params = YAML.load_file( "#{RAD_ROOT}/config/hardware.yml")
    end
      
    def software_params
      return @software_params if @software_params
      return @software_params = YAML.load_file( "#{RAD_ROOT}/config/software.yml" )
    end
    
    def serial_port     
      usb = Dir.glob("/dev/tty.usbserial*")
      if usb.empty?
        usb = Dir.glob("/dev/tty.usbmodem*") #uno shows up as usbmodem on OS X...
      end
      puts "#################################### serial port: #{usb}"
      usb
    end
    
    ## match the mcu with the proper board configuration from the arduino board.txt file
    def board_configuration(arduino_root, board_name, path_mod)
      board_configuration = {}
      board_type = {}
      puts "#################################### checking boards.txt at: #{arduino_root}/hardware#{path_mod}/boards.txt for: #{board_name}"
      File.open("#{arduino_root}/hardware#{path_mod}/boards.txt", "r") do |infile|
      	infile.each_line do |line|
          next unless line.chomp =~ /^#{board_name}\.([^=]*)=(.*)$/
          # next unless line.chomp =~ /^(#{board_name})\.name/
          board_configuration[$1] = $2
          # board_configuration = $1
      	end
      end
      board_type['build.board_designation'] = board_name
      if board_configuration.empty?
        raise "#################################### no board configuration found for : #{board_name} check your hardware configuration -- type rake arduino:boards"
      else
        puts "#################################### board_configuration (per boards.txt): #{board_configuration.inspect}"
      end
      board_configuration = board_configuration.merge board_type
      board_configuration
    end
      
  end
end