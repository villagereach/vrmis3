module Enumerable
  def count_by(&block)
    counts = Hash.new do |hash, key| hash[key] = 0 end
    each do |i| counts[yield(i)] += 1; end
    counts
  end
  
  def partition_by(&block)
    self.inject([]) do |partitions, i|
      p = yield i
      if !partitions.empty? && p == partitions[-1][0]
        partitions[-1][1] << i        
      else
        partitions << [p, [i]]
      end
      partitions
    end
  end

  def map_with_index(&block)    
    idx = -1
    map do |i| yield i, idx += 1; end 
  end

  def flatten_once
    inject { |a,b| a + b } || []
  end
  
  def self.multicross(*e)
    cc = e.pop.map { |i| [i] }
    
    e.reverse.each do |aa|
      cc = aa.map { |n| cc.map { |c| c + [n] } }.inject { |a,b| a + b }
    end
    
    cc.map(&:reverse)
  end
  
  def transpose_hashes    
    keys = first.maybe.keys || []
    data = self.map { |e| e.values_at(*keys) }
    Hash[*keys.zip(data.transpose).flatten_once]
  end
end



if ![].respond_to?(:shuffle)
  class Hash
    def count
      keys.length
    end
  end
  
  class Array
    def count
      length
    end

    def shuffle
      map { |a| [a, Kernel.rand()] }.
        sort_by { |a, r| r }.
        map { |a, r| a }
    end
  end
end

module ActiveRecord
  class Base
    def self.to_sql(options = {})
      construct_finder_sql(options)
    end
    
    def current_user
      self.class.current_user
    end
    
    def self.current_user
      Thread.current[:current_user]
    end
    
    def self.current_user=(c)
      Thread.current[:current_user] = c
    end
    
    def self.acts_as_stat_tally
      include ActsAsStatTally
    end

    def self.acts_as_visit_model
      include ActsAsVisitModel
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      def disable_referential_integrity(&block)
        execute "SET CONSTRAINTS ALL DEFERRED"
        yield
        execute "SET CONSTRAINTS ALL IMMEDIATE"
      end
    end
  end
end


