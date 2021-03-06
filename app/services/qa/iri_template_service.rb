# Provide service for building a URL based on an IRI Templated Link and its variable mappings based on provided substitutions.
module Qa
  class IriTemplateService
    # Construct an url from an IriTemplate making identified substitutions
    # @param url_config [Qa::IriTemplate::UrlConfig] configuration (json) holding the template and variable mappings
    # @param substitutions [HashWithIndifferentAccess] name-value pairs to substitute into the url template
    # @return [String] url with substitutions
    def self.build_url(url_config:, substitutions:)
      # TODO: This is a very simple approach using direct substitution into the template string.
      #   Better would be to...
      #     * pattern {var_name} = simple value substitution in place of pattern produces 'value'
      #     * pattern {?var_name} = parameter substitution in place of pattern produces 'var_name=value'
      #     * patterns without a substitution are not included in the resulting URL
      #     * appropriately adds '?' or '&'
      #     * ensure proper escaping of values (e.g. value="A simple string" which is encoded as A%20simple%20string)
      #   Even more advanced would be to...
      #     * support BasicRepresentation (which is what it does now)
      #     * support ExplicitRepresentation
      #        * literal encoding for values (e.g. value="A simple string" becomes %22A%20simple%20string%22)
      #        * language encoding for values (e.g. value="A simple string" becomes value="A simple string"@en which is encoded as %22A%20simple%20string%22%40en)
      #        * type encoding for values (e.g. value=5.5 becomes value="5.5"^^http://www.w3.org/2001/XMLSchema#decimal which is encoded
      #                                         as %225.5%22%5E%5Ehttp%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%23decimal)
      # Fuller implementations parse the template into component parts and then build the URL by adding parts in as applicable.
      url = url_config.template
      url_config.mapping.each do |m|
        key = m.variable
        url = url.gsub("{?#{key}}", m.simple_value(substitutions[key])) # Incorrectly applies pattern {?var_name} to produce substitution 'value'
        # url.gsub("{#{key}}", m.simple_value(substitutions[key]))  # TODO: pattern {var_name} should produce substitution 'value'
        # url.gsub("{?#{key}}", m.parameter_value(substitutions[key])) # TODO: pattern {?var_name} should produce substitution 'var_name=value'
      end
      url
    end
  end
end
