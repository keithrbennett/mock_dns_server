
# This is put in a lambda so as not to pollute the namespace with variables that will be useless later
->() {
  file_mask = File.join(File.dirname(__FILE__), '**/*.rb')
  files_to_require = Dir[file_mask]
  files_to_require.each { |file| require file }
}.call


module MockDnsServer
  # Your code goes here...
end
