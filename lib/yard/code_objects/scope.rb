module YARD::CodeObjects
  module Scope

    def next_scope_entry_id
      if @local_entries == nil
        @local_entries = 0
      else
        @local_entries += 1
      end
    end
  end
end
