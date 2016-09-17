#!/usr/bin/ruby
# Copyright Huascar Sanchez, 2016. 

require 'csv'
require 'fileutils'


# Kōfu or Miner of Travis repositories
class Kofu
  VERSION = '0.0.1'
  
  # Public:
  #
  # Returns an array of records
  def self.process(filename)
    records = []
    file = File.join(File.dirname(__FILE__), filename)
    
    channel  = Hash.new
    
    CSV.foreach(file, :headers => true, :header_converters => :symbol) do |line|
      data = Hash.new
      
      data[:project]  = line[:GH_PROJECT_NAME]
      
      # initialize channel bus
      unless channel.key?(data[:project])
        channel[data[:project]] = []
      else

        data[:build]    = line[:TR_BUILD_ID]  
        data[:status]   = line[:TR_STATUS]
        
        if (data[:status] != "passed")
          data[:before] = "https://api.github.com/repos/#{data[:project]}/git/commits/#{line[:GIT_COMMIT]}"
        else
          data[:after]  = "https://api.github.com/repos/#{data[:project]}/git/commits/#{line[:GIT_COMMIT]}" 
        end
        
        if channel.key?(data[:after])
          data[:diff] = 
        end
            
        data[:started]  = line[:TR_STARTED_AT]
        data[:lang]     = line[:GH_LANG]
        
        channel[data[:project]].push(data)
      end
      
      if (data[:status] == "passed")
        data[:after] = 
      end
      
      record.push(data)      
    end
  
    records
  end
  
  # Public:
  # Returns the diff between two commits
  def self.diff(ca, cb)
  end
  
end
