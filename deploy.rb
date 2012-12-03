require 'fileutils'

# Handles the files supplied at the CLI. 
class FileHandler 
	attr_accessor :files, :metas, :meta_ext

	def initialize
		@files = @metas = []
		@meta_ext = "-meta.xml"
	end

	# Checks if the files exist and if 
	# they have associated metadata files
	def build_deploy_package(file_names)
		file_names.each do |file_name|
			@files << file_name if File.exists? file_name
			metadata_file_name = file_name + @meta_ext
			@metas << metadata_file_name if File.exists? metadata_file_name
		end
		
		Package.build(@files, @metas) unless @files.empty?
	end
end

class Package
	attr_accessor :deploy_dir
	
	@dir_root      = 'deploy'
	@dir_root_pack = 'pack'
	@package       = 'package.xml'
	@api_version   = '26.0'
	@xml_body1     = '<?xml version="1.0" encoding="UTF-8"?><Package xmlns="http://soap.sforce.com/2006/04/metadata">'
	@xml_body2     = "<version>#{@api_version}</version></Package>"
	@xml_types     = { 
						'cls'     => '<types><members>*</members><name>ApexClass</name></types>',
						'page'    => '<types><members>*</members><name>ApexPage</name></types>',	
						'trigger' => '<types><members>*</members><name>ApexTrigger</name></types>' 
					}

	def self.build(file_names, meta_names)
		types = []
		file_names.each {|f_n| types << f_n.split('.').last}
		types = types.uniq #you almost never really want to use #Uniq! as it will return nil if no changes are made.
	
		@xml = @xml_body1
		types.each { |t| @xml << t } unless types.empty?
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

	def self.create_deploy_dir
		path = File.join(Dir.home, @dir_root)
		FileUtils.remove_dir(path, true) if Dir.exists? path
		Dir.mkdir(path, 0777)
		path + File::SEPARATOR
	end

	def self.add_files_to_deploy_dir(deploy_dir, file_names, meta_names)
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
	attr_accessor :xml_ant_build, :deploy_dir, :build_file

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
						zipFile="pack.zip" 
						pollWaitMillis="10000" 
						maxPoll="200"/>
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