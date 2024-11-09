# test_runner.rb

require 'bundler/setup'
Bundler.require(:default)
Dotenv.load
require_relative 'lib/db_connection'
require_relative 'lib/hack_fetcher'
require_relative 'lib/hack_comparator'
require_relative 'lib/report_generator'

CHANNEL_IDS = [48]

def run_tests(channel_id, load=true)
  # Load seed data
  # seed_data = HackFetcher.load_seed_data
  # serialized_data_seed = Marshal.dump(seed_data)
  # File.open('seed_data.marshal', 'wb') { |file| file.write(serialized_data_seed) }
  seed_data = Marshal.load(File.read("seed_data.marshal"))
  puts "Loaded #{seed_data.keys.size} seed hacks."
  # puts seed_data["@hermoneymastery_video_7286913008788426027"]
  # Fetch hacks from the database
  if load
    db_connection = DBConnection.connect
    fetched_hacks = HackFetcher.fetch_hacks_from_db(db_connection, channel_id)
    puts "Fetched #{fetched_hacks.size} new hacks from the database."

    serialized_data_fetched = Marshal.dump(fetched_hacks)
    File.open("fetched_hacks_#{channel_id}.marshal", 'wb') { |file| file.write(serialized_data_fetched) }
  else
    fetched_hacks = Marshal.load(File.read("fetched_hacks_#{channel_id}.marshal"))
    puts "Fetched #{fetched_hacks.size} new hacks from file."
    # hash_with_id_700 = fetched_hacks.find { |hash| hash[:id] == "700"}
    # puts fetched_hacks[9]
  end
  # Compute statistics
  statistics = compute_statistics(fetched_hacks)
  puts "Computed statistics successfully. #{statistics}"

  # Run comparisons and generate reports
  comparison_results = HackComparator.compare_all_hacks(seed_data, fetched_hacks)
  puts "Comparison completed for #{comparison_results.keys.size} hacks."
  general_comparison = HackComparator.general_comparison(comparison_results, statistics)
  # puts general_comparison
  ReportGenerator.generate_markdown_report(comparison_results, general_comparison, statistics, channel_id)
  ReportGenerator.generate_summary_report(comparison_results, general_comparison, statistics, channel_id)
end

# Method to compute the required statistics
def compute_statistics(fetched_hacks)
  total_hacks = fetched_hacks.size
  hacks_is_hack_true = 0
  hacks_valid_validation = 0
  hacks_with_empty_structured_info = 0

  fetched_hacks.each do |hack|
    is_hack = hack[:is_hack] == true || hack[:is_hack].to_s.downcase == 't'
    next unless is_hack

    hacks_is_hack_true += 1
    has_valid_validation = hack[:hack_validations] && (hack[:hack_validations][:status] == true || hack[:hack_validations][:status].to_s.downcase == 't' )
    if has_valid_validation
      hacks_valid_validation += 1

      # Check if hack_structured_infos is empty
      is_structured_info_empty = hack[:hack_structured_infos].nil? || hack[:hack_structured_infos].empty?
      hacks_with_empty_structured_info += 1 if is_structured_info_empty
    end
  end

  {
    total_hacks: total_hacks,
    hacks_is_hack_true: hacks_is_hack_true,
    hacks_valid_validation: hacks_valid_validation,
    hacks_with_empty_structured_info: hacks_with_empty_structured_info
  }
end

# Execute tests
run_tests(CHANNEL_IDS, true)
