require 'SVG/Graph/TimeSeries'

class GraphsController < ApplicationController


	before_filter :find_version, :only => [:target_version]


	def target_version

		# Initialize the graph
		graph = SVG::Graph::TimeSeries.new({
			:width => 800,
			:height => 300,
			:graph_title => l(:label_graphs_total_vs_closed_issues),
			:show_graph_title => true,
			:no_css => true,
			:key => true,
			:scale_x_integers => true,
			:scale_y_integers => true,
			:show_x_guidelines => true,
			:stagger_x_labels => true,
			:show_data_points => false,
			:show_data_values => false,
			:area_fill => true,
			:x_label_format => "%b %d",
			:style_sheet => "/plugin_assets/redmine_graphs/stylesheets/target_version.css"
		})

		# Group issues
	  	issues_by_created_on = @version.fixed_issues.group_by {|issue| issue.created_on.to_date }
		issues_by_updated_on = @version.fixed_issues.group_by {|issue| issue.updated_on.to_date }
		issues_by_closed_on = @version.fixed_issues.collect { |issue| issue if issue.closed? }.compact.group_by {|issue| issue.updated_on.to_date }
	  		  	
	  	# Set the scope of the graph
	  	scope_end_date = issues_by_updated_on.sort.keys.last
	  	scope_end_date = @version.effective_date if !@version.effective_date.nil? && @version.effective_date > scope_end_date
	  	line_end_date = Date.today
	  	line_end_date = scope_end_date if scope_end_date < line_end_date
	  		  	
		# Generate the created_on line
		created_count = 0
		created_on_line = Hash.new
	  	issues_by_created_on.sort.each { |created_on, issues| created_on_line[(created_on-1).to_s] = created_count; created_count += issues.size; created_on_line[created_on.to_s] = created_count }
	  	created_on_line[scope_end_date.to_s] = created_count
	  	graph.add_data({
			:data => created_on_line.sort.flatten,
			:title => l(:label_issue_plural)
	    })
	    
		# Generate the closed_on line
		closed_count = 0
	  	closed_on_line = Hash.new
	  	issues_by_closed_on.sort.each { |closed_on, issues| closed_on_line[(closed_on-1).to_s] = closed_count; closed_count += issues.size; closed_on_line[closed_on.to_s] = closed_count }
	  	closed_on_line[line_end_date.to_s] = closed_count
	    graph.add_data({
			:data => closed_on_line.sort.flatten,
			:title => "#{l(:label_issue_plural)} #{l(:label_closed_issues)}"
	    })
	    
	    # Compile the graph
		headers["Content-Type"] = "image/svg+xml"
		send_data(graph.burn, :type => "image/svg+xml", :disposition => "inline")
	end
	
	
	private
	
	
	def find_version
		@version = Version.find(params[:id])
		deny_access unless User.current.allowed_to?(:view_issues, @version.project)
	rescue ActiveRecord::RecordNotFound
		render_404
	end
end