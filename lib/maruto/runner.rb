require 'maruto'
require 'nokogiri'
require 'pathname'
require 'thor'

class Maruto::Runner < Thor
	include Thor::Actions

	desc "magento? MAGENTO_ROOT", "check if MAGENTO_ROOT contains a magento app"
	def magento?(magento_root)
		magento_root = Pathname.new(magento_root).cleanpath
		check_magento_folder(magento_root)
	end

	desc "lint MAGENTO_ROOT", "lint php files in MAGENTO_ROOT/app/code"
	def lint(magento_root)

		magento_root = Pathname.new(magento_root).cleanpath
		check_magento_folder(magento_root)

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

	desc "events MAGENTO_ROOT", "list events and their observers"
	def events(magento_root)

		magento_root = Pathname.new(magento_root).cleanpath
		check_magento_folder(magento_root)

		magento_config = Maruto::MagentoConfig.new magento_root

		magento_config.events.sort_by { |k, v| k }.each do |event, observers|
			puts event
			observers.each do |observer|
				puts "   #{observer}"
			end
		end

	end

	no_commands do
		def check_magento_folder(magento_root)
			raise Thor::Error, "not a folder: #{magento_root}" unless magento_root.directory?

			is_magento = (magento_root + 'app').directory? &&
			             (magento_root + 'app/code').directory? &&
			             (magento_root + 'app/etc').directory? &&
			             (magento_root + 'app/etc/modules').directory? &&
			             (magento_root + 'app/etc/local.xml').file?
			raise Thor::Error, "could not find magento in this folder: #{magento_root}" unless is_magento
		end
	end
end


