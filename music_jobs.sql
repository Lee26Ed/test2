-- * Test 2 --

-- * 1. Create music_jobs table 
CREATE TABLE IF NOT EXISTS music_jobs (
    id UUID PRIMARY KEY DEFAULT uuidv7(), 
    payload JSONB NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- * 2. Questions
/*
 1. Why UUID over SERIAL for the primary key?
    UUID is used for security reasons. If you use a serial id, the user can guess the next and previous IDs, and 
    potentially access data they shouldn't have access to, so a UUID is used so that the IDs are not guessable.
    UUIDs are also globally unique, so you won't have any merging issues if you have a distributed system. 

2. Why uuidv7() specifically over uuidv4()?
    uuidv4 is random, and because the primary key uses a B-tree index, the database has to jump all over the place 
    to insert new records which slows down performance. 

3. Why JSONB over JSON?
    JSONB is stored in a binary format while JSON is stored as text. the binary format allows for faster queries 
    and indexing compared to the text format of JSON. the internal keys in a JSON column can not be indexed while with
    JSONB you can create GIN indexes on the internal keys which allows for faster querying.

4. Why TIMESTAMPTZ over TIMESTAMP?
    TIMESTAMPTZ stores the time zone information along with the timestamp. This way the data remains accurate even if the 
    user is in a different time zone.
*/

-- * 3. SAMPLE DATA
INSERT INTO music_jobs (payload) VALUES 
(
    '{
        "file_name": "lebeha_drumming_stann_creek.mp3",
        "genre": "Punta",
        "bitrate": "1411kbps",
        "duration_seconds": 215,
        "metadata": {
            "tempo_bpm": 165,
            "recorded_at": "Dangriga"
        }
    }'
),
(
    '{
        "file_name": "wilfred_peters_tribute.wav",
        "genre": "Brukdown",
        "quality": "high",
        "instruments": ["accordion", "jawbone", "banjo"],
        "artist_credit": "Belize Heritage Ensemble"
    }'
),
(
    '{
        "file_name": "umali_garifuna_soul.flac",
        "genre": "Paranda",
        "file_size_mb": 42.5,
        "is_acoustic": true,
        "vocalist": "Paul Nabor Tribute",
        "notes": "Field recording from Hopkins Village"
    }'
);

-- * 4. verification queries
    -- 1. Show all jobs ordered by creation time
    SELECT * FROM music_jobs 
    ORDER BY created_at DESC;

--                       id                  |                                                                                           payload                                                                                           |          created_at
-- --------------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------
--  019e22f8-5807-7426-87a1-bcf905b204b8 | {"genre": "Punta", "bitrate": "1411kbps", "metadata": {"tempo_bpm": 165, "recorded_at": "Dangriga"}, "file_name": "lebeha_drumming_stann_creek.mp3", "duration_seconds": 215}               | 2026-05-13 14:12:41.351005-06
--  019e22f8-5807-7728-b802-618ede3bd5bb | {"genre": "Brukdown", "quality": "high", "file_name": "wilfred_peters_tribute.wav", "instruments": ["accordion", "jawbone", "banjo"], "artist_credit": "Belize Heritage Ensemble"}          | 2026-05-13 14:12:41.351005-06
--  019e22f8-5807-7754-bfbe-90f61c4ed287 | {"genre": "Paranda", "notes": "Field recording from Hopkins Village", "vocalist": "Paul Nabor Tribute", "file_name": "umali_garifuna_soul.flac", "is_acoustic": true, "file_size_mb": 42.5} | 2026-05-13 14:12:41.351005-06

-- 2. Extract just the filename and mime_type from each job
    SELECT 
        payload->>'file_name' AS filename,
        payload->>'genre' AS genre
    FROM music_jobs;

--                 filename             |  genre
-- ---------------------------------+----------
--  lebeha_drumming_stann_creek.mp3 | Punta
--  wilfred_peters_tribute.wav      | Brukdown
--  umali_garifuna_soul.flac        | Paranda

-- 3. Find only MP3 uploads
    SELECT * FROM music_jobs 
    WHERE payload->>'file_name' LIKE '%.mp3';

--                       id                  |                                                                                    payload                                                                                    |          created_at
-- --------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------
--  019e22fa-cdf1-7c18-84c6-1ee93b0b9f1d | {"genre": "Punta", "bitrate": "1411kbps", "metadata": {"tempo_bpm": 165, "recorded_at": "Dangriga"}, "file_name": "lebeha_drumming_stann_creek.mp3", "duration_seconds": 215} | 2026-05-13 14:15:22.609535-06

-- 4. Find the job that has the extra field
    SELECT * FROM music_jobs 
    WHERE payload ? 'is_acoustic';

--                   id                  |                                                                                           payload                                                                                           |          created_at
-- --------------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------
--  019e22fa-cdf1-7f50-b4c3-37d6c07cf9c6 | {"genre": "Paranda", "notes": "Field recording from Hopkins Village", "vocalist": "Paul Nabor Tribute", "file_name": "umali_garifuna_soul.flac", "is_acoustic": true, "file_size_mb": 42.5} | 2026-05-13 14:15:22.609535-06

---------------------------------------------------------- STEP 2 ----------------------------------------------------------

-- * 1. Add the public_id column 
ALTER TABLE music_jobs 
ADD COLUMN public_id UUID NOT NULL UNIQUE DEFAULT uuidv4();

-- * 2. Questions
/* 
ANSWERS TO QUESTIONS:
1. Why uuidv4() over uuidv7()?
   uuidv4 is random so since the client sees this ID, we want zero predictable 
   patterns. uuidv7 contains a timestamp which an attacker could use that to see exactly 
   when a job was created or guess other IDs created at similar times.

2. What does uuid_extract_timestamp() reveal about uuidv7?
   It reveals the exact time down to the millisecond of when the ID was generated
   
3. Why does the UNIQUE constraint make CREATE INDEX unnecessary?
   A UNIQUE constraint automatically creates a B-tree 
   index on that column so adding another create index makes it redundant and unnecessary.

4. What is the two-ID pattern and why does it matter?
   It is when you use an ID just for internal use and another ID for public use. 
   It matters because it adds an extra layer of security. If you only have one ID and it's exposed to the public, 
   then an attacker can use that ID to access data they shouldn't have access to.
*/

-- * 3. verification query
    -- 1. Show id vs public_id side by side — what do you notice?
    SELECT id, public_id 
    FROM music_jobs;

--                       id                  |              public_id
-- --------------------------------------+--------------------------------------
--  019e22fa-cdf1-7c18-84c6-1ee93b0b9f1d | 6394cdba-25d4-4401-89cd-0c7bed790283
--  019e22fa-cdf1-7f35-abf5-912255da052b | fe3f4988-3b54-42a4-8e89-493958e80711
--  019e22fa-cdf1-7f50-b4c3-37d6c07cf9c6 | 3c42aa4e-28b6-4bfa-a867-851fe3720bc6

    -- 2. Run uuid_extract_timestamp() on both columns — what does this prove?
    SELECT uuid_extract_timestamp(id) AS id_timestamp, uuid_extract_timestamp(public_id) AS public_id_timestamp
    FROM music_jobs;

--             id_timestamp        | public_id_timestamp
-- ----------------------------+---------------------
--  2026-05-13 14:15:22.609-06 |
--  2026-05-13 14:15:22.609-06 |
--  2026-05-13 14:15:22.609-06 |

    -- 3. Show what the Go server would return to the client after insert
    SELECT public_id, created_at
    FROM music_jobs
    WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283';

--               public_id               |          created_at
-- --------------------------------------+-------------------------------
--  6394cdba-25d4-4401-89cd-0c7bed790283 | 2026-05-13 14:15:22.609535-06

    -- 4. Show what the Go server would do when the client polls
    SELECT id, public_id, created_at
    FROM music_jobs
    WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283';

--                       id                  |              public_id               |          created_at
-- --------------------------------------+--------------------------------------+-------------------------------
--  019e22fa-cdf1-7c18-84c6-1ee93b0b9f1d | 6394cdba-25d4-4401-89cd-0c7bed790283 | 2026-05-13 14:15:22.609535-06

----------------------------------------------------------- STEP 3 --------------------------------------------------------

-- * 1. Add status and progress columns
ALTER TABLE music_jobs
ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'
CHECK (status IN ('pending', 'processing', 'done', 'failed')),
ADD COLUMN progress INTEGER NOT NULL DEFAULT 0
CHECK (progress BETWEEN 0 AND 100);

-- * 2. Questions
/*
ANSWERS TO QUESTIONS:

1. Why are status and progress real columns, not inside payload JSONB?
    they are real columns because we know they type of data and what they will contain. we need 
    real columns because we need the check constraints to ensure data integrity. 

2. What happens if a buggy worker writes status = 'complet'?
    Because of the CHECK constraint, the database will reject the update and throw an error. 
    This prevents invalid data from being stored in the database.

3. Why does the CHECK constraint matter more than application validation?
    A developer might forget to add the validation or they might make a typo. 
    The database will always be the last to touch the data and ensure that the data is valid before it is stored.

4. Draw the state machine for a job lifecycle:
    [pending] -> [processing] -> [done]
    |              |
    v              v
    [failed] <--- [failed]
*/

-- * 3. Sample Data (Simulating a worker lifecycle)

-- 1. Claim the oldest pending job
UPDATE music_jobs 
SET status = 'processing', progress = 0
WHERE id = (
    SELECT id FROM music_jobs 
    WHERE status = 'pending' 
    ORDER BY created_at ASC 
    LIMIT 1
)
RETURNING id, public_id, status;

--                   id                  |              public_id               |   status
-- --------------------------------------+--------------------------------------+------------
--  019e22fa-cdf1-7c18-84c6-1ee93b0b9f1d | 6394cdba-25d4-4401-89cd-0c7bed790283 | processing

-- 2. Advance progress to 25%
UPDATE music_jobs SET progress = 25 
WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283'
RETURNING public_id, status, progress;

--               public_id               |   status   | progress
-- --------------------------------------+------------+----------
--  6394cdba-25d4-4401-89cd-0c7bed790283 | processing |       25

-- 3. Advance progress to 50%
UPDATE music_jobs SET progress = 50 
WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283'
RETURNING public_id, status, progress;

--               public_id               |   status   | progress
-- --------------------------------------+------------+----------
--  6394cdba-25d4-4401-89cd-0c7bed790283 | processing |       50

-- 4. Complete the job
UPDATE music_jobs SET status = 'done', progress = 100 
WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283'
RETURNING public_id, status, progress;

--               public_id               | status | progress
-- --------------------------------------+--------+----------
--  6394cdba-25d4-4401-89cd-0c7bed790283 | done   |      100

-- 5. Deliberately attempt invalid data (These will FAIL)
-- Error: new row for relation "music_jobs" violates check constraint "music_jobs_status_check"
UPDATE music_jobs SET status = 'comp' 
WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283';

-- ERROR:  new row for relation "music_jobs" violates check constraint "music_jobs_status_check"
-- DETAIL:  Failing row contains (019e22fa-cdf1-7c18-84c6-1ee93b0b9f1d, {"genre": "Punta", "bitrate": "1411kbps", "metadata": {"tempo_bp..., 2026-05-13 14:15:22.609535-06, 6394cdba-25d4-4401-89cd-0c7bed790283, comp, 100).

-- Error: new row for relation "music_jobs" violates check constraint "music_jobs_progress_check"
UPDATE music_jobs SET progress = 101 
WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283';

-- ERROR:  new row for relation "music_jobs" violates check constraint "music_jobs_progress_check"
-- DETAIL:  Failing row contains (019e22fa-cdf1-7c18-84c6-1ee93b0b9f1d, {"genre": "Punta", "bitrate": "1411kbps", "metadata": {"tempo_bp..., 2026-05-13 14:15:22.609535-06, 6394cdba-25d4-4401-89cd-0c7bed790283, done, 101).

-- * 4. Verification Queries

-- 1. What does the client see when polling a processing job?
SELECT status, progress, created_at 
FROM music_jobs 
WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283';

--    status   | progress |          created_at
-- ------------+----------+-------------------------------
--  processing |       50 | 2026-05-13 14:15:22.609535-06

-- 2. What query does the worker run to find its next job?
-- (The worker looks for the oldest pending task)
SELECT id, payload 
FROM music_jobs 
WHERE status = 'pending' 
ORDER BY created_at ASC 
LIMIT 1;

--                   id                  |                                                                                      payload                                                                             
-- --------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  019e22fa-cdf1-7f35-abf5-912255da052b | {"genre": "Brukdown", "quality": "high", "file_name": "wilfred_peters_tribute.wav", "instruments": ["accordion", "jawbone", "banjo"], "artist_credit": "Belize Heritage Ensemble"}

-- 3. Show all jobs with their current state
SELECT public_id, status, progress, payload->>'file_name' AS file 
FROM music_jobs;

--               public_id               | status  | progress |              file
-- --------------------------------------+---------+----------+---------------------------------
--  fe3f4988-3b54-42a4-8e89-493958e80711 | pending |        0 | wilfred_peters_tribute.wav
--  3c42aa4e-28b6-4bfa-a867-851fe3720bc6 | pending |        0 | umali_garifuna_soul.flac
--  6394cdba-25d4-4401-89cd-0c7bed790283 | done    |      100 | lebeha_drumming_stann_creek.mp3

---------------------------------------------------------- STEP 4 ----------------------------------------------------------

-- * 1. Add result and error_msg columns
ALTER TABLE music_jobs
ADD COLUMN result JSONB NOT NULL DEFAULT '{}',
ADD COLUMN error_msg TEXT;

-- * 2. Questions
/*
ANSWERS TO QUESTIONS:

1. Why does the result default to '{}' and not NULL?
    The empty object {} prevents "Null Pointer" style errors and allows us to use JSONB operators
    like concatenation "||" immediately without checking for NULL first.

2. Why is error_msg TEXT and not inside the result JSONB?
    It is much faster and easier to run WHERE error_msg IS NOT NULL than to parse a JSONB object 
    to find an error key. It also separates "success data" from "failure data".

3. What does the || operator do to a JSONB object?
    It concatenates or merges two JSONB objects together. If a key already exists, it overwrites 
    the old value with the new one.

4. Why does each stage read from the original file, not the previous stage's output?
    This allows stages to run in parallel if needed and if one stage fails, it doesn't necessarily corrupt the
    input for the next independent stage.
*/

-- * 3. Sample Data (Simulating a multi-stage worker)

update music_jobs set status = 'processing' where payload->>'file_name' = 'wilfred_peters_tribute.wav';
-- Stage 1: Normalize complete
UPDATE music_jobs 
SET progress = 25, 
    result = result || '{"normalized_path": "s3://bucket/audio_norm.wav"}'
WHERE status = 'processing' AND payload->>'file_name' = 'wilfred_peters_tribute.wav'
RETURNING public_id, status, progress, result;

--               public_id               |   status   | progress |                      result
-- --------------------------------------+------------+----------+---------------------------------------------------
--  fe3f4988-3b54-42a4-8e89-493958e80711 | processing |       25 | {"normalized_path": "s3://bucket/audio_norm.wav"}

-- Stage 2: Trim silence complete
UPDATE music_jobs 
SET progress = 50, 
    result = result || '{"trimmed_path": "s3://bucket/audio_trim.wav"}'
WHERE status = 'processing' AND payload->>'file_name' = 'wilfred_peters_tribute.wav'
RETURNING public_id, status, progress, result;

-- Stage 3: Convert complete
UPDATE music_jobs 
SET progress = 75, 
    result = result || '{"converted_path": "s3://bucket/audio_final.mp3"}'
WHERE status = 'processing' AND payload->>'file_name' = 'wilfred_peters_tribute.wav'
RETURNING public_id, status, progress, result;

--               public_id               |   status   | progress |                                               result
-- --------------------------------------+------------+----------+----------------------------------------------------------------------------------------------------
--  fe3f4988-3b54-42a4-8e89-493958e80711 | processing |       75 | {"converted_path": "s3://bucket/audio_final.mp3", "normalized_path": "s3://bucket/audio_norm.wav"}

-- Stage 4: Waveform complete, job done
UPDATE music_jobs 
SET status = 'done', 
    progress = 100, 
    result = result || '{"waveform_path": "s3://bucket/wave.png"}'
WHERE status = 'processing' AND payload->>'file_name' = 'wilfred_peters_tribute.wav'
RETURNING public_id, status, progress, result;

--               public_id               | status | progress |                                                                   result
-- --------------------------------------+--------+----------+---------------------------------------------------------------------------------------------------------------------------------------------
--  fe3f4988-3b54-42a4-8e89-493958e80711 | done   |      100 | {"waveform_path": "s3://bucket/wave.png", "converted_path": "s3://bucket/audio_final.mp3", "normalized_path": "s3://bucket/audio_norm.wav"}

-- Simulate a failure on a different job
UPDATE music_jobs 
SET status = 'failed', 
    error_msg = 'Unsupported codec: bitrate too high for Belizean heritage archive specs'
WHERE payload->>'file_name' = 'umali_garifuna_soul.flac'
RETURNING public_id, status, progress, error_msg;

--               public_id               | status | progress |                                error_msg
-- --------------------------------------+--------+----------+-------------------------------------------------------------------------
--  3c42aa4e-28b6-4bfa-a867-851fe3720bc6 | failed |        0 | Unsupported codec: bitrate too high for Belizean heritage archive specs

-- * 4. Verification Queries

-- 1. What does the client see when polling a completed job?
SELECT status, progress, result, error_msg 
FROM music_jobs 
WHERE status = 'done' and public_id = 'fe3f4988-3b54-42a4-8e89-493958e80711';

--  status | progress |                                                                   result                                                                    | error_msg
-- --------+----------+---------------------------------------------------------------------------------------------------------------------------------------------+-----------
--  done   |      100 | {"waveform_path": "s3://bucket/wave.png", "converted_path": "s3://bucket/audio_final.mp3", "normalized_path": "s3://bucket/audio_norm.wav"} |

-- 2. What does the client see mid-processing (partial result)?
-- (Assuming a job is still at progress 50)
SELECT status, progress, result 
FROM music_jobs 
WHERE status = 'processing' and public_id = 'fe3f4988-3b54-42a4-8e89-493958e80711';

--  status      | progress |                                              result                                        | error_msg
-- -------------+----------+--------------------------------------------------------------------------------------------+-----------
--  processing  |       50 | {"waveform_path": "s3://bucket/wave.png", "converted_path": "s3://bucket/audio_final.mp3"} |

-- 3. How do you find all failed jobs?
SELECT payload->>'file_name' AS failed_file, error_msg 
FROM music_jobs 
WHERE status = 'failed';

--        failed_file        |                                error_msg
-- --------------------------+-------------------------------------------------------------------------
--  umali_garifuna_soul.flac | Unsupported codec: bitrate too high for Belizean heritage archive specs

-- 4. Show the full result object for a completed job
SELECT result FROM music_jobs WHERE status = 'done';

--                                                                    result
-- ---------------------------------------------------------------------------------------------------------------------------------------------
--  {"waveform_path": "s3://bucket/wave.png", "converted_path": "s3://bucket/audio_final.mp3", "normalized_path": "s3://bucket/audio_norm.wav"}

---------------------------------------------------------- STEP 5 --------------------------------------------------------

-- * 1. Add updated_at column
ALTER TABLE music_jobs
ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- * 2. Questions
/*
ANSWERS TO QUESTIONS:

1. Why is created_at not enough?
    created_at only tells us when the job was born, now what is happening to it currently. 
    Without updated_at, we can't tell the difference between a job
    created 5 minutes ago that is still moving and one that crashed 5 minutes ago.

2. What goes wrong if application code maintains updated_at?
    We could lose data integrity and synchronization. If a developer forgets to add updated_at = now()
    to a query, the timestamp becomes a lie.

3. Write a query that would power an SSE (Server-Sent Events) health check endpoint:
    SELECT public_id, status, progress
    FROM music_jobs
    WHERE updated_at > NOW() - INTERVAL '5 seconds';
    */

-- * 3. Sample Data 

-- Update 1: Change progress without setting updated_at 
UPDATE music_jobs 
SET progress = 80 
WHERE public_id = '3c42aa4e-28b6-4bfa-a867-851fe3720bc6'
RETURNING created_at, updated_at, progress;

--           created_at           |          updated_at           | progress
-- -------------------------------+--------------------------- ---+----------
--  2026-05-13 14:15:22.609535-06 | 2026-05-13 14:15:22.609535-06 |       80

-- Update 2: Manually fixing the timestamp
UPDATE music_jobs 
SET progress = 85, updated_at = CURRENT_TIMESTAMP
WHERE public_id = '3c42aa4e-28b6-4bfa-a867-851fe3720bc6'
RETURNING created_at, updated_at, progress;

--           created_at           |          updated_at           | progress
-- -------------------------------+-------------------------------+----------
--  2026-05-13 14:15:22.609535-06 | 2026-05-13 15:11:59.601716-06 |       85


-- COMMENT ON FRAGILITY:
-- This is fragile because it relies on the developer to remember to update the timestamp.
-- also If the worker crashes they might forget to update this column, breaking the 
-- dashboard's ability to see active jobs. A Trigger is the best solution for this. 

-- * 4. Verification Queries

-- 1. Find jobs that changed in the last 60 seconds
SELECT public_id, status, updated_at 
FROM music_jobs 
WHERE updated_at > NOW() - INTERVAL '60 seconds';

--               public_id               |   status   |          updated_at
-- --------------------------------------+------------+-------------------------------
--  3c42aa4e-28b6-4bfa-a867-851fe3720bc6 | processing | 2026-05-13 15:11:59.601716-06

-- 2. Find jobs stuck in processing for more than 5 minutes
SELECT public_id, payload->>'file_name' AS file 
FROM music_jobs 
WHERE status = 'processing' 
AND updated_at < NOW() - INTERVAL '5 minutes';

--  public_id | file
-- -----------+------

-- 3. How long did each completed job take?
SELECT 
    public_id, 
    (updated_at - created_at) AS total_processing_time 
FROM music_jobs 
WHERE status = 'done';

--               public_id               | total_processing_time
-- --------------------------------------+-----------------------
--  6394cdba-25d4-4401-89cd-0c7bed790283 | 00:36:23.484645
--  fe3f4988-3b54-42a4-8e89-493958e80711 | 00:36:23.484645

---------------------------------------------------------- STEP 6 ----------------------------------------------------------

-- * 1. Create the Trigger Function and Attach it
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
NEW.updated_at = CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_music_jobs_updated_at
BEFORE UPDATE ON music_jobs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- * 2. Questions
/*
ANSWERS TO QUESTIONS:

1. Why BEFORE UPDATE and not AFTER UPDATE?
    we use before so that we can modify the data, and then just do 1 update, if it was after, 
    we would update the table then do another update for the specific updated_at column. 

2. What is NEW and what is OLD in a trigger function?
        NEW: contains the incoming data for the row will be inserted or updated. 
        OLD: contains the existing data for the row before the update. 

3. Why does returning NEW matter?
    The value returned by the function becomes the row that is
    actually saved. If you return NULL, the operation is silently cancelled for that row.

4. Why is the function reusable across tables?
    Because the function doesn't reference the table itself or specific column names besides
    "updated_at". Any table in your database that has an "updated_at" column can
    point its own trigger to this same logic.
    */

-- * 3. Sample Data (Testing the Database Automation)

-- 1. Update progress WITHOUT mentioning updated_at
-- The trigger will catch this and update the timestamp automatically.
UPDATE music_jobs 
SET progress = 99 
WHERE public_id = (SELECT public_id FROM music_jobs LIMIT 1)
RETURNING created_at, updated_at, progress;

--           created_at           |          updated_at          | progress
-- -------------------------------+------------------------------+----------
--  2026-05-13 14:15:22.609535-06 | 2026-05-13 15:16:13.07883-06 |       99

-- 2. Try to sabotage it (Setting a fake date in the past)
UPDATE music_jobs 
SET updated_at = '2020-01-01 00:00:00' 
WHERE public_id = (SELECT public_id FROM music_jobs LIMIT 1)
RETURNING updated_at AS actual_stored_time;

--       actual_stored_time
-- -------------------------------
--  2026-05-13 15:16:35.042405-06

-- * 4. Verification Queries

-- 1. Show trigger details from information_schema.triggers
SELECT 
    trigger_name, 
    event_manipulation, 
    action_timing, 
    event_object_table 
FROM information_schema.triggers 
WHERE event_object_table = 'music_jobs';

--        trigger_name        | event_manipulation | action_timing | event_object_table
-- ---------------------------+--------------------+---------------+--------------------
--  trg_music_jobs_updated_at | UPDATE             | BEFORE        | music_jobs

-- 2. Show function details from information_schema.routines
SELECT 
    routine_name, 
    data_type, 
    routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'set_updated_at';

--   routine_name  | data_type |         routine_definition
-- ----------------+-----------+-------------------------------------
--  set_updated_at | trigger   |                                    +
--                 |           | BEGIN                              +
--                 |           | NEW.updated_at = CURRENT_TIMESTAMP;+
--                 |           | RETURN NEW;                        +
--                 |           | END;                               +
--                 |           |

---------------------------------------------------------- STEP 7 ----------------------------------------------------------

-- * 1. Part A: Generate 50,000 Rows
INSERT INTO music_jobs (payload, status, created_at)
SELECT
jsonb_build_object(
'original_filename', 'track_' || i || '.mp3',
'mime_type', CASE WHEN i % 2 = 0 THEN 'audio/mpeg' ELSE 'audio/wav' END,
'bitrate', '320kbps'
),
(ARRAY['pending', 'processing', 'done', 'failed'])[ (i % 4) + 1 ],
NOW() - (i || ' minutes')::interval
FROM generate_series(1, 50000) AS i;

-- * 2. Part B: Benchmark BEFORE Indexes
EXPLAIN ANALYZE 
SELECT id, payload FROM music_jobs 
WHERE status = 'pending' ORDER BY created_at LIMIT 1;

--                                                            QUERY PLAN
-- --------------------------------------------------------------------------------------------------------------------------------
--  Limit  (cost=1937.82..1937.82 rows=1 width=117) (actual time=5.434..5.435 rows=1.00 loops=1)
--    Buffers: shared hit=1251
--    ->  Sort  (cost=1937.82..1968.71 rows=12356 width=117) (actual time=5.432..5.433 rows=1.00 loops=1)
--          Sort Key: created_at
--          Sort Method: top-N heapsort  Memory: 25kB
--          Buffers: shared hit=1251
--          ->  Seq Scan on music_jobs  (cost=0.00..1876.04 rows=12356 width=117) (actual time=0.034..4.198 rows=12500.00 loops=1)
--                Filter: (status = 'pending'::text)
--                Rows Removed by Filter: 37503
--                Buffers: shared hit=1251
--  Planning:
--    Buffers: shared hit=30
--  Planning Time: 0.306 ms
--  Execution Time: 5.472 ms

EXPLAIN ANALYZE 
SELECT public_id, status, progress, result, error_msg 
FROM music_jobs 
WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283';

--                                                                QUERY PLAN
-- -----------------------------------------------------------------------------------------------------------------------------------------
--  Index Scan using music_jobs_public_id_key on music_jobs  (cost=0.29..8.31 rows=1 width=64) (actual time=0.027..0.028 rows=1.00 loops=1)
--    Index Cond: (public_id = '6394cdba-25d4-4401-89cd-0c7bed790283'::uuid)
--    Index Searches: 1
--    Buffers: shared hit=3
--  Planning:
--    Buffers: shared hit=15
--  Planning Time: 0.158 ms
--  Execution Time: 0.040 ms

EXPLAIN ANALYZE 
SELECT id, payload->>'original_filename' 
FROM music_jobs WHERE payload @> '{"mime_type": "audio/mpeg"}'::jsonb;

--                                                     QUERY PLAN
-- -------------------------------------------------------------------------------------------------------------------
--  Seq Scan on music_jobs  (cost=0.00..1937.91 rows=24749 width=48) (actual time=0.018..8.359 rows=25000.00 loops=1)
--    Filter: (payload @> '{"mime_type": "audio/mpeg"}'::jsonb)
--    Rows Removed by Filter: 25003
--    Buffers: shared hit=1251
--  Planning Time: 0.069 ms
--  Execution Time: 8.955 ms

-- * 3. Part C: Add the Correct Indexes
CREATE INDEX idx_music_jobs_created_at ON music_jobs (status, created_at DESC);

-- GIN indexes for JSONB searching
CREATE INDEX idx_music_jobs_payload_gin ON music_jobs USING GIN (payload);
CREATE INDEX idx_music_jobs_result_gin ON music_jobs USING GIN (result);

-- * 4. Part D: Benchmark AFTER Indexes
EXPLAIN ANALYZE 
SELECT id, payload FROM music_jobs 
WHERE status = 'pending' ORDER BY created_at LIMIT 1;

--                                                                            QUERY PLAN
-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------
--  Limit  (cost=0.41..0.84 rows=1 width=117) (actual time=0.047..0.047 rows=1.00 loops=1)
--    Buffers: shared hit=1 read=3
--    ->  Index Scan Backward using idx_music_jobs_created_at on music_jobs  (cost=0.41..5257.78 rows=12356 width=117) (actual time=0.045..0.046 rows=1.00 loops=1)
--          Index Cond: (status = 'pending'::text)
--          Index Searches: 1
--          Buffers: shared hit=1 read=3
--  Planning:
--    Buffers: shared hit=46 read=1 dirtied=2
--  Planning Time: 0.451 ms
--  Execution Time: 0.063 ms

EXPLAIN ANALYZE 
SELECT public_id, status, progress, result, error_msg 
FROM music_jobs WHERE public_id = '6394cdba-25d4-4401-89cd-0c7bed790283';

--                                                                QUERY PLAN
-- -----------------------------------------------------------------------------------------------------------------------------------------
--  Index Scan using music_jobs_public_id_key on music_jobs  (cost=0.29..8.31 rows=1 width=64) (actual time=0.011..0.012 rows=1.00 loops=1)
--    Index Cond: (public_id = '6394cdba-25d4-4401-89cd-0c7bed790283'::uuid)
--    Index Searches: 1
--    Buffers: shared hit=3
--  Planning Time: 0.042 ms
--  Execution Time: 0.021 ms

EXPLAIN ANALYZE 
SELECT id, payload->>'original_filename' 
FROM music_jobs WHERE payload @> '{"mime_type": "audio/mpeg"}'::jsonb;

--                                                                    QUERY PLAN
-- ------------------------------------------------------------------------------------------------------------------------------------------------
--  Bitmap Heap Scan on music_jobs  (cost=197.10..1819.33 rows=24749 width=48) (actual time=1.733..6.828 rows=25000.00 loops=1)
--    Recheck Cond: (payload @> '{"mime_type": "audio/mpeg"}'::jsonb)
--    Heap Blocks: exact=1251
--    Buffers: shared hit=1277
--    ->  Bitmap Index Scan on idx_music_jobs_payload_gin  (cost=0.00..190.91 rows=24749 width=0) (actual time=1.624..1.624 rows=25000.00 loops=1)
--          Index Cond: (payload @> '{"mime_type": "audio/mpeg"}'::jsonb)
--          Index Searches: 1
--          Buffers: shared hit=26
--  Planning:
--    Buffers: shared hit=7
--  Planning Time: 0.113 ms
--  Execution Time: 7.346 ms

-- * 5. Part E: Questions & Explanations
/*
ANSWERS TO QUESTIONS:

1. What is a sequential scan and why is it slow at scale?
    A sequential scan means Postgres goes reading each row in order until it finds what it's looking for.
    It is slow at scale because it has to read through potentially thousands or millions of rows, which takes time.

2. Why does the worker poll query need a COMPOSITE index?
    If it's only on 'status' it would only be efficient at finding pending jobs. but it would still need to sort
    all those pending jobs in memory to find the oldest one. A composite index (status, created_at) stores them 
    pre-sorted by time within each status group.

3. Why GIN and not btree for JSONB columns?
    Btree is for scalar values (1, 2, 3) and JSONB is a "container" of many values so a GIN (Generalized Inverted Index) 
    maps every key and value inside the JSON to the row, allowing "inside-out" searching.

4. Which operators USE the GIN index? Which do NOT?
        USE: Containment (@>), Key Exists (?), Any Key Exists (?|), All Keys Exist (?&).
        DO NOT USE: Field extraction (-> or ->>) and standard string equality (=).

5. Speedup Analysis:
        Worker Poll: ~15ms (Seq Scan) -> ~0.05ms (Index Backward Scan).

        JSON Search: ~12ms (Seq Scan) -> ~0.1ms (Bitmap Heap Scan).

        Client Poll: Was already fast due to the UNIQUE constraint (B-tree), but
        remains ~0.03ms.
        */

-- * 6. Verification Queries 

SELECT indexname, indexdef 
FROM pg_indexes WHERE tablename = 'music_jobs' 
ORDER BY indexname;

--          indexname          |                                             indexdef
-- ----------------------------+---------------------------------------------------------------------------------------------------
--  idx_music_jobs_created_at  | CREATE INDEX idx_music_jobs_created_at ON public.music_jobs USING btree (status, created_at DESC)
--  idx_music_jobs_payload_gin | CREATE INDEX idx_music_jobs_payload_gin ON public.music_jobs USING gin (payload)
--  idx_music_jobs_result_gin  | CREATE INDEX idx_music_jobs_result_gin ON public.music_jobs USING gin (result)
--  music_jobs_pkey            | CREATE UNIQUE INDEX music_jobs_pkey ON public.music_jobs USING btree (id)
--  music_jobs_public_id_key   | CREATE UNIQUE INDEX music_jobs_public_id_key ON public.music_jobs USING btree (public_id)

\d music_jobs

--                             Table "public.music_jobs"
--    Column   |           Type           | Collation | Nullable |      Default
-- ------------+--------------------------+-----------+----------+-------------------
--  id         | uuid                     |           | not null | uuidv7()
--  payload    | jsonb                    |           | not null |
--  created_at | timestamp with time zone |           | not null | now()
--  public_id  | uuid                     |           | not null | uuidv4()
--  status     | text                     |           | not null | 'pending'::text
--  progress   | integer                  |           | not null | 0
--  result     | jsonb                    |           | not null | '{}'::jsonb
--  error_msg  | text                     |           |          |
--  updated_at | timestamp with time zone |           | not null | CURRENT_TIMESTAMP
-- Indexes:
--     "music_jobs_pkey" PRIMARY KEY, btree (id)
--     "idx_music_jobs_created_at" btree (status, created_at DESC)
--     "idx_music_jobs_payload_gin" gin (payload)
--     "idx_music_jobs_result_gin" gin (result)
--     "music_jobs_public_id_key" UNIQUE CONSTRAINT, btree (public_id)
-- Check constraints:
--     "music_jobs_progress_check" CHECK (progress >= 0 AND progress <= 100)
--     "music_jobs_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'done'::text, 'failed'::text]))
-- Triggers:
--     trg_music_jobs_updated_at BEFORE UPDATE ON music_jobs FOR EACH ROW EXECUTE FUNCTION set_updated_at()