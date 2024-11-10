# test_runner.rb

require 'bundler/setup'
Bundler.require(:default)
Dotenv.load
require 'json'
require_relative 'lib/db_connection'
require_relative 'lib/hack_fetcher'
require_relative 'lib/hack_comparator'
require_relative 'lib/report_generator'

CHANNEL_ID = 58

def run_tests(channel_id)
  # Load seed data
  seed_data = {}
  fetched_hacks = {}
  if File.exist?('data/seed_data.json')
    File.open('data/seed_data.json', 'r') do |f|
      seed_data = JSON.parse(f.read, symbolize_names: true)
    end
  else
    seed_data = HackFetcher.load_seed_data
    # puts JSON.generate(seed_data)
    File.open('data/seed_data.json', 'w') do |f|
      f.write(JSON.generate(seed_data))
    end
  end
  puts "Loaded #{seed_data.keys.size} seed hacks."
  # puts seed_data["@hermoneymastery_video_7286913008788426027"]
  
  # Fetch hacks from the database
  if File.exist?("data/fetched_hacks_#{channel_id}.json")
    File.open("data/fetched_hacks_#{channel_id}.json", 'r') do |f|
      fetched_hacks = JSON.parse(f.read, symbolize_names: true)
    end
    puts "Fetched #{fetched_hacks.size} new hacks from file."
  else
    db_connection = DBConnection.connect
    puts "Connected to DB."
    fetched_hacks = HackFetcher.fetch_hacks_from_db(db_connection, channel_id)
    puts "Fetched #{fetched_hacks.size} new hacks from the database."

    File.open("data/fetched_hacks_#{channel_id}.json", 'w') do |f|
      f.write(JSON.generate(fetched_hacks))
    end
  end
  # Compute statistics
  statistics = compute_statistics(fetched_hacks)
  puts "Computed statistics successfully. #{statistics}"

  # Run comparisons and generate reports
  result = HackComparator.compare_all_hacks(seed_data, fetched_hacks)
  comparison_results = result[0]
  seed_statistics = result[1]
  puts "Comparison completed for #{comparison_results.keys.size} hacks."
  puts "Computed seed statistics successfully. #{seed_statistics}"
  general_comparison = ""
  if File.exist?("data/general_comparison_#{channel_id}.txt")
    File.open("data/general_comparison_#{channel_id}.txt", 'r') do |f|
    general_comparison = f.read
    end
  else
    general_comparison = HackComparator.general_comparison(comparison_results, statistics, seed_statistics)
    File.open("data/general_comparison_#{channel_id}.txt", 'w') do |f|
      f.write(general_comparison)
    end
  end
  # puts general_comparison
  ReportGenerator.generate_markdown_report(comparison_results, general_comparison, statistics, seed_statistics, channel_id)
  ReportGenerator.generate_summary_report(comparison_results, general_comparison, statistics, seed_statistics, channel_id)
end

# Method to compute the required statistics
def compute_statistics(fetched_hacks)
  total_hacks = fetched_hacks.size
  hacks_is_hack_true = 0
  hacks_valid_validation = 0

  fetched_hacks.each do |hack|
    is_hack = hack[:is_hack] == true || hack[:is_hack].to_s.downcase == 't'
    next unless is_hack

    hacks_is_hack_true += 1
    has_valid_validation = hack[:hack_validations] && (hack[:hack_validations][:status] == true || hack[:hack_validations][:status].to_s.downcase == 't' )
    if has_valid_validation
      hacks_valid_validation += 1

    end
  end

  {
    total_hacks: total_hacks,
    hacks_is_hack_true: hacks_is_hack_true,
    hacks_valid_validation: hacks_valid_validation
  }
end

# Execute tests
run_tests(CHANNEL_ID)
