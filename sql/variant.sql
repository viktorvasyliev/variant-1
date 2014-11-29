/*
 * Author: Jim Nasby
 * Created at: 2014-10-07 17:50:51 -0500
 *
 */


SET client_min_messages = warning;

-- If your extension will create a type you can
-- do somenthing like this

CREATE SCHEMA _variant;
CREATE SCHEMA variant;

CREATE TYPE _variant._variant AS ( original_type regtype, data text );

CREATE TYPE variant.variant;
CREATE OR REPLACE FUNCTION _variant._variant_in(cstring)
RETURNS variant.variant
LANGUAGE c IMMUTABLE STRICT
AS '$libdir/variant', 'variant_in';

CREATE OR REPLACE FUNCTION _variant._variant_out(variant.variant)
RETURNS cstring
LANGUAGE c IMMUTABLE STRICT
AS '$libdir/variant', 'variant_out';

CREATE TYPE variant.variant(
  INPUT = _variant._variant_in
  , OUTPUT = _variant._variant_out
  , STORAGE = extended
);

GRANT USAGE ON SCHEMA variant TO public;

CREATE OR REPLACE VIEW _variant.allowed_types AS
  SELECT t.oid::regtype AS type_name
      , 'variant.variant'::regtype AS source
      , 'variant.variant'::regtype AS target
    FROM pg_catalog.pg_type t
      LEFT JOIN pg_catalog.pg_type e ON e.oid = t.typelem
    WHERE true
      AND t.typisdefined
      AND t.typtype != 'c' -- We don't currently support composite types
      AND (e.typtype IS NULL OR e.typtype != 'c' ) -- Or arrays of composite types
;

CREATE OR REPLACE VIEW _variant.casts AS
  SELECT castsource::regtype AS source, casttarget::regtype AS target
      , castfunc::regprocedure AS cast_function
      , CASE castcontext
          WHEN 'e' THEN 'explicit'
          WHEN 'a' THEN 'assignment'
          WHEN 'i' THEN 'implicit'
        END AS cast_context
      , CASE castmethod
          WHEN 'f' THEN 'function'
          WHEN 'i' THEN 'inout'
          WHEN 'b' THEN 'binary'
        END AS cast_method
    FROM pg_catalog.pg_cast c
;

CREATE OR REPLACE VIEW variant.variant_casts AS
  SELECT *
    FROM _variant.casts
    WHERE false
      OR source = 'variant.variant'::regtype
      OR target = 'variant.variant'::regtype
;

CREATE OR REPLACE VIEW _variant.missing_casts_to AS
  SELECT t.type_name AS source, target
    FROM _variant.allowed_types t
  EXCEPT
  SELECT source, target FROM variant.variant_casts
;

CREATE OR REPLACE VIEW _variant.missing_casts_from AS
  SELECT source, t.type_name AS target
    FROM _variant.allowed_types t
  EXCEPT
  SELECT source, target FROM variant.variant_casts
;

CREATE OR REPLACE VIEW variant.missing_casts AS
  SELECT *, 'TO' AS direction
    FROM _variant.missing_casts_to
  UNION ALL
  SELECT *, 'FROM' AS direction
    FROM _variant.missing_casts_from
;

CREATE OR REPLACE FUNCTION _variant.exec(
  sql text
) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  RAISE DEBUG 'Executing SQL %s', sql;
  EXECUTE sql;
END
$f$;

CREATE OR REPLACE FUNCTION _variant.create_cast_in(
  p_source    regtype
) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM _variant.exec(
    format(
      $sql$CREATE OR REPLACE FUNCTION _variant.cast_in(
      i %s
      , typmod int
    ) RETURNS variant.variant LANGUAGE c IMMUTABLE AS '$libdir/variant', 'variant_cast_in'
      $sql$
      , p_source -- i data type
    )
  );
  PERFORM _variant.exec(
    format( 'CREATE CAST( %s AS variant.variant ) WITH FUNCTION _variant.cast_in( %1$s, int ) AS ASSIGNMENT'
      , p_source
    )
  );
END
$f$;

CREATE OR REPLACE FUNCTION _variant.create_cast_out(
  p_target    regtype
) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  v_function_name name := 'cast_to_' || regexp_replace( p_target::text, '[\. "]', '_' ); -- Replace invarid identifier characters with '_'
BEGIN
  PERFORM _variant.exec(
    format(
      $sql$CREATE OR REPLACE FUNCTION _variant.%s(
      v variant.variant
    ) RETURNS %1s LANGUAGE c IMMUTABLE AS '$libdir/variant', 'variant_cast_out'
      $sql$
      , v_function_name
      , p_target
    )
  );
  PERFORM _variant.exec(
    format( 'CREATE CAST( variant.variant AS %s) WITH FUNCTION _variant.%s( variant.variant ) AS ASSIGNMENT'
      , p_target
      , v_function_name
    )
  );
END
$f$;

CREATE OR REPLACE FUNCTION variant.create_casts()
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  r variant.missing_casts;
  sql text;
BEGIN
  FOR r IN SELECT * FROM variant.missing_casts
  LOOP
    sql := format( $sql$CREATE CAST %s AS %s
        WITH FUNCTION _variant.cast
      $sql$ );
  END LOOP;
END
$f$;

-- vi: expandtab sw=2 ts=2
