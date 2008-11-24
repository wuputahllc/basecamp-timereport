#!/usr/bin/env ruby

# fetch.rb - Fetches all time data from Basecamp (that you have access to) for a
# given time period and gives you a summarized report in a number of categories.
#
# In order to use this, you must set the following ENV variables:
#   BASECAMP_URL BASECAMP_USERNAME BASECAMP_PASSWORD
#
# Instead of launching this directly, put your setting in the 'fetch' shell script
# which is a wrapper to this program. This way, your info is not permanently in
# your shell environment.
#
# Example usage:
#   ./fetch.rb 2008-11-01 2008-11-15
#
# You must provide the start date. The end date defaults to today if not provided.

# Yes, this code is not all that pretty - this was primarily a mental exercise.
# Primarily, this was outputting all the output in a single expression at the
# end.

require 'basecamp'
require 'date'

class Object; def with(obj=self) yield(obj); obj; end; end
class Object; def chain(obj=self) yield(obj); end; end

def header(txt = nil, chr = '=')
  return chr * 60 if txt.nil?
  extra = 60 - (txt.length + 2)
  chr * (extra / 2 + (extra.odd? ? 1 : 0)) << " " << txt << " " << chr * (extra / 2)
end

%w[BASECAMP_URL BASECAMP_USERNAME BASECAMP_PASSWORD].each do |setting|
  unless ENV.has_key?(setting)
    puts "Environment variable #{setting} not set! Aborting..."
    exit
  end
end

unless ARGV.size >= 1
  puts "You must specify the start date for the report as an argument. (End date is optional, defaults to today)"
  exit
end

Basecamp.establish_connection!(ENV['BASECAMP_URL'],
                               ENV['BASECAMP_USERNAME'],
                               ENV['BASECAMP_PASSWORD'],
                               true)
start_date, end_date = ARGV.collect { |arg| Date.parse(arg) } << Date.today
basecamp = Basecamp.new

if end_date - start_date > 180
  puts "You can only run a report for 180 day periods (for now...)"
  exit
elsif end_date < start_date
  start_date, end_date = [end_date, start_date]
end

totals = { :people => Hash.new(0.0),
           :projects => Hash.new(0.0),
           :pp => Hash.new { |h, k| h[k] = Hash.new(0.0) } }
cache = { :people => { }, :projects => { } }
Basecamp::TimeEntry.report(:from => start_date.strftime('%Y%m%d'), :to => end_date.strftime('%Y%m%d')).each do |entry|
  person = cache[:people][entry.person_id] ||= basecamp.person(entry.person_id)
  project = cache[:projects][entry.project_id] ||= Basecamp::Project.find(entry.project_id)
  totals[:people][person] += entry.hours
  totals[:projects][project] += entry.hours
  totals[:pp][project][person] += entry.hours
end

# Yes, this is one expression - its ugly, but its pretty cool, too.
# No, I don't normally do things like this. :)
puts header("TIME REPORT FOR #{start_date.strftime('%Y-%m-%d')} TO #{end_date.strftime('%Y-%m-%d')}", ' '),
     header('By Person'),
     totals[:people].
       collect { |(p, h)| [ [p['last-name'], p['first-name']], h ] }.
       sort.
       collect { |(p, h)| sprintf "%-54s%6.02f" % [p.reverse.join(' '), h] }.
       join("\n"),
     header('By Project'),
     totals[:projects].
       collect { |(p, h)| [ [p.company.name, p.name], h ] }.
       sort.
       collect { |(p, h)| sprintf "%-54s%6.02f" % [p.join(' - '), h] }.
       join("\n"),
     header('By Company'),
     totals[:projects].
       inject(Hash.new(0.0)) { |hsh, (p, h)|
         hsh.with { |hh| hh[p.company.name] += h }
       }.
       sort.
       collect { |(p, h)| sprintf "%-54s%6.02f" % [p, h] }.
       join("\n"),
     header('By Person per Project'),
     totals[:pp].
       collect { |(proj, people)|
         [proj.name, people.collect { |(p, h)| [ [p['last-name'], p['first-name'] ], h ] }.
                     sort.
                     collect { |(p, h)| sprintf "  %-52s%6.02f" % [p.reverse.join(' '), h] }.
                     join("\n")]
       }.
       sort.
       flatten.
       join("\n"),
     header
