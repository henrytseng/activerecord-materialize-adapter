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
      [
        -9_223_372_036_854_775_807,
        9_223_372_036_854_775_807
      ].each do |i|
        result = ActiveRecord::Base.connection.query_value("SELECT #{i}::bigint")
        expect(result.class).to be <= Integer
        expect(result).to be == i
      end
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

  it "should support ::decimal and use backwards compatible String" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT (0.1 + 0.2)::decimal")
      expect(result.class).to be <= String
      expect(BigDecimal(result)).to be == (BigDecimal('.1') + BigDecimal('.2'))
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

  it "should support ::time and use backwards compatible value" do
    pg_result = with_pg { ActiveRecord::Base.connection.query_value("SELECT TIME '01:23:45'::time") }
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT TIME '01:23:45'::time")
      expect(result.class).to be <= String
      expect(result).to be == pg_result
    end
  end

  it "should support ::date and use backwards compatible value" do
    pg_result = with_pg { ActiveRecord::Base.connection.query_value("SELECT DATE '2007-02-01'::date") }
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT DATE '2007-02-01'::date")
      expect(result.class).to be <= String
      expect(result).to be == pg_result
    end
  end

  it "should support ::bytea" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT '\\000'::bytea")
      expect(result.class).to be <= String
      expect(result).to be == "\x00"
    end
  end

  it "should support ::boolean" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT TRUE::boolean")
      expect(result.class).to be TrueClass
    end
  end

  it "should support ::map[...]" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT '{a => 1, b => 2}'::map[text=>int]")
      expect(result.class).to be <= String
    end
  end

  it "should support ::jsonb and use backwards compatible value" do
    pg_result = with_pg { ActiveRecord::Base.connection.query_value("SELECT '{\"1\":2,\"3\":4}'::jsonb") }
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT '{\"1\":2,\"3\":4}'::jsonb")
      expect(result.class).to be <= String
      expect(JSON.parse(result)).to be == JSON.parse(pg_result)
    end
  end

  it "should support ::interval" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT INTERVAL '1-2 3 4:5:6.7'::interval")
      expect(result.class).to be <= String
      expect(result).to include "1 year 2 months 3 days 04:05:06.7"
    end
  end

  it "should support ::record" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT ROW('a', 123)")
      expect(result.class).to be <= String
      expect(result).to include "a"
      expect(result).to include "123"
    end
  end

  it "should support ::oid" do
    with_materialize do |config|
      result = ActiveRecord::Base.connection.query_value("SELECT 123::oid")
      expect(result.class).to be <= Numeric
    end
  end
end
