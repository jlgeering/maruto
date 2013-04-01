require 'maruto/base'
require 'nokogiri'

module Maruto::ConfigParser

	def self.parse_module_definition(xml_node)
		module_definition = {
			:name      => xml_node.name.to_sym,
			:active    => !(/^(false|off)$/ =~ xml_node.at_xpath('active').content),
			:code_pool => xml_node.at_xpath('codePool').content.to_sym,
		}

		deps = xml_node.xpath('depends/*').map { |e| e.name.to_sym }
		module_definition[:dependencies] = deps if deps.size > 0

		unless /^(true|false|off)$/ =~ xml_node.at_xpath('active').content then
			module_definition[:warnings] = ["value for active element should be in ['true','false','off'] (element: #{xml_node.at_xpath('active')})"]
		end

		unless /^(core|community|local)$/ =~ xml_node.at_xpath('codePool').content then
			module_definition[:warnings] = ["value for codePool element should be in ['core','community','local'] (element: #{xml_node.at_xpath('codePool')})"]
		end

		module_definition
	end

	def self.parse_module_definition_file(path)
		f = File.open(path)
		doc = Nokogiri::XML(f) { |config| config.strict }
		f.close

		doc.xpath('//modules/*').map { |xml_node| self.parse_module_definition(xml_node).merge({:defined => path}) }
	end

	def self.parse_all_module_definitions(magento_root)
		Dir.chdir(magento_root) do
			Dir.glob('app/etc/modules/*.xml').reduce([]) { |result, path| result + self.parse_module_definition_file(path) }
		end
	end

end
