/*
 * This script cleans up the previous run of the Redlist so that a new one may commence.
 * It does this rather burtally by just DROPPING everything
 *
 * If you want to keep anything, back it up before running this!
 */

-- Drop any extant redlist schema
DROP SCHEMA IF EXISTS redlist CASCADE;

-- Create the redlist schema
CREATE SCHEMA redlist;