# code hoovered from different places to cobble together some outdated
# sinatra html tag helpers
# ------------------------------------------------------

module Sinatra

  module AssetHelpers
 
    PRE_CONTENT_STRINGS = Hash.new { "" }

    TAG_PREFIXES = ["aria", "data", :aria, :data].to_set

    BOOLEAN_ATTRIBUTES = %w(allowfullscreen async autofocus autoplay checked compact controls declare default defaultchecked defaultmuted defaultselected defer disabled enabled formnovalidate hidden indeterminate inert ismap itemscope loop multiple muted nohref noresize noshade novalidate nowrap open pauseonexit readonly required reversed scoped seamless selected sortable truespeed typemustmatch visible).to_set

# ------------------------------------------------------
# ------------------------------------------------------

# ------------------------------------------------------
# ------------------------------------------------------
    def send_data(data, options={})
      status       options[:status]   if options[:status]
      attachment   options[:filename] if options[:disposition] == 'attachment'
      content_type options[:type]     if options[:type]
      halt data
    end

# ------------------------------------------------------
# ------------------------------------------------------
# File lib/erb.rb, line 992
    def url_encode(s)
      s.to_s.b.gsub(/[^a-zA-Z0-9_\-.~]/) { |m|
        sprintf("%%%02X", m.unpack1("C"))
      }
    end

# ------------------------------------------------------
# ------------------------------------------------------
# modified from: File actionview/lib/action_view/helpers/url_helper.rb, line 482
      def mail_to(email_address, name = nil, html_options = {} )
        html_options = (html_options || {})

        encoded_email_address = url_encode(email_address).gsub("%40", "@")

        link_to(name || email_address, "mailto:#{encoded_email_address}", html_options)
      end

# ------------------------------------------------------
    # File actionview/lib/action_view/helpers/tag_helper.rb, line 174
# ------------------------------------------------------
      def prefix_tag_option(prefix, key, value, escape)
        key = "#{prefix}-#{key.to_s.dasherize}"
        unless value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(BigDecimal)
          value = value.to_json
        end
        tag_option(key, value, escape)
      end

# ------------------------------------------------------
    # File actionview/lib/action_view/helpers/tag_helper.rb, line 182
# ------------------------------------------------------
        def boolean_tag_option(key)
          %(#{key}="#{key}")
        end

# ------------------------------------------------------
    # File actionview/lib/action_view/helpers/tag_helper.rb, line 186
# ------------------------------------------------------
      def tag_option(key, value, escape)
        if value.is_a?(Array)
          value = escape ? safe_join(value, " ".freeze) : value.join(" ".freeze)
        else
          value = escape ? unwrapped_html_escape(value) : value
        end
        %(#{key}="#{value.gsub(/"/, '"'.freeze)}")
      end

# ------------------------------------------------------
    # File actionview/lib/action_view/helpers/output_safety_helper.rb, line 33
# ------------------------------------------------------
      def safe_join(array, sep = $,)
        sep = unwrapped_html_escape(sep)

        array.flatten.map! { |i| unwrapped_html_escape(i) }.join(sep).html_safe
      end

# ------------------------------------------------------
    # File activesupport/lib/active_support/inflector/methods.rb, line 209
# ------------------------------------------------------
      def dasherize(underscored_word)
        underscored_word.tr("_".freeze, "-".freeze)
      end

# ------------------------------------------------------
    # File activesupport/lib/active_support/core_ext/string/output_safety.rb, line 34
# ------------------------------------------------------
      def unwrapped_html_escape(s) # :nodoc:
        s = s.to_s
        # KLUDGE HERE: hope it will be okay without
        #if s.html_safe?
          #s
        #else
          #CGI.escapeHTML(ActiveSupport::Multibyte::Unicode.tidy_bytes(s))
        #end
      end

# ------------------------------------------------------
    # File actionview/lib/action_view/helpers/tag_helper.rb, line 150
# ------------------------------------------------------
      def to_html_attributes(options, escape = true)
        return "" if options.empty?
        output = ""
        sep    = " ".freeze
        options.each_pair do |key, value|
          if TAG_PREFIXES.include?(key) && value.is_a?(Hash)
            value.each_pair do |k, v|
              next if v.nil?
              output << sep
              output << prefix_tag_option(key, k, v, escape)
            end
          elsif BOOLEAN_ATTRIBUTES.include?(key)
            if value
              output << sep
              output << boolean_tag_option(key)
            end
          elsif !value.nil?
            output << sep
            output << tag_option(key, value, escape)
          end
        end
        output unless output.empty?
      end

# ------------------------------------------------------
      # 
      # Methods for working with assets like images, links etc.
      #
      ##
      # Construct a link to +url_fragment+, which should be given relative to
      # the base of this Sinatra app.  
      # 
      # The mode should be either <code>:path_only</code>, which will generate an absolute path 
      # within the current domain (the default), or <code>:full</code>, which will include 
      # the site name and port number.  (The latter is typically necessary for links in RSS feeds.)  
      # 
      # Code inspiration from [ http://github.com/emk/sinatra-url-for/ ] by Eric Kidd
      # 
      # ==== Examples
      # 
      # When <tt>request.script_name => ''</tt>  => map '/' do...
      # 
      #   url_for()                # Returns "/"
      #   url_for('')              # Returns "/"
      #   url_for(nil)             # Returns "/"
      # 
      #   url_for "/"              # Returns "/"
      #   url_for("/", :root)      # Returns "/" at the root of the app system
      # 
      #   url_for "path"           # Returns "/path"
      #   url_for "/path"          # Returns "/path"
      # 
      #   url_for "path", :full    # Returns "http://example.com/path"
      #   url_for "/path", :full   # Returns "http://example.com/path"
      # 
      # This also work with apps that are mounted Rack apps:
      # 
      #   # config.ru
      #   map '/somepath' do
      #     run MyApp
      #   end
      # 
      #   url_for '/blog'  =>  /somepath/blog
      # 
      # 
      # <b>NB! '/urlmap' represents the URL Map path given by request.script_name</b>  
      # 
      # When <tt>request.script_name => '/urlmap'</tt>  => map '/urlmap' do...
      # 
      #   url_for()                # Returns "/urlmap/"
      #   url_for('')              # Returns "/urlmap/"
      #   url_for(nil)             # Returns "/urlmap/"
      # 
      #   url_for "/"              # Returns "/urlmap/"
      #   url_for("/", :root)      # Returns "/" at the root of the app system
      # 
      #   url_for "path"           # Returns "/urlmap/path"
      #   url_for "/path"          # Returns "/path"
      # 
      #   url_for "path", :full    # Returns "http://example.com/urlmap/path"
      #   url_for "/path", :full   # Returns "http://example.com/path"
      # 
      # @api public
# ------------------------------------------------------
      def url_for(path='/', url_params = {}, mode = nil) 
        mode, url_params =  url_params, {}  if url_params.is_a?(Symbol)
        
        # Acceptable paths at this stage are:
        # -- '' # empty string
        # -- '/'
        # -- '/path/2/something'
        # -- 'path/2/something'
        
        # ensure our path is present & correct
        if path.nil?
          warn "url_for() method given a nil value"
          out_path = '/'
          
        # do we have an empty string?
        elsif (path.to_s == '' )
          # this means we're looking to stay at root of our current app
          out_path = request.script_name.empty? ? '/' : "#{request.script_name}/"
          
        # do we have a starting slash ?
        elsif (path.to_s[0,1] == '/')
          # yes, we have. is it longer than 1 char (ie: not cleaned up nil value)
          if path.length > 1
            # root path, so ignore script_name
            out_path = path
          else
            # no, short path, so are we
            # -- having a script_name value
            # -- having a mode identifier
            out_path = request.script_name.empty? ? path : "#{request.script_name}#{path}"
          end
        else
          # no, we are staying locally within our app
          out_path = request.script_name.empty? ? "/#{path}" : "#{request.script_name}/#{path}"
        end
        case mode
        when :full
          port = (request.scheme =~ /https?/ && request.port.to_s =~ /(80|443)/) ? "" : ":#{request.port}"
          base = "#{request.scheme}://#{request.host}#{port}#{request.script_name}"
        when :root
          base = '' # ignoring the script_name path
        else
          base = ''
        end
        "#{base}#{out_path}"
      end
      
      ##
      # Return image tag to _path_.
      #
      # ==== Examples
      #
      #  image 'foo.png'
      #  # => <img src="/images/foo.png" />
      #
      #  image '/foo.png', :alt => 'Kung-foo'
      #  # => <img src="/foo.png" alt="Kung-foo">
      #
      # @api public
      def image(source, attrs = {}) 
        attrs[:src] = (source[0,1] == '/') ? url_for(source) : url_for("/images/#{source}")
        attrs[:alt] ||= File.basename(source,'.*').split('.').first.to_s.capitalize
        if size = attrs.delete(:size)
          attrs[:width], attrs[:height] = size.split("x") if size =~ %r{^\d+%?x\d+%?$}
        end
        %Q[<img #{to_html_attributes(attrs)}>]
      end
      alias  :image_tag :image
      
      ##
      # A basic link helper 
      #
      # ==== Examples
      #
      #   link_to('FAQs', '#faqs')
      #   => <a href="#faqs">FAQs/a>
      #
      #   link_to('Apple', 'http://apple.com')
      #   => <a href="http://apple.com">Apple</a>
      #
      #   link_to('Apple', 'http://apple.com', :title => 'go buy a new computer')
      #   => <a href="http://apple.com" title="go buy a new computer">Apple</a>
      # 
      # @api public  
      def link_to(link_text, url, attrs={}) 
        unless url[0,1] == '#' # tag
          url = url_for(url) unless remote_asset?(url)
        end
        
        attrs = {:href => url }.merge(attrs)
        %Q[<a #{to_html_attributes(attrs)}>#{link_text}</a>]
      end
      
      
      ##
      # Simple helper method that redirects the edit/new page Cancel button 
      # back to the previous page, or if no previous page, then back to URL given.
      #
      # ==== Examples
      #
      #    redirect_back_or(url)
      #      =>
      # 
      # @api public
      def redirect_back_or(path = nil, do_redirect = false) 
        
        past = request.nil? ? nil : (request.env['HTTP_REFERER'] ||= nil)
        path = past.nil? ? path : past.sub(host,'')
        do_redirect ? redirect(path) : path
      end
      alias :redirect_back :redirect_back_or
      
      ##
      # Convenience method for the full Host URL
      # 
      # <b>NB!</b> The path must be returned without a trailing slash '/' or 
      # else the <tt>:redirect_back_or()</tt> method outputs the wrong paths
      #
      # ==== Examples
      #
      #   <%= host %> => 'http://example.org'
      # 
      # @api public
      def host 
        port = (request.scheme =~ /https?/ && request.port.to_s =~ /(80|443)/) ? "" : ":#{request.port}"
        "#{protocol}://#{request.env['SERVER_NAME']}#{port}"
        # "#{protocol}://#{request.env['SERVER_NAME']}"
      end
      alias :server :host
      
      ##
      # Convenience helper method that returns the URL protocol used
      #
      # ==== Examples
      #
      #   <%= protocol %> => 'http'
      # 
      # @api public
      def protocol 
        request.env['rack.url_scheme']
      end
      
      ## 
      # returns true/false based upon if the URL is prefixed by ' ://'
      # 
      # ==== Examples
      # 
      #   url = url_for(url) unless remote_asset?(url)
      # 
      # @api private
      def remote_asset?(uri) 
        uri =~ %r[^\w+://.+]
      end
# ------------------------------------------------------
# ------------------------------------------------------
        
    end   #  module AssetHelpers
# ------------------------------------------------------
# ------------------------------------------------------
      
    helpers AssetHelpers

end  # module sinatra
