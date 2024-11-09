require 'pg'
require 'yaml'

module DBConnection
  def self.connect
    db_config_path = File.join(__dir__, '../config/database.yml')
    yaml_content = File.read(db_config_path)
    config = YAML.safe_load(yaml_content, aliases: true)['development']
    # config = YAML.load_file(File.join(__dir__, '../config/database.yml'))['development']
    PG.connect(
      host: config['host'],
      port: config['port'],
      dbname: config['database'],
      user: config['username'],
      password: config['password']
    )
  end

end