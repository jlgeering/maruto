require 'maruto'
require 'nokogiri'
require 'pathname'
require 'thor'

class Maruto::Runner < Thor
	include Thor::Actions

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
					puts file unless firstline.start_with?("<?php")
				rescue
					# TODO return list of errors
					puts "error in " + file
				end
			end
		end
	end

	desc "events", "list configured events and their observers"
	method_option :magento_root, :aliases => "-m", :default => "."
	def events()

		magento_root = check_magento_folder()

		magento_config = Maruto::MagentoConfig.new magento_root

		magento_config.events.sort_by { |k, v| k }.each do |event, observers|
			puts event
			observers.each do |observer|
				puts "   #{observer}"
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
			             (magento_root + 'app/etc/local.xml').file?
			raise Thor::Error, "could not find magento in this folder: #{magento_root.realpath}#{options[:magento_root] == '.' ? ' (try -m MAGENTO_ROOT)' : ''}" unless is_magento

			return magento_root
		end
	end
end


