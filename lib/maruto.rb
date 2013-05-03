require 'maruto/version'
require 'maruto/magento_config'
require 'maruto/magento_instance'

module Maruto
	def self.warnings(magento_root)
		magento = MagentoInstance.load(magento_root)
		magento[:warnings]
	end
end
