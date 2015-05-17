class RMQ
  def initialize
    @selected_dirty = true
  end

  def originated_from=(value)
    if value
      if value.is_a?(Potion::Activity)
        @originated_from = value
        @activity = value
      elsif value.is_a?(Potion::View)
        @originated_from = value
      elsif value.is_a?(PMScreen)
        @originated_from = value
      else
        debug.log_detailed('Invalid originated_from', objects: {value: value})
      end
    else
      @originated_from = nil
    end
    @originated_from
  end

  def originated_from
    @originated_from
  end

  def parent_rmq
    @_parent_rmq
  end
  def parent_rmq=(value)
    #debug.assert(value.is_a?(RMQ) || value.nil?, 'Invalid parent_rmq', { value: value })
    @_parent_rmq = value
  end

  # Do not use
  def selected=(value)
    @_selected = value
    @selected_dirty = false
  end

  def root?
    # TODO broken
    (selected.length == 1) && (selected.first == @originated_from)
  end

  def originated_from_or_its_view
    if @originated_from.is_a?(Potion::Activity) || @originated_from.is_a?(PMScreen)
      @originated_from.root_view
    else
      @originated_from
    end
  end

  def get
    sel = self.selected
    if sel.length == 1
      sel.first
    else
      sel
    end
  end

  def origin_views
    if pq = self.parent_rmq
      pq.selected
    else
      root_view
    end
  end

  def wrap(*views)
    views = [views] unless views.is_a?(Potion::Array) # TODO, WTF?

    views.flatten!
    views.select!{ |v| v.is_a?(Potion::View) } # TODO Fake view here
    RMQ.create_with_array_and_selectors(views, views, views.first, self)
  end

  def log(opt = nil)
    if opt == :tree
      mp tree_to_s(selected)
      sleep 0.1 # Hack, TODO, fix async problem
    end

    wide = (opt == :wide)
    out =  "\n id          | class                 | style_name              | frame                                 |"
    out << "\n" unless wide
    out <<   " sv id       | superview             | subviews count          | tags                                  |"
    line =   " - - - - - - | - - - - - - - - - - - | - - - - - - - - - - - - | - - - - - - - - - - - - - - - - - - - |\n"
    out << "\n"
    out << line.chop if wide
    out << line

    selected.each do |view|
      out << " #{view.object_id.to_s.ljust(12)}|"
      name = view.short_class_name
      name = name[(name.length - 21)..name.length] if name.length > 21
      out << " #{name.ljust(22)}|"
      out << " #{""[0..23].ljust(24)}|" # TODO change to real stylname
      #out << " #{(view.style_name || '')[0..23].ljust(24)}|" # TODO change to real stylname

      s = ""
      #if view.origin
        #format = '#0.#'
        s = " {l: #{view.x}"
        s << ", t: #{view.y}"
        s << ", w: #{view.width}"
        s << ", h: #{view.height}}"
      #end
      out << s.ljust(39)
      out << '|'
      out << "\n" unless wide
      out << " #{view.superview.object_id.to_s.ljust(12)}|"
      out << " #{(view.superview ? view.superview.short_class_name : '')[0..21].ljust(22)}|"
      out << " #{view.subviews.length.to_s.ljust(23)} |"
      #out << "  #{view.subviews.length.to_s.rjust(8)} #{view.superview.short_class_name.ljust(20)} #{view.superview.object_id.to_s.rjust(10)}"
      out << " #{"".ljust(38)}|"
      #out << " #{view.rmq_data.tag_names.join(',').ljust(32)}|"
      out << "\n"
      out << line unless wide
    end

    mp out
    sleep 0.1 # Hack, TODO, fix async problem
  end
  def tree_to_s(selected_views, depth = 0)
    out = ""

    selected_views.each do |view|
      if depth == 0
        out << "\n"
      else
        0.upto(depth - 1) do |i|
          out << (i == (depth - 1) ? '    ├' : '    │')
        end
      end

      out << '───'

      out << " |ROOT| -> " unless view.superview
      out << " #{view.short_class_name[0..21]}"
      out << "  ( #{view.rmq_data.style_name[0..23]} )" if view.rmq_data.style_name
      out << "  #{view.object_id}"
      #out << "  [ #{view.rmq_data.tag_names.join(',')} ]" if view.rmq_data.tag_names.length > 0

      #if view.origin
        #format = '#0.#'
        s = " {l: #{view.x}"
        s << ", t: #{view.y}"
        s << ", w: #{view.width}"
        s << ", h: #{view.height}}"
        out << s
      #end

      out << "\n"
      out << tree_to_s(view.subviews, depth + 1)
    end

    out
  end

  def inspect
    out = "RMQ. #{self.count} selected. selectors: #{self.selectors}. .log for more info"
    #out = "RMQ #{self.object_id}. #{self.count} selected. selectors: #{self.selectors}. .log for more info"
    out << "\n[#{selected.first}]" if self.count == 1
    out
  end

  def selected
    if @selected_dirty
      @_selected = []

      if RMQ.is_blank?(self.selectors)
        @_selected << originated_from_or_its_view
      else
        working_selectors = self.selectors.dup
        extract_views_from_selectors(@_selected, working_selectors)

        unless RMQ.is_blank?(working_selectors)
          subviews = all_subviews_for(root_view)
          subviews.each do |subview|
            @_selected << subview if match(subview, working_selectors)
          end
        end

        @_selected.uniq!
      end

      @selected_dirty = false
    else
      @_selected ||= []
    end

    @_selected
  end

  def extract_views_from_selectors(view_container, working_selectors)
    unless RMQ.is_blank?(working_selectors)
      working_selectors.delete_if do |selector|
        if selector.is_a?(Potion::View)
          view_container << selector
          true
        end
      end
    end
  end

  def all_subviews_for(view)
    out = []

    view.subviews.each do |subview|
      out << subview
      out << all_subviews_for(subview)
    end
    out.flatten!
    out
  end

  def all_superviews_for(view, out = [])
    if (sv = view.superview)
      out << sv
      all_superviews_for(sv, out)
    end
    out
  end

end # RMQ

__END__

findViewById(android.R.id.content) returns the View that hosts the content you supplied in setContentView().
  Beyond that, try getRootView() (called on any View) to retrieve "the topmost view in the current view hierarchy".



we_care_about_this = getWindow.getDecorView.findViewById(Android::R::Id::Content)`
now we can traverse:
`we_care_about_this.getChildCount` and `we_care_about_this.getChildAt(0)`


 Activity host = (Activity) view.getContext()

2. view.isFocused()