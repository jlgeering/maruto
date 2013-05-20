require 'maruto/base'
require 'nokogiri'

module Maruto::MagentoVersion

	def self.read_magento_version()
		mage = 'app/Mage.php'
		File.open mage do |file|
			if file.find { |line| line =~ /getVersionInfo/ }
				# newer Magento version
				return []
			else
				# older Magento version
				 return [1,0]
			end
		end
	end

end
