class GraphDataController < OlmisController
  unloadable

  helper :date_period_range

  def graph
    flashchart(Graphs.send(params[:graph], params))
  end
  
  private
    
  def flashchart(options = {})    
    respond_to do |format|
      format.json { render :text => Graphs.chart_to_json(options) }
      format.html { 
        response.headers['Content-Type'] = 'text/plain'
        render :text => Graphs.chart_to_csv(options)
      }
      format.csv  { render :text => Graphs.chart_to_csv(options) }
      format.jqplot { render :text => Graphs.chart_to_jqplot(options.merge({ :chart_id => params[:chart_id] })) }
    end
  end
end
