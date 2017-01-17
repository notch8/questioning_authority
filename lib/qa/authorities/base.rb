require 'deprecation'

module Qa::Authorities
  ##
  # @abstract The base class for all authorites. Implementing subclasses must
  #   provide {#all}, {#find}, and {#search} methods.
  class Base
    extend Deprecation

    ##
    # @abstract By default, #all is not implemented. A subclass authority must
    #   implement this method to conform to the generic interface. The
    #   `#to_json` response may be an empty list (`[]`) if no terms exist.
    #
    # List the terms.
    #
    # @return [#to_json] a JSON-castable object containing a list of all terms
    #   in the authority's vocabulary.
    # @raise [NotImplementedError] when this method is abstract.
    def all
      raise NotImplementedError, "#{self.class}#all is unimplemented."
    end

    ##
    # @abstract By default, #find is not implemented. A subclass authority must
    #   implement this method to conform to the generic interface. When the term
    #   does not exist, the `#to_json` response should be `nil` and must result
    #   in a 'null' JSON body.
    #
    # Retrieve the requested term by id.
    #
    # @param _id [String] the id string for the authority to lookup
    #
    # @return [#to_json] the requested term body as a JSON-castable object.
    #   `nil` when the term does not exist.
    # @raise [NotImplementedError] when this method is abstract.
    def find(_id)
      raise NotImplementedError, "#{self.class}#find is unimplemented."
    end

    ##
    # @deprecated use {#find} instead
    def full_record(id, _subauthority = nil)
      Deprecation.warn('#full_record is deprecated. Use #find instead')
      find(id)
    end

    ##
    # @abstract By default, #search is not implemented. A subclass authority
    #   must implement this method to conform to the generic interface.
    #
    # Search the authority, returning a list of terms as a response.
    #
    # @param _query [String] the query string.
    #
    # @return [#to_json] a JSON-castable object containing a list of terms as
    #   the search response.
    # @raise [NotImplementedError] when this method is abstract.
    def search(_query)
      raise NotImplementedError, "#{self.class}#search is unimplemented."
    end
  end
end
