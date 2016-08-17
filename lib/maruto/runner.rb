require 'maruto'
require 'nokogiri'
require 'pathname'
require 'thor'

class Maruto::Runner < Thor
	include Thor::Actions

	map "-v" => :version, "--version" => :version

	desc "version", "Show Maruto and Magento version"
	method_option :magento_root, :aliases => "-m", :default => "."
	def version
		say "Maruto #{Maruto::VERSION}"
		begin
			magento_root = check_magento_folder()
			magento = Maruto::MagentoInstance.load(magento_root)
			say "Magento #{magento[:version].join('.')}"
		rescue Thor::Error
			# do nothing
		end
	end

	desc "magento?", "check if MAGENTO_ROOT contains a magento app"
	method_option :magento_root, :aliases => "-m", :default => "."
	def magento?()
		check_magento_folder()
		puts "OK"
	end

	desc "lint", "lint php files in MAGENTO_ROOT/app/code"
	method_option :magento_root, :aliases => "-m", :default => "."
	def lint()

		magento_root = check_magento_folder()

		# TODO move this into a lint_php method
		inside(magento_root) do
			Dir.glob( 'app/code/**/*.php' ) do |file|
				begin
					firstline = File.open(file, &:readline)
					# TODO return list of warnings
					# TODO case insensitive
					puts file unless firstline.start_with?("<?php") or firstline.start_with?("<?PHP")
				rescue
					# TODO return list of errors
					puts "error in " + file
				end
			end
		end
	end

	desc "warnings", "list potential problems found in the config"
	method_option :magento_root, :aliases => "-m", :default => "."
	method_option :with_core, :type => :boolean, :aliases => "-c", :default => false
	def warnings()

		magento_root = check_magento_folder()

		magento_config = Maruto::MagentoConfig.new magento_root
		magento_config.print_warnings

		# next gen maruto:

		with_core = options[:with_core]

		magento = Maruto::MagentoInstance.load(magento_root)

		magento[:warnings].group_by { |e| e[:module] }.each do |m,module_warnings|
			if with_core or magento[:all_modules][m][:code_pool] != :core then
				puts "[module:#{m}]"
				module_warnings.group_by { |e| e[:file] }.each do |file,warnings|
					puts "  [file:#{file}]"
					warnings.each do |w|
						puts "    #{w[:message]}"
					end
				end
			end
		end

		if magento[:warnings].empty?
			exit 0
		end
		exit 1
	end

	desc "models", "list models sorted and grouped by their group_name"
	method_option :magento_root, :aliases => "-m", :default => "."
	def models()

		magento_root = check_magento_folder()

		magento_config = Maruto::MagentoConfig.new magento_root

		magento_config.models.sort_by { |k, v| k }.each do |name,group|
			puts "#{name} #{group}"
		end

	end

	desc "modules", "list modules"
	method_option :magento_root, :aliases => "-m", :default => "."
	def modules()

		magento_root = check_magento_folder()

		magento = Maruto::MagentoInstance.load(magento_root)

		magento[:all_modules].each do |name, m|
			deps = ''
			deps = ", dependencies:[#{m[:dependencies].collect{ |d| d.to_s }.join(', ')}]" if m[:dependencies]
			puts "#{name}(active:#{m[:active]}, code_pool:#{m[:code_pool]}, defined:#{m[:defined]}#{deps})"
		end

	end

	desc "observers FILTER", "list observers sorted and grouped by their event or area, optionally filtered by event name"
	method_option :magento_root, :aliases => "-m", :default => "."
	method_option :group_by_scope, :type => :boolean, :aliases => "-s", :default => false
	def observers(filter = nil)

		magento_root = check_magento_folder()

		magento = Maruto::MagentoInstance.load(magento_root)

		group_by_scope = options[:group_by_scope]

		if group_by_scope then
			magento[:event_observers].each do |area, events|
				events.each do |event, observers|
					if filter.nil? or event.include? filter
						puts "#{area}/#{event}"
						observers.each do |name, observer|
							puts "  #{name} (module:#{observer[:module]} type:#{observer[:type]} class:#{observer[:class]} method:#{observer[:method]})"
						end
					end
				end
			end
		else
			grouped_by_events = Hash.new
			magento[:event_observers].each do |area, events|
				events.each do |event, observers|
					grouped_by_events[event] ||= Hash.new
					grouped_by_events[event][area] = observers
				end
			end
			grouped_by_events.sort_by { |k, v| k }.each do |event, areas|
				if filter.nil? or event.include? filter
					puts "#{event}"
					areas.each do |area, observers|
						observers.each do |name, observer|
							puts "  #{area}/#{name} (module:#{observer[:module]} type:#{observer[:type]} class:#{observer[:class]} method:#{observer[:method]})"
						end
					end
				end
			end
		end

	end

	no_commands do
		def check_magento_folder()
			magento_root = Pathname.new(options[:magento_root]).cleanpath

			raise Thor::Error, "not a folder: #{magento_root}" unless magento_root.directory?

			is_magento = (magento_root + 'app').directory? &&
									 (magento_root + 'app/code').directory? &&
									 (magento_root + 'app/etc').directory? &&
									 (magento_root + 'app/etc/modules').directory? &&
									 (magento_root + 'app/etc/modules/Mage_All.xml').file?
			raise Thor::Error, "could not find magento in this folder: #{magento_root.realpath}#{options[:magento_root] == '.' ? ' (try -m MAGENTO_ROOT)' : ''}" unless is_magento

			return magento_root
		end
	end
end
