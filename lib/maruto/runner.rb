require 'maruto'
require 'thor'

class Maruto::Runner < Thor
	include Thor::Actions

	desc "lint MAGENTO_ROOT", "lint php files"
	def lint(magento_root)

		# TODO move this into a magento_folder? method
		magento_root = Pathname.new(magento_root).cleanpath

		raise Thor::Error, "not a folder: #{magento_root}" unless magento_root.directory?

		is_magento = (magento_root + 'app').directory? &&
		             (magento_root + 'app/code').directory? &&
		             (magento_root + 'app/etc').directory? &&
		             (magento_root + 'app/etc/modules').directory? &&
		             (magento_root + 'app/etc/local.xml').file?
		raise Thor::Error, "could not find magento in this folder: #{magento_root}" unless is_magento

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

end


