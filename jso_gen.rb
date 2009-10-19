# jso_gen.rb

require 'json'
require 'open-uri'
require 'erb'

# Parses JSON and create data structure necessary to generate GWT JavaScript
# Overlay Types.
#
class JsoGen
  class UnknownClass < RuntimeError; end
  
  attr_reader :json, :root

  # url = "http://localhost:3000/search/news_genre/one.json"
  # jgen = JsoGen.new(url)
  def initialize url
    open(url) {|f| @json = f.read}
    @root = JSON.parse @json
  end

  # generate JavaScript Overlay Types and store the output strings as values
  # in the return Hash
  def generate
    classes = {}
    @root.generate_jso 'root', classes
    classes
  end

  # parse self into a Hash of classes
  def tokenize
    @root.jso_token
  end

  def self.gen_class class_name, methods, package_name='fr.orange.lgsite.client.json'
    template = ERB.new <<-EOF
package <%= package_name %>;

import com.google.gwt.core.client.JavaScriptObject;
import com.google.gwt.core.client.JsArray;

public class <%= class_name %> extends JavaScriptObject
{
  // Overlay types always have protected, zero-argument constructors
  protected <%= class_name %> () {}

  // Typically, methods on overlay types are JSNI
<%= methods %>
}
    EOF
    template.result binding
  end

  def self.gen_method java_type, js_field_name
    java_method_name = "get#{js_field_name.camelize}"

    template = ERB.new <<-EOF
  public final native <%= java_type %> <%= java_method_name %> () /*-{
    return this.<%= js_field_name %>;
  }-*/;

    EOF
    template.result binding
  end

end

# module to include into scalar classes
module ScalarGenerator
  def generate_jso field_name, classes
    JsoGen.gen_method self.java_type, field_name
  end
end

module ScalarJso
  include ScalarGenerator

  def is_scalar
    true
  end

  def jso_token
    self.class
  end
end

module VectorJso
  def is_scalar
    false
  end
end

# open scalar classes

class Bignum
  include ScalarJso

  def java_type; "float"; end
end

class FalseClass
  include ScalarJso

  def java_type; "boolean"; end
end

class Fixnum
  include ScalarJso

  def java_type; "int"; end
end

class Float
  include ScalarJso

  def java_type; "float"; end
end

class NilClass
  include ScalarJso

  def java_type; "String"; end
end

class String
  include ScalarJso

  def camelize
      self.split('_').collect {|s| s.capitalize}.join('')
  end
  
  def java_type; "String"; end
end

class TrueClass
  include ScalarJso

  def java_type; "boolean"; end
end

# open Array
class Array
  include VectorJso

  def generate_jso field_name, classes
    self.first.generate_jso(field_name, classes) if self.first.is_a? Hash
    JsoGen.gen_method self.java_type, field_name
  end

  def jso_token
    [self.first.jso_token]
  end

  def java_type
    "JsArray<#{self.first.java_type}>"
  end
end

# open Hash
class Hash
  include VectorJso

  def jso_token
    ret_hash = {}
    self.each {|k, v| ret_hash[k] = v.jso_token}
    ret_hash
  end

  def java_type
    long_name = self.keys.sort.collect {|k| k.camelize}.join ''
    hashed = long_name.hash.abs.to_s(36).capitalize
    "JsoGen#{hashed}"
  end

  def generate_jso field_name, classes
    java_class = self.java_type

    unless classes.include? java_class
      java_class = self.java_type
      methods = self.keys.sort.collect {|k| self[k].generate_jso k, classes}

      body = JsoGen.gen_class java_class, methods
      classes[java_class] = body
    end
    
    java_class
  end

end

