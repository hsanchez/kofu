#!/usr/bin/ruby
# Copyright Huascar Sanchez, 2016. 

require 'csv'
require 'fileutils'
require 'optparse'
require 'descriptive_statistics'

# Kōfu (or Miner in Japanese) -- Travis CI dataset Miner
module Kofu 
  extend self
  
  VERSION = '0.0.1'
  API     = "https://api.github.com/repos/"
  COMMITS = "/git/commits/"
  COMPARE = "/compare/"

  # Travis stuff
  TRAVIS  = "https://api.travis-ci.org/jobs/" # + jobid
  LOGS    = "/log.txt"
  DEBUG   = false
  
  PASSED    = "passed"
  CANCELED  = "canceled" 
  
  # Public: It dumps the collected records to either the screen
  # or a file named results.csv (default behavior).
  #
  # records   - an array of collected records
  # to_file   - prints results to a file named results.csv
  #
  # Returns the records instance (useful for post processing)
  def dump(records, to_file = false)
    if to_file
      Kofu.to_csv(records)
    else
      Kofu.to_screen(records)
    end
    records
  end  
  
  # Public: Process a CSV file and then returns an array of records
  # @param filename name of csv file
  # Returns an array of records indexed by repository name
  def process(filename, lang, verbose = false)
    # hash consisting of an array of arrays
    records = Hash.new
    file    = File.join(File.dirname(__FILE__), filename)
    
    visited = []
        
    branches = Hash.new
    
    unless verbose
      puts "Processing #{filename} ... This will take a few minutes."
    end
    
    repos = Hash.new
    
    if verbose
      entry = []
      stats = Hash.new
      stats[:java]  = Hash.new
      stats[:ruby]  = Hash.new
      
      stats[:java][:count]  = 0
      stats[:ruby][:count]  = 0
      
      stats[:java][:size] = []
      stats[:ruby][:size] = []
      
      stats[:total] = 0
    end
    
    CSV.foreach(file, :headers => true, :header_converters => :symbol) do |line|      
      build       = Hash.new
      repository  = line[:gh_project_name]  
      
      build[:branch]  = line[:git_branch]
      build[:lang]    = line[:gh_lang]      
      
      next if build[:lang] != lang && lang != "all"
      
      if verbose
        stats[:total] += 1
      end
      
      key = {
        name:   repository, 
        branch: build[:branch]
      }
      
      # puts key
      # print "Not seen before? #{!visited.include?(key)} == true"
      # print ":["
      # puts "Nil repos? #{repos[repository].nil?}"
          
      if !visited.include?(key) # repository
        
        repos[key]  = []
        # print "Initiated"
        # print "]"
        # puts ""
        
        # Skip first status of a build if that status
        # is a passed status
        next if line[:tr_status] == PASSED
        
        visited.push(key)
        
        if verbose
          if entry.size > 1 && entry.include?("p")
            puts "#{entry}"
            entry.clear
          end
        end
      # else
      #   print "Initiated"
      #   print "]"
      #   puts ""
      end 
      
      # puts "Nil repos? #{repos[repository].nil?}"
    
      build[:build]  = Kofu.ensure_value(line[:tr_build_id])
      build[:jobid]  = line[:tr_job_id] # useful for building log url 
      build[:status] = line[:tr_status] 
    
      # Ignores status of a build if that status
      # is a canceled status
      next if build[:status] == CANCELED
    
      build[:started]    = Kofu.ensure_value(line[:tr_started_at])
      build[:commit]     = line[:git_commit]     
          
      build[:commiturl]  = "#{API}#{repository}#{COMMITS}#{build[:commit]}"
      build[:buildurl]   = "#{TRAVIS}#{build[:jobid]}#{LOGS}"
    
      if repos[key].any?
      
        base  = repos[key][-1][:commit]
        head  = build[:commit]        
      
        # compare the previous commit to this new one
        build[:patchurl] = "#{API}#{repository}#{COMPARE}#{base}...#{head}"
      else
      
        base          = build[:branch]
        head          = build[:commit]        
      
        # compare the branch to this new commit
        build[:patchurl] = "#{API}#{repository}#{COMPARE}#{base}...#{head}"
      end
                        
      repos[key].push(build)
    
      if verbose
        entry.push(build[:status][0,1])
      end
          
      if build[:status] == PASSED   
      
        if verbose
          stats[:java][:count] += 1 if build[:lang] == "java"
          stats[:ruby][:count] += 1 if build[:lang] == "ruby"  
        
          if entry.size > 1
            stats[:java][:size].push(entry.size) if build[:lang] == "java"
            stats[:ruby][:size].push(entry.size) if build[:lang] == "ruby"
          end
                
        end
             
        visited.delete(key)
    
        if !records.key?(key)
          records[key] = []        
        end

        records[key].push(repos[key])
    
        repos.delete(key)        
      end
      
    end
    
    if DEBUG
      puts "collected #{records.size} records"
    end
    
    if verbose
      total_recs = stats[:total]
      puts "Number of processed records: #{total_recs}"
      
      stats.each do |k, v|
        next if k == :total
      
        puts "Number of #{k} ([errored|failed]+[passed]) patterns: #{v[:count]}"
        puts "(Additional) details:"
        puts "Basic stats using the size of collected patterns:"
        
        mean = ("%.2f" % v[:size].mean).to_f
        min  = v[:size].min
        max  = v[:size].max
        stdv = v[:size].standard_deviation
        
        puts "min: #{min}, mean: #{mean}, max: #{max}, stdv: #{stdv}"
      end
    end
  
    # [repo_0: [data, data], repo_1: [data, data], ..., repo_N: [data, data]]
    records
  end
  
  # Internal: Prints all collected records to screen
  #
  # A record is made of an array of snapshots and  
  # each snapshot is an array of build attempts. 
  # e.g., record A = [snapshot1,..., snapshotN] and 
  # snapshot1 = [build1, ..., buildN]
  #
  def to_screen(records)
    
    header    = false
    headers   = []
    
    records.each do |key, value| # maps a repo to an array of snapshots
      
      name      = key
      snapshots = value

      snapshots.each do |s| # an array of snapshots
        unless s.size <= 1
          s.each do |build| # an array of build attempts
            unless header
              headers.push(:repository)
              headers = headers | build.keys
              puts headers.join(',')
            end
            values = [key]
            values = values | build.values
            puts values.join(',')
            header = true
          end
        end
      end
    end
  end  
  
  # Internal: It writes records to a csv file
  #
  # records - array of records
  # verbose - verbose mode
  # filename - name of file
  #
  # Returns nothing
  def to_csv(records, filename = 'result.csv')
    header    = false
    headers   = []

    if File.exists?(filename)
      FileUtils.rm(filename)
    end

    CSV.open(filename, 'wb') do |csv|
      
      records.each do |key, value| # maps a repo to an array of snapshots
      
        name      = key
        snapshots = value

        snapshots.each do |s| # an array of snapshots
          unless s.size <= 1
            s.each do |build| # an array of build attempts
              unless header
                headers.push(:repository)
                headers = headers | build.keys
                csv << (headers.map {|k| k.to_s}).to_a
              end
              values = [key]
              values = values | build.values
              csv << values
              header = true
            end
          end
        end
      end
    end

  end
  
  # Private: Ensure nil string values are blank values.
  #
  # Returns Either a blank value or a non nil string value
  def ensure_value(value, orElse = "")
    value.nil? ? orElse : value
  end
  
end