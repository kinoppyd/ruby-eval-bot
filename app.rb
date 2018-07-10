require 'mobb'
require 'cgi'

set :service, 'slack'

module Sandbox
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
    allowed = [:Array, :Complex, :Float, :Hash, :Integer, :Rational, :String, :block_given?, :iterator?, :catch, :raise, :gsub, :lambda, :proc, :rand, :methods]
    Kernel.methods.reject { |name| allowed.include?(name.to_sym) }.each do |m|
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

  return "Invalid Access" if code.include?("ENV")

  def tainted(code)
    <<"CLEANROOM"
    module CleanRoom
      using Sandbox
      #{code}
    end
CLEANROOM
  end

  res = begin
    eval(tainted(code))
  rescue SecurityError, SyntaxError => e
    e.message
  rescue Error => e
    e.message
  end

  res.to_s
end
