class Autoeval
  attr_reader :user, :health_centers

  def initialize(u, health_centers)
    @user = u

    date_periods = (0..6).map { |n| n.months.ago.to_date_period }
    ids = health_centers.map(&:id)

    @health_centers = HealthCenter.find(:all,
      :include => [:health_center_visits],
      :conditions => { 'health_center_visits.visit_month' => date_periods, 'health_centers.id' => ids }
    )
  end

  def statements(hc)
    all_statements[hc]
  end

  def all_statements
    @stmts ||= begin
      stmts = (stockouts_this_month +
        not_recently_visited +
        stockouts_this_month_full_delivery_last_month +
        insufficient_deliveries +
        excessive_interval)
      Hash[ *stmts.group_by(&:first).map { |hc, ss| [hc, ss.map { |sss| sss[1..-1] } ] }.flatten_once ]
    end
  end


  def not_recently_visited
    health_centers.
      map    { |hc|          [hc, [hc.visits[-1], hc.excusable_non_visits[-1]].compact.map(&:visit_month).max] }.
      map    { |hc, last_ok| [hc, last_ok.nil? ? -1 : (Date.today - Date.from_date_period(last_ok)).to_i * 1.day / 1.month] }.
      select { |hc, months|  months >= 3 }.
      map    { |hc, months|  [hc, 'not_recently_visited', { :months => months }]}
  end

  def excessive_interval
    health_centers.
      select { |hc|       hc.visits.size > 1 && hc.visits[-1].visit_month == current_date_period }.
      map    { |hc|       [hc, (hc.visits[-1].visited_at - hc.visits[-2].visited_at).to_i.abs] }.
      select { |hc, days| days >= 34 }.
      map    { |hc, days| [hc, 'excessive_interval', { :days => days }]}
  end

  def stockouts_this_month
    health_centers.
      select { |hc| hc.visits.size > 0 }.
      map    { |hc| [hc, stockouts_by_period_product[current_date_period].select { |k,v| v[hc.id] && v[hc.id][0] }.map { |k,v| k }] }.
      map    { |hc, product_ids| [hc, product_ids.select { |i| (!stockouts_by_period_product[previous_date_period][i][hc.id][1]) rescue true }] }.
      map    { |hc, product_ids| Product.find(product_ids).map { |p| 
                                  [ hc, 'stockouts_this_month', 
                                    { :date => I18n.l(Date.from_date_period(current_date_period), 
                                                      :format => :short_month_of_year),
                                      :product => p.label } ] } }.
      flatten_once
  end

  def stockouts_this_month_full_delivery_last_month
    health_centers.
      select { |hc| hc.visits.size > 0 }.
      map    { |hc| [hc, stockouts_by_period_product[current_date_period ].select { |k,v| v[hc.id] && v[hc.id][0] }.map { |k,v| k }] }.
      map    { |hc, product_ids| [hc, product_ids.select { |i| stockouts_by_period_product[previous_date_period][i][hc.id][1] rescue false }] }.
      map    { |hc, product_ids| Product.find(product_ids).map { |p| [ hc, 'stockouts_this_month_full_delivery_last_month', { :product => p.label } ] } }.
      flatten_once
  end

  def insufficient_deliveries
    health_centers.
      select { |hc| hc.visits.size > 0 }.
      map    { |hc| [hc, stockouts_by_period_product[current_date_period ].select { |k,v| v[hc.id] && !v[hc.id][1] }.map { |k,v| k }] }.
      map    { |hc, product_ids| [hc, product_ids.select { |i| !(stockouts_by_period_product[previous_date_period][i][hc.id][1]) rescue true }] }.
      map    { |hc, product_ids| Product.find(product_ids).map { |p| [ hc, 'insufficient_deliveries', { :product => p.label } ] } }.
      flatten_once
  end

  private

  def current_date_period
    @current ||= Time.now.to_date_period
  end

  def previous_date_period
    @previous ||= 1.month.ago.to_date_period
  end

  def stockouts_by_period_product
    @stockouts_by_period_product ||= begin

      results = Queries.stockouts_by_area_date_period_range(
        Product.trackable.all,
        health_centers.select { |hc| hc.visited_in?(current_date_period) },
        [previous_date_period, current_date_period],
        true)

      stockouts = { previous_date_period => {}, current_date_period => {} }

      results.each do |r|
        stockouts[r['date_period']][r['product_id'].to_i] ||= {}
        stockouts[r['date_period']][r['product_id'].to_i][r['health_center_id'].to_i] ||= []

        if r['stockouts'].to_i > 0
          stockouts[r['date_period']][r['product_id'].to_i][r['health_center_id'].to_i][0] = r['stockouts'].to_i
        end

        if r['full_deliveries'].to_i > 0
          stockouts[r['date_period']][r['product_id'].to_i][r['health_center_id'].to_i][1] = r['full_deliveries'].to_i
        end
      end
      stockouts
    end
  end


  #* [A health center] had [a table] with [2 or more] “I don’t know” or “NR” answers. Unclear if this is relevant. We think the completeness concept is better. So, might instead use % complete for HCs in delivery zone for a multi-month period, building off of the new model.
  #  *
  #  * [A health center] had [at least 3] refrigerator problems in the last 6 months. Please follow up to resolve this problem.
  #  * All the [PAV or delivery data] stock questions this month for [a health center] had identical answers as last month. Please verify that this data is correct.
  #  * [A health center] had a [piece of equipment] that was not working for [3 or more] months in a row.
  #  * A health center] had no vaccine or syringe stockouts for [2 or more] months. Great job!
  #  * [A health center’s] forms were fully filled out for [3 or more] months. Well done! eclipsed by the completion ratio – need to turn that into easy phrases.
  #  * Well done! [A health center] had all equipment in working order for [6 or more] months.
  #  * [A health center] was visited every month for [at least 6] months. Good work!
  #  * Great job! [A health center] experienced no refrigerator problems for [at least 6] months.


end
