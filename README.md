variant
=======

variant is a Postgres datatype that can hold data from any other type, as well
as remembering what the original type was. For example:

    SELECT '(text,some text)'::variant.variant;
          variant       
    --------------------
     (text,"some text")
    (1 row)

    SELECT '(int,42)'::variant.variant;
       variant    
    --------------
     (integer,42)
    (1 row)

To build it, just do this:

    make install

and then in your database:

    CREATE EXTENSION variant;

See "Building" below for more details or if you run into a problem.

Usage
=====

Currently, what you can do is extremely limited; you can only store and retrieve data.

The input format for a variant is similar to that of a composite type of the form

    ( original_type regtype, data text )

where original_type is the type that the data was originally in, and data is the data itself, in it's own output format. For certain values (ie: an empty string), you must wrap the data portion in double-quotes, ie:

    CAST( '(text,"")' AS variant.variant )

NULLs
=====

variant has special handling for NULLs in that you can store a NULL value that is associated with a data type:

    '(timestamp with time zone,)'

This is *not* the same as a variant that is itself NULL.

TODO
====

The next step is to handle casting to and from variant and other data types. This will make it easy to store data as a variant by simply casting to variant.

Add the ability to remember exactly what types a particular variant has stored. I plan on doing this by allowing you to uniquely identify a variant when you create it, ie:

    CREATE TABLE v( v variant('integer variant');
    SELECT variant.register( 'integer variant', array[ 'smallint', 'int', 'bigint' ] );

variant doesn't currently store the type modifier (ie: the 42 in varchar(42)).

Building
========
To build variant, do this:

    make
    make install

If you encounter an error such as:

    "Makefile", line 8: Need an operator

You need to use GNU make, which may well be installed on your system as
`gmake`:

    gmake
    gmake install

If you encounter an error such as:

    make: pg_config: Command not found

Be sure that you have `pg_config` installed and in your path. If you used a
package management system such as RPM to install PostgreSQL, be sure that the
`-devel` package is also installed. If necessary tell the build process where
to find it:

    env PG_CONFIG=/path/to/pg_config make && make install

And finally, if all that fails (and if you're on PostgreSQL 8.1 or lower, it
likely will), copy the entire distribution directory to the `contrib/`
subdirectory of the PostgreSQL source tree and try it there without
`pg_config`:

    env NO_PGXS=1 make && make installcheck && make install

If you encounter an error such as:

    ERROR:  must be owner of database regression

You need to run the test suite using a super user, such as the default
"postgres" super user:

    make installcheck PGUSER=postgres

Once variant is installed, you can add it to a database. If you're running
PostgreSQL 9.1.0 or greater, it's a simple as connecting to a database as a
super user and running:

    CREATE EXTENSION variant;

If you've upgraded your cluster to PostgreSQL 9.1 and already had variant
installed, you can upgrade it to a properly packaged extension with:

    CREATE EXTENSION variant FROM unpackaged;

For versions of PostgreSQL less than 9.1.0, you'll need to run the
installation script:

    psql -d mydb -f /path/to/pgsql/share/contrib/variant.sql

If you want to install variant and all of its supporting objects into a specific
schema, use the `PGOPTIONS` environment variable to specify the schema, like
so:

    PGOPTIONS=--search_path=extensions psql -d mydb -f variant.sql

Dependencies
------------
The `variant` data type has no dependencies other than PostgreSQL.

Copyright and License
---------------------

Copyright (c) 2014 The maintainer's name.

