require 'mobb'
require 'cgi'

set :service, 'slack'

module Sandbox
  self_module = self

  [File, Dir, IO, Process, FileTest, RubyVM, RubyVM::InstructionSequence].each do |klass|
    refine klass.singleton_class do
      def banned_method(*_); raise SecurityError.new; end
      klass.methods.each do |m|
        alias_method(m, :banned_method)
      end
    end
  end

  refine Object do
    def banned_method(*_); raise SecurityError.new; end
    allowed = [:Array, :Complex, :Float, :Hash, :Integer, :Rational, :String, :block_given?, :iterator?, :catch, :raise, :gsub, :lambda, :proc, :rand, :methods, :private_methods]
    Kernel.methods.reject { |name| allowed.include?(name.to_sym) }.each do |m|
      alias_method(m, :banned_method)
    end
  end

  refine Module do
    def banned_method(*_); raise SecurityError.new; end
    allowed = [:alias_method, :methods, :private_methods]
    methods = Module.methods + self_module.private_methods
    methods.reject { |name| allowed.include?(name.to_sym) }.each do |m|
      alias_method(m, :banned_method)
    end
  end

  refine Kernel.singleton_class do
    def banned_method(*_); raise SecurityError.new; end
    allowed = [:Array, :Complex, :Float, :Hash, :Integer, :Rational, :String, :block_given?, :iterator?, :catch, :raise, :gsub, :lambda, :proc, :rand]
    Kernel.methods.reject { |name| allowed.include?(name.to_sym) }.each do |m|
      alias_method(m, :banned_method)
    end
  end
end

on /^ruby:\s+(.+)$/ do |code|
  code = CGI.unescapeHTML(code)

  begin
    RubyVM::InstructionSequence.compile(code)
  rescue SyntaxError => e
    return e.message
  end


  def tainted(code)
    <<"CLEANROOM"
    module CleanRoom
      using Sandbox
      TOPLEVEL_BINDING = self
      ENV = {}
      RUBY_DESCRIPTION = "sandbox"
      RUBY_ENGINE = "sandbox"
      RUBY_PATCHLEVEL = nil
      RUBY_PLATFORM = "sandbox"
      RUBY_RELEASE_DATE = "sandbox"
      RUBY_REVISION = nil
      RUBY_VERSION = "sandbox"
      #{code}
    end
CLEANROOM
  end

  res = begin
    eval(tainted(code))
  rescue SecurityError, SyntaxError, SystemStackError, StandardError => e
    e.message
  end

  res.to_s
end
