# lib/report_generator.rb

module ReportGenerator
  REPORT_OUTPUT_DIR = 'data/reports'
  # REPORT_FILE = 'hack_comparison_report.md'

  def self.generate_summary_report(comparison_results, general_comparison, statistics, seed_statistics, channel_id)
    general_report = generate_general_report(comparison_results, general_comparison, statistics, seed_statistics, channel_id)
  
    # Now, build the report content starting with the general analysis
    report_content = general_report
    comparison_results.each do |transcription_hash, result|
      # puts result
      seed_hack_id = result["seed_id"]
      fetched_hack_id = result["fetch_id"]
      seed_hack_title = result["seed_title"]
      fetched_hack_title = result["fetch_title"]
      differences = result["differences_hash"]

      # Build the report section for this hack
      hack_report = "## Hack Report for #{seed_hack_id}\n"
      hack_report += "Original Hack: **#{seed_hack_title}**. Test Hack: **#{fetched_hack_title}**,  ID=`#{fetched_hack_id}`, Channel ID: `#{channel_id}`\n\n"
      hack_report += "**Analysis summary:**\n\n#{differences['hack']["analysis"]}"
      # Add separator between hacks
      hack_report += "\n---\n\n"
      # Append to the report content
      report_content += hack_report
    end

    # Ensure the output directory exists
    Dir.mkdir(REPORT_OUTPUT_DIR) unless Dir.exist?(REPORT_OUTPUT_DIR)

    # Write the report content to the markdown file
    report_path = File.join(REPORT_OUTPUT_DIR, "hack_comparison_summary_report_#{channel_id}.md")
    File.write(report_path, report_content)
  rescue IOError => e
    puts "Failed to write markdown report: #{e.message}"
  end

  def self.generate_markdown_report(comparison_results, general_comparison, statistics, seed_statistics, channel_id)
    general_report = generate_general_report(comparison_results, general_comparison, statistics, seed_statistics, channel_id)

    # Now, build the report content starting with the general analysis
    report_content = general_report

    comparison_results.each do |transcription_hash, result|
      seed_hack_id = result["seed_id"]
      fetched_hack_id = result["fetch_id"]
      seed_hack_title = result["seed_title"]
      fetched_hack_title = result["fetch_title"]
      differences = result["differences_hash"]

      # Build the report section for this hack
      hack_report = "## Hack Report for Original Hack ID: #{seed_hack_id} (#{seed_hack_title}). Test Hack ID: #{fetched_hack_id} (#{fetched_hack_title}), Channel ID: #{channel_id})\n\n"

      differences.each do |section, diff|
        # prompt = differences[:prompt]
        analysis = diff["analysis"]

        hack_report += "### Section: #{section.capitalize}\n"
        # hack_report += "**Prompt:**\n\n```\n#{prompt}\n```\n\n"
        hack_report += "**Analysis:**\n```\n#{analysis}\n```\n\n"
      end

      # Add separator between hacks
      hack_report += "---\n\n"

      # Append to the report content
      report_content += hack_report
    end

    # Ensure the output directory exists
    Dir.mkdir(REPORT_OUTPUT_DIR) unless Dir.exist?(REPORT_OUTPUT_DIR)

    # Write the report content to the markdown file
    report_path = File.join(REPORT_OUTPUT_DIR, "hack_comparison_report_#{channel_id}.md")
    File.write(report_path, report_content)
  rescue IOError => e
    puts "Failed to write markdown report: #{e.message}"
  end

  # Generate general analysis report with statistics
  def self.generate_general_report(comparison_results, general_comparison, statistics, seed_statistics, channel_id)
    report_content = "# Analysis of the Test\n\n"

    # Add statistics
    report_content += "## Statistics:\nTotal Hacks Compared: #{comparison_results.keys.size}\n"
    report_content += "\nStatistics of the new test:\n"
    report_content += "- Number of possible hacks: #{statistics[:hacks_is_hack_true]} (#{(statistics[:hacks_is_hack_true] / statistics[:total_hacks].to_f).round(2)})\n"
    report_content += "- Hacks Validated as Valid: #{statistics[:hacks_valid_validation]}  (#{(statistics[:hacks_valid_validation] / statistics[:total_hacks].to_f).round(2)})\n"
    report_content += "\nStatistics of the old hacks:\n"
    report_content += "- Number of possible hacks: #{seed_statistics[:hacks_is_hack_true]} (#{(seed_statistics[:hacks_is_hack_true] / seed_statistics[:total_hacks].to_f).round(2)})\n"
    report_content += "- Hacks Validated as Valid: #{seed_statistics[:hacks_valid_validation]}  (#{(seed_statistics[:hacks_valid_validation] / seed_statistics[:total_hacks].to_f).round(2)})\n\n"
    # report_content += "## General Analysis\n\n"
    report_content += "#{general_comparison}\n---\n\n"
    # puts report_content
    report_content
  end
end
