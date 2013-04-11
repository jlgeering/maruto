
require 'maruto/module_definition'
require 'maruto/module_configuration'

module Maruto::MagentoInstance
	def self.load(magento_root)
		all_modules = Maruto::ModuleDefinition.parse_all_module_definitions(magento_root)
		sorted_modules, active_modules = Maruto::ModuleDefinition.analyse_module_definitions(magento_root, all_modules)

		sorted_modules.each do |m|
			Maruto::ModuleConfiguration.load(m)
			# ModuleConfiguration.analyse(m, active_modules)
		end

		warnings = []
		all_modules.each do |m|
			warnings.concat m[:warnings].map{|w| "[module:#{m[:name]}] #{w}"} if m.include? :warnings
		end

		{
			:active_modules => active_modules.map{|k,v| v},
			:all_modules    => all_modules,
			:sorted_modules => sorted_modules,
			:warnings       => warnings,
		}
	end
end
