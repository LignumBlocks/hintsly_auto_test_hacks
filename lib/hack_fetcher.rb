# lib/hack_fetcher.rb

require 'pg'
require 'csv'

module HackFetcher
  # Define your seed CSV files and transcription directory
  HACKS_CSV = 'data/seeds/hacks_verification.csv'
  HACK_VALIDATION_CSV = 'data/seeds/validation_result.csv'
  QUERIES_CSV = 'data/seeds/validation_queries.csv'
  HACK_DESCRIPTIONS_CSV = 'data/seeds/descriptions_results.csv'
  HACK_STRUCTURED_INFO_CSV = 'data/seeds/hack_structured_info.csv'
  HACK_CLASSIFICATION_CSV = 'data/seeds/hack_classification.csv'
  TRANSCRIPTIONS_DIR = 'data/seeds/transcriptions'
  
  def self.fetch_hacks_from_db(conn, channel_id)
    # Prepare SQL query to fetch hacks for given channel IDs
    # Assuming the table is named 'hacks' and has a 'channel_id' column
    # sanitized_ids = channel_ids.map(&:to_i).join(',')
    hacks_query = <<-SQL
      SELECT hacks.*, videos.channel_id, videos.text AS file_name, videos.id AS video_id
      FROM hacks
      JOIN videos ON hacks.video_id = videos.id
      WHERE videos.channel_id = #{channel_id};
    SQL

    # Execute the query and fetch results
    hacks_result = conn.exec_params(hacks_query)
    hacks = hacks_result.map { |row| row }

    # Extract hack_ids and video_ids
    hack_ids = hacks.map { |hack| hack['id'].to_i }.join(',')
    video_ids = hacks.map { |hack| hack['video_id'].to_i }.uniq.join(',')
    # video_files = hacks.map { |hack| hack['file_name'] }
    # puts video_files
    # Fetch hack_validations
    validations = fetch_hack_validations(conn, hack_ids)

    # Fetch queries
    queries = fetch_queries(conn, hack_ids)

    # Fetch hack_structured_infos
    structured_infos = fetch_hack_structured_infos(conn, hack_ids)

    # Fetch transcription from database via Video association
    # transcriptions = fetch_transcription(conn, video_ids)
    
    # Combine all data
    hacks_with_related = hacks.map do |hack|
      hack_id = hack['id'].to_i
      video_id = hack['video_id'].to_i
      hack_data = hack.transform_keys(&:to_sym)
      
      hack_data[:hack_validations] = validations[hack_id] || {}
      hack_data[:queries] = queries[hack_id] || []
      hack_data[:hack_structured_infos] = structured_infos[hack_id] || {}
      hack_data[:transcription] = hack['file_name'] 
      # puts hack_data[:transcription] 
      hack_data
    end

    conn.close  # Close the database connection
    hacks_with_related
  rescue PG::Error => e
    puts "Database connection error: #{e.message}"
    []
  end

  # Fetch hack_validations for given hack_ids
  def self.fetch_hack_validations(conn, hack_ids)
    return {} if hack_ids.empty?
    query = <<-SQL
      SELECT * FROM hack_validations
      WHERE hack_id IN (#{hack_ids});
    SQL

    result = conn.exec_params(query)
    validations = {}

    result.each do |row|
      hack_id = row['hack_id'].to_i
      validations[hack_id] = row.transform_keys(&:to_sym)
    end

    validations
  rescue PG::Error => e
    AppLogger.logger.error("Database query error (hack_validations): #{e.message}")
    puts "Database query error (hack_validations): #{e.message}"
    {}
  end

  # Fetch queries for given hack_ids
  def self.fetch_queries(conn, hack_ids)
    return {} if hack_ids.empty?

    query = <<-SQL
      SELECT * FROM queries
      WHERE hack_id IN (#{hack_ids});
    SQL

    result = conn.exec_params(query)
    queries = {}

    result.each do |row|
      hack_id = row['hack_id'].to_i
      queries[hack_id] ||= []
      queries[hack_id] << row.transform_keys(&:to_sym)
    end

    queries
  rescue PG::Error => e
    AppLogger.logger.error("Database query error (queries): #{e.message}")
    puts "Database query error (queries): #{e.message}"
    {}
  end

  # Fetch hack_structured_infos for given hack_ids
  def self.fetch_hack_structured_infos(conn, hack_ids)
    return {} if hack_ids.empty?

    query = <<-SQL
      SELECT * FROM hack_structured_infos
      WHERE hack_id IN (#{hack_ids});
    SQL

    result = conn.exec_params(query)
    structured_infos = {}

    result.each do |row|
      # puts row
      hack_id = row['hack_id'].to_i
      # Assuming one structured_info per hack; modify if multiple
      structured_infos[hack_id] = row.transform_keys(&:to_sym)
    end

    structured_infos
  rescue PG::Error => e
    AppLogger.logger.error("Database query error (hack_structured_infos): #{e.message}")
    puts "Database query error (hack_structured_infos): #{e.message}"
    {}
  end

  # Fetch transcription for a given video_id
  def self.fetch_transcription(conn, video_ids)
    transcription_query = <<-SQL
      SELECT video_id, content
      FROM transcriptions
      WHERE video_id IN (#{video_ids});
    SQL

    result = conn.exec_params(transcription_query)
    
    # Map each transcription to its corresponding video_id
    transcriptions = {}
    result.each do |row|
      video_id = row['video_id'].to_i
      transcriptions[video_id] = row['content']
    end

    transcriptions
  rescue PG::Error => e
    AppLogger.logger.error("Database query error (transcriptions): #{e.message}")
    puts "Database query error (transcriptions): #{e.message}"
    { content: nil }
  end


  # Load seed hacks from CSV files
  def self.load_seed_data
    seed_hacks = {}

    # Load hacks
    CSV.foreach(HACKS_CSV, headers: true) do |row|
      hack_id = row['file_name']
      seed_hacks[hack_id] = {
        hack_id: hack_id,
        is_hack: row['hack_status'],
        title: row['title'],
        summary: row['brief summary'],
        justification: row['justification']
      }
    end
    # Load queries
    CSV.foreach(QUERIES_CSV, headers: true) do |row|
      hack_id = row['file_name']
      queries = row['queries']
      seed_hacks[hack_id] ||= {}
      queries_list = queries[1..-2].split(", ")
      queries_list.map! { |element| element[1..-2] }
      seed_hacks[hack_id]['queries'] = queries_list
    end
    # Load hack_validation
    CSV.foreach(HACK_VALIDATION_CSV, headers: true) do |row|
      hack_id = row['file_name']
      seed_hacks[hack_id]['validation_status'] = row['validation status']
      seed_hacks[hack_id]['validation_analysis'] = row['validation analysis']
      seed_hacks[hack_id]['links'] = row['relevant sources'].split
    end
    # Load descriptions
    CSV.foreach(HACK_DESCRIPTIONS_CSV, headers: true) do |row|
      hack_id = row['file_name']
      seed_hacks[hack_id]['free_description'] = row['deep analysis_free']
      seed_hacks[hack_id]['premium_description'] = row['deep analysis_premium']
    end
    # Load hack_structured_info
    CSV.foreach(HACK_STRUCTURED_INFO_CSV, headers: true) do |row|
      hack_id = row['file_name']
      seed_hacks[hack_id]['hack_structured_info'] = {
        hack_title: row['Hack Title'],
        description: row['Description'],
        main_goal: row['Main Goal'],
        steps_summary: row['steps(Summary)'],
        resources_needed: row['Resources Needed'],
        expected_benefits: row['Expected Benefits'],
        extended_title: row['Extended Title'],
        detailed_steps: row['Detailed steps'],
        additional_tools_resources: row['Additional Tools and Resources'],
        case_study: row['Case Study']
      }
    end
    # # Load hack_classification
    # CSV.foreach(HACK_CLASSIFICATION_CSV, headers: true) do |row|
    #   hack_id = row['file_name']
    #   free = row['deep analysis_free']
    #   premium = row['deep analysis_premium']
    #   seed_hacks[hack_id]['hack_structured_info'] = {
    #   }
    # end
    # 
    # Load transcriptions
    load_transcriptions(seed_hacks)

    seed_hacks
  end

  # Load transcription content from transcription files
  def self.load_transcriptions(seed_hacks)
    seed_hacks.each do |hack_id, hack_data|
      transcription_path = File.join(TRANSCRIPTIONS_DIR, "#{hack_id}.txt")
      if File.exist?(transcription_path)
        transcription_content = File.read(transcription_path)
        hack_data['transcription'] = transcription_content
      else
        # AppLogger.logger.warn("Transcription file not found for Hack ID #{hack_id}: #{transcription_path}")
        puts "Warning: Transcription file not found for Hack ID #{hack_id}: #{transcription_path}"
        hack_data['transcription'] = nil
      end
    end
  end
end