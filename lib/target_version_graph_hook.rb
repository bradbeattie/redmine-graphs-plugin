# Provides a graph on the target version page
class TargetVersionGraphHook < Redmine::Hook::ViewListener
  def view_versions_show_bottom(context = { })
  	if !context[:version].fixed_issues.empty?
  		output = "<fieldset id='target_version_graph'><legend>#{ l(:label_graphs_total_vs_closed_issues) }</legend>"
                output << "<object width=\"100%\" height=\"300\" type=\"image/svg+xml\" data=\"#{src}\">"
                output << "<img src=\"#{src}\" alt=\"#{ l(:label_graphs_total_vs_closed_issues) }\"/>"
		output << tag("embed", :width => "100%", :height => 300, :type => "image/svg+xml", :src => url_for(:controller => 'graphs', :action => 'target_version_graph', :id => context[:version]))
                output << "</object>"
		output << "</fieldset>"
		return output
	end 
  end
end
