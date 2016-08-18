# frozen_string_literal: true

require 'maruto/base'
require 'nokogiri'

module Maruto::MagentoVersion

	def self.read_magento_version()
		mage = 'app/Mage.php'
		return nil unless File.exist? mage
		File.open mage do |file|
			# newer magento version have a getVersionInfo function
			newer = file.find { |line| line =~ /getVersionInfo/ }
			file.rewind
			if newer
				# newer Magento version
				function = read_function(file, 'getVersionInfo')
				match    = function.match(/return array\(.*'major'.*'(\d+)'.*'minor'.*'(\d+)'.*'revision'.*'(\d+)'.*'patch'.*'(\d+)'.*'stability'.*'number'.*\)/)
				version    = []
				version[0] = match[1].to_i unless match[1].nil?
				version[1] = match[2].to_i unless match[2].nil?
				version[2] = match[3].to_i unless match[3].nil?
				version[3] = match[4].to_i unless match[4].nil?
				return version
			else
				# older Magento version
				function = read_function(file, 'getVersion')
				match    = function.match(/return '(\d+)\.(\d+)\.?(\d+)?\.?(\d+)?';/)
				version    = []
				version[0] = match[1].to_i unless match[1].nil?
				version[1] = match[2].to_i unless match[2].nil?
				version[2] = match[3].to_i unless match[3].nil?
				version[3] = match[4].to_i unless match[4].nil?
				return version
			end
		end
	end

private

	def self.read_function(file, function_name)
		func = nil
		file.rewind
		file.each_line do |line|
			if func then
				func += line
				if /}/ =~ line
					break
				end
			else
				if /public static function #{function_name}\(\)/ =~ line
					func = line
				end
			end
		end
		func.delete("\n")
	end

end
