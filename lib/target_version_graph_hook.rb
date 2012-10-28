# Provides a graph on the target version page
class TargetVersionGraphHook < Redmine::Hook::ViewListener
  def view_versions_show_bottom(context = { })
    context[:controller].send(:render_to_string, {
      :partial => 'hooks/redmine_graphs/view_versions_show_bottom',
      :locals => context})
  end
end
