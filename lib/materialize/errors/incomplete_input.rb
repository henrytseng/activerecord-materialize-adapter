# frozen_string_literal: true

require 'materialize/errors/database_error'

module Materialize
  module Errors
    class IncompleteInput < DatabaseError
    end
  end
end
