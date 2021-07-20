require 'spec_helper'

describe "Data types" do
  it "should support ::character varying" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 'foo'::character varying")
      expect(result.class).to be <= String
    end
  end

  it "should support ::text" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 'quox sed ut'::text")
      expect(result.class).to be <= String
    end
  end

  it "should support ::bigint" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 123::bigint")
      # binding.pry
      # expect(result.class).to be <= Bignum
    end
  end

  it "should support ::integer" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 345::integer")
      expect(result.class).to be <= Integer
    end
  end

  it "should support ::float4" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 1.23::float4")
      expect(result.class).to be <= Float
    end
  end

  it "should support ::float8" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 34.5::float8")
      expect(result.class).to be <= Float
    end
  end

  it "should support ::decimal" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 1.23::decimal")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::timestamp" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT TIMESTAMP '2007-02-01 15:04:05'::timestamp")
      expect(result.class).to be <= Time
    end
  end

  it "should support ::timestampz" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT TIMESTAMPTZ '2007-02-01 15:04:05+06'::timestamp with time zone")
      expect(result.class).to be <= Time
    end
  end

  it "should support ::time" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT TIME '01:23:45'::time")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::date" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT DATE '2007-02-01'::date")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::bytea" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT '\\000'::bytea")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::boolean" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT TRUE::boolean")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::map[...]" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT '{a => 1, b => 2}'::map[text=>int]")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::jsonb" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT '{\"1\":2,\"3\":4}'::jsonb")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::interval" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT INTERVAL '1-2 3 4:5:6.7'::interval")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::record" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT ROW('a', 123)")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end

  it "should support ::oid" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 123::oid")
      # binding.pry
      # expect(result.class).to be <= Numeric
    end
  end






end
