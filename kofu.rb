#!/usr/bin/ruby
# Copyright Huascar Sanchez, 2016. 

require 'csv'
require 'fileutils'
require 'optparse'

# Kōfu (or Miner in Japanese) -- Travis CI dataset Miner
class Kofu
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
  def self.dump(records, to_file = false)
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
  def self.process(filename, verbose = false)
    # hash consisting of an array of arrays
    records = Hash.new
    file    = File.join(File.dirname(__FILE__), filename)
    
    visited = []
    
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
      
      if verbose
        stats[:total] += 1
      end
    
      if !visited.include?(repository)
        repos[repository]  = []
        
        # Skip first status of a build if that status
        # is a passed status
        next if line[:tr_status] == PASSED
        
        visited.push(repository)
        
        if verbose
          if entry.size > 1
            puts "#{entry.size}: #{entry}"
            entry.clear
          end
        end
      end        
      
      build[:build]  = Kofu.ensure_value(line[:tr_build_id])
      build[:jobid]  = line[:tr_job_id] # useful for building log url 
      build[:status] = line[:tr_status] 
      
      # Ignores status of a build if that status
      # is a canceled status
      next if build[:status] == CANCELED
      
      build[:started]    = Kofu.ensure_value(line[:tr_started_at])
      build[:lang]       = line[:gh_lang]
      build[:commit]     = line[:git_commit]   
      build[:branch]     = line[:git_branch]  
            
      build[:commiturl]  = "#{API}#{repository}#{COMMITS}#{build[:commit]}"
      build[:buildurl]   = "#{TRAVIS}#{build[:jobid]}#{LOGS}"
      
      if repos[repository].any?
        
        base  = repos[repository][-1][:commit]
        head  = build[:commit]        
        
        # compare the previous commit to this new one
        build[:patchurl] = "#{API}#{repository}#{COMPARE}#{base}...#{head}"
      else
        
        base          = build[:branch]
        head          = build[:commit]        
        
        # compare the branch to this new commit
        build[:patchurl] = "#{API}#{repository}#{COMPARE}#{base}...#{head}"
      end
                    
      repos[repository].push(build)
      
      if verbose
        entry.push(build[:status][0,1])
      end
            
      if build[:status] == PASSED   
        
        if verbose
          stats[:java][:count] += 1 if build[:lang] == "java"
          stats[:ruby][:count] += 1 if build[:lang] == "ruby"  
          
          stats[:java][:size].push(entry.size) if build[:lang] == "java"
          stats[:ruby][:size].push(entry.size) if build[:lang] == "ruby"
                  
        end
               
        visited.delete(repository)
      
        if !records.key?(repository)
          records[repository] = []        
        end

        records[repository].push(repos[repository])
      
        repos.delete(repository)        
      end
    end
    
    if DEBUG
      puts "collected #{records.size} records"
    end
    
    if verbose
      stats.each do |k, v|
        next if k == :total
        
        puts "For #{k}:"
        puts "Number of patterns: #{v[:count]} -- #{v[:count].to_f/stats[:total]} of #{stats[:total]} records"
        
        sorted = v[:size].sort
        puts "patterns size:"
        puts "min: #{sorted.first}, avg: #{sorted.inject{ |sum, el| sum + el }.to_f / sorted.size}, max: #{sorted.last}"
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
  def self.to_screen(records)
    
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
  def self.to_csv(records, filename = 'result.csv')
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
  def self.ensure_value(value, orElse = "")
    value.nil? ? orElse : value
  end
  
end


if __FILE__ == $0
  
  options = {}  
  
  kofu = OptionParser.new do |opt|
    opt.banner = "Usage: kofu COMMAND [OPTIONS]"
    opt.separator  ""
    opt.separator  "Commands"
    opt.separator  "     process: process csv file"
    opt.separator  ""
    opt.separator  "Options"
    
    opt.on("-f","--file FILE","the csv file to process") do |file|
      options[:file] = file 
    end
  
    opt.on("-p","--patterns","disclose build attempt patterns") do
      options[:patterns] = true
    end
  
    opt.on("-h","--help","help") do 
      puts kofu
    end
  end
  
  kofu.parse!
  
  case ARGV[0]
   when "process"
     file = options[:file].nil? ? 'data.csv' : options[:file]     
     
     if options[:patterns].nil?
       Kofu.dump(Kofu.process(file))
     else
       Kofu.process(file, options[:patterns])
     end
    else
      puts kofu
    end

end