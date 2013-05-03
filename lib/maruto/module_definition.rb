require 'maruto/base'
require 'nokogiri'
require 'tsort'

module Maruto::ModuleDefinition

	def self.parse_module_definition(xml_node)
		module_definition = {
			:name      => xml_node.name.to_sym,
			:active    => !(/^(false|off)$/ =~ xml_node.at_xpath('active').content),
			:code_pool => xml_node.at_xpath('codePool').content.to_sym,
		}

		deps = xml_node.xpath('depends/*').map { |e| e.name.to_sym }
		module_definition[:dependencies] = deps if deps.size > 0

		unless /^(true|false|off)$/ =~ xml_node.at_xpath('active').content then
			module_definition[:warnings] = []
			module_definition[:warnings] << { :message => "value for active element should be in ['true','false','off'] (element: #{xml_node.at_xpath('active')})" }
		end

		unless /^(core|community|local)$/ =~ xml_node.at_xpath('codePool').content then
			module_definition[:warnings] ||= []
			module_definition[:warnings] << { :message => "value for codePool element should be in ['core','community','local'] (element: #{xml_node.at_xpath('codePool')})" }
		end

		module_definition
	end

	def self.parse_module_definition_file(path)
		f = File.open(path)
		doc = Nokogiri::XML(f) { |config| config.strict }
		f.close

		modules = doc.xpath('//modules/*').map { |xml_node| self.parse_module_definition(xml_node).merge({:defined => path}) }

		modules.each do |m|
			if m.include? :warnings then
				m[:warnings].each do |w|
					w[:file] = path
				end
			end
		end

		modules
	end

	def self.parse_all_module_definitions()
		Dir.glob('app/etc/modules/*.xml').reduce([]) { |result, path| result + self.parse_module_definition_file(path) }
	end

	class ModuleSorter
		include TSort
		def initialize(h)
			@h = h
		end
		def tsort_each_node(&block)
			@h.each_key(&block)
		end
		def tsort_each_child(mod_name, &block)
			@h[mod_name][:dependencies].each(&block) if @h[mod_name].include? :dependencies
		end
		def sorted
			tsort.map { |mod_name| @h[mod_name] }
		end
	end

	def self.analyse_module_definitions(module_definitions)
		h = Hash.new
		module_definitions.each do |m|
			if m[:active]
				mod_name = m[:name]
				if h.include? mod_name then
					# disable first module
					h[mod_name][:active] = false
					m[:warnings] ||= []
					m[:warnings] << { :file => m[:defined], :message => "duplicate module definition (in '#{h[mod_name][:defined]}' and '#{m[:defined]}')" }
				end
				parts = mod_name.to_s.split('_')
				h[mod_name] = m
				if parts.size != 2
					m[:warnings] ||= []
					m[:warnings] << { :file => m[:defined], :message => "invalid module name" }
					m[:active] = false
				else
					m[:config_path] = "app/code/#{m[:code_pool]}/#{parts[0]}/#{parts[1]}/etc/config.xml"
					if !File.exists?(m[:config_path])
						m[:warnings] ||= []
						m[:warnings]<< { :file => m[:defined], :message => "config.xml is missing (searching '#{m[:config_path]}' for #{m[:name]})" }
						m[:active] = false
					end
				end
			end
		end
		# remove inactive modules
		h.reject!{|n,m| !m[:active]}
		# check dependencies
		h.reject{|n,m| !m.include? :dependencies}.each do |mod_name, m|
			# group by module name: hash of module_name => [module_name]
			dependencies = m[:dependencies].group_by{ |e| e }
			# find duplicates
			duplicates       = Hash[dependencies.select{ |k, v| v.size > 1 }].keys  # in ruby 1.8.7 select returns an array of tuples
			# unique values
			m[:dependencies] = dependencies.keys
			if duplicates.size > 0
				m[:warnings] ||= []
				m[:warnings] << { :file => m[:defined], :message => "duplicate dependencies (#{duplicates.join(', ')})" }
			end
			m[:dependencies].delete_if do |d|
				unless h.include? d
					m[:warnings] ||= []
					m[:warnings] << { :file => m[:defined], :message => "missing dependency: '#{d}'" }
					true
				end
			end
		end
		[ModuleSorter.new(h).sorted, h]
	end

end
