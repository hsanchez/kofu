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
  
  ERRORED   = "errored"
  FAILED    = "failed"
  PASSED    = "passed"
  CANCELED  = "canceled" 
  
  class InvalidLine < StandardError; end  
  
  # Travis CI status monitor
  # monitor = Monitor.new
  # line = ...
  # begin
  #   monitor.started(line)
  #   monitor.succeded(line)
  # rescue InvalidLine => e
  #   monitor.failed(line)
  # end
  # return monitor.data
  class Monitor
    
    def initialize (lang = "all", verbose = false)
      @data     = Hash.new
      @verbose  = verbose
      @lang     = lang
      @keys     = Hash.new
      
      if @verbose
        @patterns = []
        @stats    = Hash.new
      
        @stats[:java]  = Hash.new
        @stats[:ruby]  = Hash.new
      
        @stats[:java][:count]  = 0
        @stats[:ruby][:count]  = 0
      
        @stats[:java][:size] = []
        @stats[:ruby][:size] = []
      
        @stats[:total] = 0
      end
    end
    
    # Public: key seen before?
    def skip(line)
      project = line[:gh_project_name]
      branch  = line[:git_branch]
    
      key = {
        name:   project, 
        branch: branch
      }
      
      @data.key?(key)
    end
    
    # Public: starts the reading of a line  
    def started (line)
      
      project = line[:gh_project_name]
      branch  = line[:git_branch]
      pl      = line[:gh_lang]
      status  = line[:tr_status]
            
      key = {
        name:   project, 
        branch: branch
      }
            
      # Skips the line if the travis build programming 
      # language is different than the programming 
      # language requested by the user. 
      raise InvalidLine, "Skip line" if pl != @lang && @lang != "all"
      
      # Skips line if the status of the travis build 
      # is a canceled status
      raise InvalidLine, "Skip line" if status == CANCELED
      
      
      if !@keys.key?(key) # not visisted key yet!        
        
        @keys[key] = []
        
        if @verbose
          @stats[:total] += 1 # counts only not seen projects
          
          if @patterns.size > 1 && @patterns.last == "p"
            puts "recorded: #{@patterns}"
            @patterns.clear
          end
        end
        
        
        # Skips line if the first status of the travis build
        # is a passed status
        raise InvalidLine, "Skip line" if status == PASSED
        
      else
      
        # Skips line if the first status of the travis build
        # is a passed status
        raise InvalidLine, "Skip line" if status == PASSED && @keys[key].empty?  
      end
            
    end 
    
    # Public: succeded the reading of a line
    def succeded(line)
      build = Hash.new
      
      build[:project] = line[:gh_project_name]
      build[:branch]  = line[:git_branch]
      build[:lang]    = line[:gh_lang]
      
      key = {
        name:   build[:project], 
        branch: build[:branch]
      }
      
      build[:build]  = Kofu.ensure_value(line[:tr_build_id])
      build[:jobid]  = line[:tr_job_id] # useful for building log url 
      build[:status] = line[:tr_status]
      
      build[:started]    = Kofu.ensure_value(line[:tr_started_at])
      build[:commit]     = line[:git_commit]     
          
      build[:commiturl]  = "#{API}#{build[:project]}#{COMMITS}#{build[:commit]}"
      build[:buildurl]   = "#{TRAVIS}#{build[:jobid]}#{LOGS}"
      
      if @keys[key].any?
      
        base  = @keys[key][-1][:commit]
        head  = build[:commit]        
      
        # compare the previous commit to this new one
        build[:patchurl] = "#{API}#{build[:project]}#{COMPARE}#{base}...#{head}"
      else
      
        base          = build[:branch]
        head          = build[:commit]        
      
        # compare the branch to this new commit
        build[:patchurl] = "#{API}#{build[:project]}#{COMPARE}#{base}...#{head}"
      end
      
      @keys[key].push(build) 
            
      if @verbose
        @patterns.push(build[:status][0,1])
      end      
      
      # stop accepting entries and create new record
      if build[:status] == PASSED         
        
        if @verbose
          @stats[:java][:count] += 1 if build[:lang] == "java"
          @stats[:ruby][:count] += 1 if build[:lang] == "ruby"  
        
          if @patterns.size > 1
            @stats[:java][:size].push(@patterns.size) if build[:lang] == "java"
            @stats[:ruby][:size].push(@patterns.size) if build[:lang] == "ruby"
          end
                
        end
        
        if !@data.key?(key) # lazy updating
          @data[key] = []        
        end
        
        @data[key].push(@keys[key])
        
      end
      
    end 
    
    def overview
      if @verbose
        total_recs = @stats[:total]
        puts "Number of processed records: #{total_recs}"
      
        @stats.each do |k, v|
          next if k == :total
          next if v[:size].empty?
        
          if !v[:size].empty?
              
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
      else
        puts "Nothing to report"
      end  
    end
    
    def failed (line)      
      if @verbose 
        puts "ignored: #{@patterns}" if !@patterns.empty?
      end
      
      line
    end
    
    def data
      @data
    end
  end
  
  
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
    file    = File.join(File.dirname(__FILE__), filename)

    unless verbose
      puts "Processing #{filename} ... This will take a few minutes."
    end
    
    
    monitor = Monitor.new(lang, verbose)
            
    CSV.foreach(file, :headers => true, :header_converters => :symbol) do |line| 

      next if monitor.skip(line)
      
      begin
      
        # preconditions checking + some var initialization
        monitor.started(line)
        
        # line recording
        monitor.succeded(line)
      
      rescue InvalidLine => e
        monitor.failed(line) 
      end
      
    end
    
    monitor.overview
    
    monitor.data
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