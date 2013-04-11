require 'maruto/version'
require 'maruto/magento_config'
require 'maruto/module_definition'

module Maruto
	def self.modules(magento_root)
		parsed_module_definitions = Maruto::ModuleDefinition.parse_all_module_definitions(magento_root)
		a,h = Maruto::ModuleDefinition.analyse_module_definitions(magento_root, parsed_module_definitions)
		a
	end
	def self.warnings(magento_root)
		parsed_module_definitions = Maruto::ModuleDefinition.parse_all_module_definitions(magento_root)
		Maruto::ModuleDefinition.analyse_module_definitions(magento_root, parsed_module_definitions)
		warnings = []
		parsed_module_definitions.each do |m|
			warnings.concat m[:warnings].map{|w| "[module:#{m[:name]}] #{w}"} if m.include? :warnings
		end
		warnings
	end
end