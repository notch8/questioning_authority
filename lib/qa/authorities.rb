require 'active_support'
require 'active_support/core_ext'

module Qa::Authorities
  extend ActiveSupport::Autoload

  @@authorities = {}

  ##
  # @return [Array<Class>]
  def self.authorities
    @@authorities.values
  end

  ##
  # @param name [#to_sym]
  #
  # @return [Class]
  def self.class_for(name: name)
    @@authorities.fetch(name.to_sym) do
      raise NameError, 
            "#{name} is not a registered authority in Questioning Authority"
    end
  end

  ##
  # @param name  [#to_sym]
  # @param klass [Class]
  #
  # @return [void]
  def self.register(name:, klass:)
    @@authorities[name.to_sym] = klass
  end

  autoload :AuthorityWithSubAuthority
  autoload :Base
  autoload :Getty
  autoload :Geonames
  autoload :Loc
  autoload :LocSubauthority
  autoload :Local
  autoload :LocalSubauthority
  autoload :Mesh
  autoload :MeshTools
  autoload :Oclcts
  autoload :Tgnlang
  autoload :WebServiceBase
  autoload :AssignFast
  autoload :AssignFastSubauthority
end
