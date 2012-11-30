require 'fileutils'

# Handles the files supplied at the CLI. 
class FileHandler 
	attr_accessor :files
	attr_accessor :metas
	attr_accessor :meta_ext

	def initialize
		@files = []
		@metas = []
		@meta_ext = "-meta.xml"
	end

	# Checks if the files exist and if 
	# they have associated metadata files
	def build_deploy_package(file_names)
		file_names.each do |file_name|
			if File.exists?(file_name)
				@files << file_name
				if File.exists?(file_name + @meta_ext)
					@metas << file_name + @meta_ext
				end
			end
		end

		if !@files.empty?
			p = Package.new
			p.build(@files, @metas)	
		end
	end
end

class Package
	attr_accessor :xml_body1
	attr_accessor :xml_body2	
	attr_accessor :xml	
	attr_accessor :api_version
	attr_accessor :xml_type
	attr_accessor :package
	attr_accessor :dir_root
	attr_accessor :dir_root_pack
	attr_accessor :deploy_dir
	
	def initialize
		@dir_root = 'deploy'
		@dir_root_pack = 'pack'
		@package = 'package.xml'
		@api_version = '26.0'
		@xml = ''
		@xml_body1 = '<?xml version="1.0" encoding="UTF-8"?><Package 
					xmlns="http://soap.sforce.com/2006/04/metadata">'
		@xml_body2 = "<version>#{@api_version}</version></Package>"
		@xml_types = { 'cls' => '<types><members>*</members><name>ApexClass</name></types>',
					'page' => '<types><members>*</members><name>ApexPage</name></types>',	
					'trigger' => '<types><members>*</members><name>ApexTrigger</name></types>' }
	end

	def build(file_names, meta_names)
	
		FileUtils.remove_dir(@deploy_dir, true)

		types = []
		file_names.each do |file_name|
			parts = file_name.split('.')
			if !types.include? @xml_types[parts.last]
				types << @xml_types[parts.last]		
			end
		end
	
		@xml << @xml_body1
		if !types.empty?
			types.each { |t| @xml << t }	
		end 
		@xml << @xml_body2

		# Create dir struct
		@deploy_dir = self.create_deploy_dir

		# Create package.xml
		Dir.mkdir(@deploy_dir + @dir_root_pack + File::SEPARATOR, 0777) 
		File.open(@deploy_dir + @dir_root_pack + File::SEPARATOR +  @package, 'w:UTF-8') { |f| f.write(@xml) }
	
		# Populate deployment pack
		self.add_files_to_deploy_dir(@deploy_dir + @dir_root_pack + File::SEPARATOR, file_names, meta_names)

		# Zip it
		system("cd #{@deploy_dir}#{@dir_root_pack} && zip -r pack.zip . && mv pack.zip ..#{File::SEPARATOR}pack.zip")

		@deploy_dir
	end

	def create_deploy_dir
		path = File.join(Dir.home, @dir_root)
		if Dir.exists?(path)
			FileUtils.remove_dir(path, true)
		end
		Dir.mkdir(path, 0777)
		path + File::SEPARATOR
	end

	def add_files_to_deploy_dir(deploy_dir, file_names, meta_names)
		(file_names + meta_names).each do |file_name|
			con = IO.read(file_name)	
			parts = file_name.split(File::SEPARATOR)
			
			# Get file ext
			ext = ""
			if parts.last.include?("-meta.xml")
				ext = (parts.last.split('-')).first.split('.').last
			else
				ext = parts.last.split('.').last
			end

			# Get pack dir struct name
			if ext == "cls"
				dir_name = "classes"
			elsif ext == "trigger"
				dir_name = "triggers"
			elsif ext == "page"
				dir_name = "pages"
			else
				return
			end

			# Create dir
			if !Dir.exists?(deploy_dir + dir_name)
				Dir.mkdir(deploy_dir + dir_name, 0777)
			end

			# Write file
			File.open(deploy_dir + dir_name + File::SEPARATOR + parts.last, 'w:UTF-8') { |f| f.write(con) }
		end	
	end
end

class Deploy
	attr_accessor :xml_ant_build
	attr_accessor :deploy_dir
	attr_accessor :build_file

	def initialize(deploy_dir)
		@deploy_dir = deploy_dir
		@build_file = 'build.xml'	
		@xml_ant_build = '<project name="Quick Code Deploy" default="deployUnpackaged" basedir="." xmlns:sf="antlib:com.salesforce">
						<property file="/etc/sf_deploy/build.properties"/>
						<property environment="env"/>
						<target name="deployUnpackaged">
						<sf:deploy username="${sf.username}" 
						password="${sf.password}" 
						serverurl="${sf.serverurl}" 
						zipFile="pack.zip"/>
						</target>
						</project>'
	end

	def create_build_file
		if File.exists?(@deploy_dir + @build_file)
			File.delete(@deploy_dir + @build_file)
		end

		File.open(@deploy_dir + @build_file, 'w:UTF-8') { |f| f.write(@xml_ant_build) } 	
	end

	def deploy_to_sf
		self.create_build_file
		system("cd #{@deploy_dir} && ant")
	end
end

# Deploy 
file_handler = FileHandler.new
deploy_dir = file_handler.build_deploy_package ARGV	
deployer = Deploy.new(deploy_dir)
deployer.deploy_to_sf
FileUtils.remove_dir(deploy_dir, true)