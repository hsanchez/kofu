#!/usr/bin/ruby
# Copyright Huascar Sanchez, 2016. 

require 'csv'
require 'fileutils'
require "shorturl"

# Kōfu (or Miner in Japanese) of Travis repositories
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
  
  # Public:
  # Returns the diff between two commits
  def self.compare(repository, base, head)
    url       = "#{API}#{repository}#{COMPARE}#{base}...#{head}"
    Kofu.shorten(url)
    # username  = repository[0..repository.rindex('/') - 1]
    #
    # http = Curl::Easy.perform(url) do |curl|
    #   curl.headers["User-Agent"] = username
    #   curl.verbose = true
    # end
    # http.body_str
  end  
  
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
  def self.process(filename)
    # hash consisting of an array of arrays
    records = Hash.new
    file    = File.join(File.dirname(__FILE__), filename)
    
    visited = []
    
    repos = Hash.new
    
    if DEBUG
      entry = []
    end
    
    CSV.foreach(file, :headers => true, :header_converters => :symbol) do |line|      
      build       = Hash.new
      repository  = line[:gh_project_name]    
    
      if !visited.include?(repository)
        repos[repository]  = []
        
        # Skip first status of a build if that status
        # is a passed status
        next if line[:tr_status] == PASSED
        
        visited.push(repository)
        
        if DEBUG
          if entry.size > 1
            puts "#{entry}"
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
            
      build[:commiturl]  = Kofu.shorten("#{API}#{repository}#{COMMITS}#{build[:commit]}")
      build[:log]        = Kofu.shorten("#{TRAVIS}#{build[:jobid]}#{LOGS}")
      
      if repos[repository].any?
        
        base  = repos[repository][-1][:commit]
        head  = build[:commit]        
        
        # compare the previous commit to this new one
        build[:patch] = Kofu.compare(repository, base, head)
      else
        
        base          = build[:branch]
        head          = build[:commit]        
        
        # compare the branch to this new commit
        build[:patch] = Kofu.compare(repository, base, head)
      end
                    
      repos[repository].push(build)
      
      if DEBUG
        entry.push(build[:status][0,1])
      end
            
      if build[:status] == PASSED          
        visited.delete(repository)
      
        if !records.key?(repository)
          records[repository] = []        
        end

        records[repository].push(repos[repository])
      
        repos.delete(repository)
        
        return records
      end
    end
    
    if DEBUG
      puts "collected #{records.size} records"
    end
  
    # [repo_0: [data, data], repo_1: [data, data], ..., repo_N: [data, data]]
    records
  end
  
  def self.shorten(url)
    if url.nil?
      raise ArgumentError.new("Only non nullable arguments are allowed")
    end
    
    ShortURL.shorten(url)
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
  
  Kofu.dump(Kofu.process('data.csv'), true)

end