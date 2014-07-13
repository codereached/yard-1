#export RUBY_SRC=~/.rvm/src/"$RUBY_VERSION"
export RUBY_SRC=/tmp/sg/github.com/ruby/ruby
rspec -c -f d -e 'TypeInf' && rspec -c -f d spec/handlers/reference_handler_spec.rb && rspec -c -f d spec/handlers/local_variable_handler_spec.rb
