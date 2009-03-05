# Provides a graph on the target version page
class TargetVersionGraphHook < Redmine::Hook::ViewListener
  def view_versions_show_bottom(context = { })
  	if !context[:version].fixed_issues.empty?
		return tag("embed", :width => 800, :height => 300, :type => "image/svg+xml", :src => url_for(:controller => 'graphs', :action => 'target_version', :id => context[:version]))
	end 
  end
end