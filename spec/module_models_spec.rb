# frozen_string_literal: true

require 'spec_helper'

require 'maruto/module_configuration'

module Maruto

	describe ModuleConfiguration do


		describe "when parsing a module config.xml and reading models" do

			before do
				@xml_root = Nokogiri::XML('''
					<config>
						<global>
							<models>
								<something>
									<class>Mage_A_Model</class>
								</something>
							</models>
						</global>
					</config>
				''').root
			end

			# it "will return an array of models and an array of warnings" do
			# 	no_models = Nokogiri::XML('<config></config>').root
			# 	models, warnings = ModuleConfiguration.parse_models(no_models)
			# 	models.must_be_kind_of Array
			# 	models.size.must_equal 0
			# 	warnings.must_be_kind_of Array
			# 	warnings.size.must_equal 0
			# end
			# it "will return an array of models and an array of warnings" do
			# 	no_models = Nokogiri::XML('<config></config>').root
			# 	models, warnings = ModuleConfiguration.parse_models(no_models)
			# 	models.must_be_kind_of Array
			# 	models.size.must_equal 0
			# 	warnings.must_be_kind_of Array
			# 	warnings.size.must_equal 0
			# end
			it "will add a warning if there is a <models> element outside of /config/global" do
				# TODO
			end
		end
	end
end
