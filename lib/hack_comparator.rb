# lib/hack_comparator.rb
require 'digest' 
require 'langchainrb'  # Ensure langchainrb is included in your Gemfile and installed
require 'net/http'

module HackComparator
  # Initialize the LLM model (adjust according to langchainrb documentation)
  GOOGLE_API_KEY = ENV['GOOGLE_API_KEY']
  LLM = Langchain::LLM::GoogleGemini.new(
        api_key: "AIzaSyDe3fdegsgMONd0k1V-XbQ3KDAWF6g21Vc",
        default_options: { temperature: 0.6,
                           chat_completion_model_name: 'gemini-1.5-flash-8b',
                           embeddings_model_name: 'text-embedding-004' }
      )

  COMPARISON_RESULTS_FILE = 'comparison_results.marshal'
  def self.run(input, system_prompt = '')
    messages = [
      { role: 'user', parts: [{ text: system_prompt }, { text: input }] }
    ]
    response = LLM.chat(messages: messages)
    response.chat_completion
  end

  # Compare all hacks and save results incrementally
  def self.compare_all_hacks(seed_hacks, fetched_hacks)
    comparison_results = load_comparison_results

    # Create a hash map of seed transcriptions for quick lookup
    seed_transcriptions_hash = {}

    seed_hacks.each do |hack_id, hack_data|
      transcription = hack_data['transcription']
      next unless transcription  # Skip if no transcription

      transcription_digest = Digest::SHA256.hexdigest(transcription)
      seed_transcriptions_hash[transcription_digest] = hack_data
    end
    fetched_hacks.each do |fetched_hack|
      # Generate a unique key for each hack (e.g., using transcription hash)
      fetched_transcription = fetched_hack[:transcription]
      next unless fetched_transcription  # Skip if no transcription

      fetched_transcription_hash = Digest::SHA256.hexdigest(fetched_transcription)

      # Check if this hack has already been processed
      if comparison_results.key?(fetched_transcription_hash)
        puts "Hack with transcription hash #{fetched_transcription_hash} already compared. Skipping."
        next
      end

      # Find matching seed hack
      seed_hack = seed_transcriptions_hash[fetched_transcription_hash]
      unless seed_hack
        puts "No matching seed hack found for transcription hash #{fetched_transcription_hash}."
        next
      end

      # Compare the hacks
      differences = compare_hacks(seed_hack, fetched_hack)

      # Save the result
      
      comparison_results[fetched_transcription_hash] = {
        seed_id: seed_hack[:hack_id],
        seed_title: seed_hack[:title],
        fetch_id: fetched_hack[:id],
        fetch_title: fetched_hack[:title],
        differences_hash: differences
      }
      save_comparison_results(comparison_results)
    end

    comparison_results
  end

  # Compare two hacks and return the differences
  def self.compare_hacks(seed_hack, fetched_hack)
    begin
      differences = {}
      seed_is_hack = seed_hack[:is_hack] == true || seed_hack[:is_hack].to_s == 'True'
      if seed_is_hack
        seed_status = seed_hack["validation_status"] == 'Valid'
      else
        seed_status = false
      end
      is_hack = fetched_hack[:is_hack] == true || fetched_hack[:is_hack].to_s.downcase == 't'
      if is_hack
        status = fetched_hack[:hack_validations][:status] == true || fetched_hack[:hack_validations][:status].to_s.downcase == 't'
      else
        status = false
      end
      
      prompt1 = "We have a software that uses AI to extract financial hacks from internet sources. Below there are two extracts of the same source. 
Old Hack: 
  title: #{seed_hack[:title]}
  summary: #{seed_hack[:summary]}
  is_hack: #{seed_is_hack}
  justification: #{seed_hack[:justification]}

--- 
New Hack: 
  title: #{fetched_hack[:title]}
  summary: #{fetched_hack[:summary]}
  is_hack: #{is_hack}
  justification: #{fetched_hack[:justification]}

---
\nProvide a concise textual analysis of the differences of the both. Look at the quality of the justification. Pay special attention, and always mention, whether both can be considered the same hack, does not matter if the titles are different, study the content and the idea.
The result must be Markdown formatted."
      analysis_p1 = run(prompt1)
      differences['verification'] = {
        prompt: prompt1,
        analysis: analysis_p1
      }
      if seed_is_hack && is_hack
        prompt2 = "We have a software that uses AI to validate or refute the content of a financial hack, based on internet sources. To achieve that, queries are generated from the title and summary. Finally a LLM analyses the internet pages content and provides a validation status and a validation analysis. Below is the information of two versions of validations of the same hack. 
Old Hack: 
  hack title: #{seed_hack[:title]}
  hack summary: '#{seed_hack[:summary]}'
  rag_validation_queries: '#{seed_hack["queries"]}'
  validation_status: #{seed_status}
  validation_analysis: '#{seed_hack["validation_analysis"]}'
  validation_sources: '#{seed_hack["links"]}'

--- 
New Hack: 
  title: #{fetched_hack[:title]}
  summary: '#{fetched_hack[:summary]}'
  rag_validation_queries: '#{fetched_hack[:queries]}'
  validation_status: #{status}
  validation_analysis: '#{fetched_hack[:hack_validations][:analysis]}'
  validation_sources: '#{fetched_hack[:hack_validations][:links]}'

---
\nProvide a concise textual analysis of the differences of the both. Delve about the quality of the queries and the analysis. If in any case the validation_sources are empty point it out. The result must be Markdown formatted."
        analysis_p2 = run(prompt2)
        differences['validation'] = {
          prompt: prompt2,
          analysis: analysis_p2
        }
        if seed_status && status
          prompt3 = "We have a software that uses AI to study financial information and resturns a financial hack. Below are two versions of the same hack with the information separated by fields.
Old Hack: 
  hack_title: #{seed_hack["hack_structured_info"][:hack_title]},
  description: #{seed_hack["hack_structured_info"][:description]},
  main_goal: #{seed_hack["hack_structured_info"][:main_goal]},
  steps_summary: #{seed_hack["hack_structured_info"][:steps_summary]},
  resources_needed: #{seed_hack["hack_structured_info"][:resources_needed]},
  expected_benefits: #{seed_hack["hack_structured_info"][:expected_benefits]},
  extended_title: #{seed_hack["hack_structured_info"][:extended_title]},
  detailed_steps: #{seed_hack["hack_structured_info"][:detailed_steps]},
  additional_tools_resources: #{seed_hack["hack_structured_info"][:additional_tools_resources]},
  case_study: #{seed_hack["hack_structured_info"][:case_study]}

--- 
New Hack: 
  hack_title: #{fetched_hack[:hack_structured_infos][:hack_title]},
  description: #{fetched_hack[:hack_structured_infos][:description]},
  main_goal: #{fetched_hack[:hack_structured_infos][:main_goal]},
  steps_summary: #{fetched_hack[:hack_structured_infos][:steps_summary]},
  resources_needed: #{fetched_hack[:hack_structured_infos][:resources_needed]},
  expected_benefits: #{fetched_hack[:hack_structured_infos][:expected_benefits]},
  extended_title: #{fetched_hack[:hack_structured_infos][:extended_title]},
  detailed_steps: #{fetched_hack[:hack_structured_infos][:detailed_steps]},
  additional_tools_resources: #{fetched_hack[:hack_structured_infos][:additional_tools_resources]},
  case_study: #{fetched_hack[:hack_structured_infos][:case_study]}

---
\nProvide a concise textual analysis of the differences. Delve into the language used. Judge the fact that this will be presented to a user as a financial advice. The result must be Markdown formatted."
          
          analysis_p3 = run(prompt3)
          differences['description'] = {
            prompt: prompt3,
            analysis: analysis_p3
          }

          prompt_general = "We have a software that uses AI to extract financial hacks from internet sources, validate them and generate a structured final hack to present to users. 
Study the following analysis for each process."
          differences.each do |section, diff|
            prompt_general += "\n## Process: #{section.capitalize}\n"
            hack_report += "**Analysis:**\n```\n#{analysis}\n```\n"
          end
          prompt_general += "\nThe analysis were about the comparison of two versions of the same hack. Consolidate the information in a concise but clear analysis of the comparison in general. The result must be Markdown formatted, using lists whenever is necessary."
          general_hack_analysis = run(prompt_general)
          differences['hack'] = {
            prompt: prompt_general,
            analysis: general_hack_analysis
          }
        end
      end
    rescue Exception => e
     puts "Error in compare_hacks: #{e.message}"
     sleep 60
     retry
    end
    differences
  end

  def self.general_comparison(comparison_results, statistics)
    prompt = "After a test we compared the new results with a previous version. We have compared #{comparison_results.keys.size} hacks.
    The statistics are:
    Total videos in test: #{statistics[:total_hacks]}
    Number of possible hacks: #{statistics[:hacks_is_hack_true]}
    Hacks Validated as Valid: #{statistics[:hacks_valid_validation]}
    
    The changes detected are as follows:
    "
    changes = ""
   
    comparison_results.each do |transcription_hash, result|
      seed_hack_title = result[:seed_title]
      fetched_hack_title = result[:fetch_title]
      differences = result[:differences_hash]
      changes << "## Comparison for hacks: '#{seed_hack_title}' and  '#{fetched_hack_title}'.\n"
      # differences.each do |key, value|
      #   changes << "### #{key.capitalize}\n"
      #   changes << "#{value[:analysis]}\n\n"
      # end
      changes << "\n```\n#{differences['hack'][:analysis]}\n```\n\n"
      # changes << "\n---\n\n"
    end
    prompt += changes
    prompt += "\nBased on these changes and statistics, provide a general analysis (in markdown styled text) of what aspects are different than before, which are better, and which are worse. We already have analysis for each hack, focus on general patterns and recurrent changes."
    
    # puts prompt
    general_analysis = run(prompt)
    # puts general_analysis
    general_analysis
  end
  private

  # Save comparison results to the Marshal file
  def self.save_comparison_results(comparison_results)
    serialized_data = Marshal.dump(comparison_results)
    File.open(COMPARISON_RESULTS_FILE, 'wb') { |file| file.write(serialized_data) }
  end
  # Load existing comparison results from the Marshal file
  def self.load_comparison_results
    if File.exist?(COMPARISON_RESULTS_FILE)
      File.open(COMPARISON_RESULTS_FILE, 'rb') do |file|
        Marshal.load(file)
      end
    else
      {}
    end
  end

end
