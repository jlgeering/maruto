# frozen_string_literal: true

require 'maruto/magento_version'
require 'maruto/module_definition'
require 'maruto/module_configuration'

module Maruto::MagentoInstance
	def self.load(magento_root)
		Dir.chdir(magento_root) do
			magento_version = Maruto::MagentoVersion.read_magento_version()

			all_modules = Maruto::ModuleDefinition.parse_all_module_definitions()
			sorted_modules, active_modules = Maruto::ModuleDefinition.analyse_module_definitions(all_modules)

			sorted_modules.each do |m|
				Maruto::ModuleConfiguration.parse_module_configuration(m)
			end

			event_observers = Maruto::ModuleConfiguration.collect_event_observers(sorted_modules)

			# TODO move to function: collect_warnings + write spec
			warnings = []
			all_modules.each do |m|
				warnings.concat m[:warnings].map{|w| w.merge(:module => m[:name]) } if m.include? :warnings
			end

			{
				:active_modules  => active_modules,
				:all_modules     => Hash[all_modules.collect { |m| [m[:name], m]}],
				:sorted_modules  => sorted_modules,
				:event_observers => event_observers,
				:version         => magento_version,
				:warnings        => warnings,
			}
		end
	end
end
