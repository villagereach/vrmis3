class ERB
  module Util
    # A utility method for escaping strings used in jQuery templates;
    # html_escape the string and then apply additional fixups.
    # Aliased as <tt>jt</tt>.
    def jquery_template_escape(s)
      html_escape(s).gsub("'", "\\\\'")
    end
    alias jt jquery_template_escape
  end
end
