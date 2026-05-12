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

• 2. Why uuidv7() specifically over uuidv4()?
    uuidv4 is random, and because the primary key uses a B-tree index, the database has to jump all over the place 
    to insert new records which slows down performance. 

• 3. Why JSONB over JSON?
    JSONB is stored in a binary format while JSON is stored as text. the binary format allows for faster queries 
    and indexing compared to the text format of JSON. the internal keys in a JSON column can not be indexed while with
    JSONB you can create GIN indexes on the internal keys which allows for faster querying.

• 4. Why TIMESTAMPTZ over TIMESTAMP?
    TIMESTAMPTZ stores the time zone information along with the timestamp. This way the data remains accurate even if the 
    user is in a different time zone.
*/

-- * 3. SAMPLE DATA
INSERT INTO music_jobs (payload) VALUES 
(
    '{
        "file_name": "lebeha_drumming_stann_creek.wav",
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
        "file_name": "wilfred_peters_tribute.mp3",
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

-- 2. Extract just the filename and mime_type from each job
    SELECT 
        payload->>'file_name' AS filename,
        payload->>'genre' AS genre
    FROM music_jobs;

-- 3. Find only MP3 uploads
    SELECT * FROM music_jobs 
    WHERE payload->>'file_name' LIKE '%.mp3';

-- 4. Find the job that has the extra field
    SELECT * FROM music_jobs 
    WHERE payload ? 'is_acoustic';


---------------------------------------------------------- STEP 2 ----------------------------------------------------------

-- * 1. Add the public_id column 
ALTER TABLE music_jobs 
ADD COLUMN public_id UUID NOT NULL UNIQUE DEFAULT uuidv4();

/* 
ANSWERS TO QUESTIONS:
1. Why uuidv4() over uuidv7()?
   uuidv4 is random so since the client sees this ID, we want zero predictable 
   patterns. uuidv7 contains a timestamp which an attacker could use that to see exactly 
   when a job was created or guess other IDs created at similar times.

2. What does uuid_extract_timestamp() reveal about uuidv7?
   It reveals the exact time down to the millisecond the ID was generated
   
3. Why does the UNIQUE constraint make CREATE INDEX unnecessary?
   In PostgreSQL, specifying a UNIQUE constraint automatically creates a B-tree 
   index on that column to enforce the uniqueness. Manually adding another index 
   would be redundant and waste disk space.

4. What is the two-ID pattern and why does it matter?
   It decouples physical storage from public API. 'id' (v7) keeps our database 
   fast via sequential inserts. 'public_id' (v4) keeps our data secure by 
   preventing "enumeration attacks" and leaking system metadata.
*/