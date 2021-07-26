# ActiveRecord Materialize Adapter

[![Testing](https://github.com/henrytseng/activerecord-materialize-adapter/actions/workflows/testing.yml/badge.svg)](https://github.com/henrytseng/activerecord-materialize-adapter/actions/workflows/testing.yml)
[![Doc reference](https://img.shields.io/badge/doc-reference-orange)](https://materialize.com/docs)
[![Chat on Slack](https://img.shields.io/badge/chat-on%20slack-purple)](https://materialize.com/s/chat)

An ActiveRecord adapter to connect to Materialize databases.

Materialize is a streaming database for real-time applications. Materialize accepts input data from a variety of streaming sources (e.g. Kafka) and files (e.g. CSVs), and lets you query them using SQL.

[https://materialize.com/](https://materialize.com/)


## Usage

Add gem to your `Gemfile`

```
   gem 'activerecord-materialize-adapter'
```

Make sure you have the `pg` or a compatible gem installed.  Update your `database.yml`

```
  production:
    reporting_analytics:
      adapter: materialize
      host: "materialize-database-host"
      port: "6875"
      database: "materialize_database_name"
      username: "materialize_user"
```


## Design

The ActiveRecord Materialize Adapter is heavily based on the PostgreSQL database adapter and also relies on the `pg` gem to be installed.

Read about Materialized architecture [https://materialize.com/docs/overview/architecture/](https://materialize.com/docs/overview/architecture/)

Materialize has been designed to specifically solve problems with event streaming; therefore, some relational database functionality may not be supported.


## Contributing

To contribute read the `CONTRIBUTING.md` first.

Fork the repository and create a pull request referencing tests and documentation.

A development stack can be setup with `bin/build` and tests can be run with `bin/test`.

Debugging with `bin/materialize_psql` and `bin/psql` allows you to connect directly with Materialize and PostgreSQL.

For testing and debugging a PostgreSQL configuration is available in `postgres/postgresql.conf` and `pg_hba.conf`.
