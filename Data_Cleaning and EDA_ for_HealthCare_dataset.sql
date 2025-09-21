use medical_dataset;

SELECT * FROM healthcare

-- First we make a staging table so that we can work on that 
CREATE TABLE healthcare_staging LIKE healthcare;

-- And import the data using imort wizard
-- Then we check using the count func if all the rows has been imoprted in the staging table 
SELECT COUNT(*) AS total_rows FROM healthcare_staging;

-- First initial EDA , to understand the dataset

-- we understood the dataset and indentified that there are 2 useless columns 

ALTER TABLE healthcare_staging
DROP COLUMN Random_Notes;

ALTER TABLE healthcare_staging
DROP COLUMN Temp_code;
 -- So we have removed two useless columns 
SELECT * FROM healthcare_staging

-- Now doing a quick baseline check , what are the missing vals in each column wise 


SELECT
SUM(patient_ID IS NULL OR Patient_ID='') AS Missing_patient_ID,
SUM(Diagnosis_code IS NULL OR Diagnosis_code='') AS Missing_Diagnosis_code,
SUM(Cost IS NULL OR Cost=' ') As Cost_missing,
SUM(Cost<=0) AS non_positive_cost
FROM healthcare_staging;



-- Now we'll check for distinct claim_id and patient_id so we can get a idea if we got duplicates or not 


SELECT 
COUNT(DISTINCT Claim_ID) AS distinct_claims,
COUNT(DISTINCT Patient_ID) AS distinct_Patient

FROM healthcare_staging;



-- With this line we are seeing all the duplicates 
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY claim_id) AS row_num
    FROM healthcare_staging
) t
WHERE row_num >1;

-- Lets confirm the duplicates one more time 


SELECT *
FROM healthcare_staging
WHERE Claim_ID='C1044';

-- turn off safe mode 
SET SQL_SAFE_UPDATES = 0;

-- Now time to delete the duplicates 

WITH DELETE_CTE AS (  
SELECT Claim_ID,
           ROW_NUMBER() OVER (PARTITION BY Claim_ID ORDER BY claim_date DESC) AS row_num
    FROM healthcare_staging
)
DELETE FROM healthcare_staging
WHERE Claim_ID IN( 

SELECT Claim_ID 
FROM DELETE_CTE 
WHERE row_num>1
);


-- Now lets check again if any duplicates left 

SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY claim_id) AS row_num
    FROM healthcare_staging
) t
WHERE row_num >1;


-- Standardize Data

-- Find missing vals 

SELECT *
FROM healthcare_staging
ORDER BY Diagnosis_code;

-- Looking for missing vals 

SELECT 
    SUM(CASE WHEN patient_id IS NULL OR patient_id = '' THEN 1 ELSE 0 END) AS missing_patients,
    SUM(CASE WHEN diagnosis_code IS NULL OR diagnosis_code = '' THEN 1 ELSE 0 END) AS missing_diagnosis,
    SUM(CASE WHEN cost IS NULL OR cost = '' THEN 1 ELSE 0 END) AS missing_cost
FROM healthcare_staging;

-- Found the number of missing values , now i will go and check them deeper 

SELECT *
FROM healthcare_staging
WHERE diagnosis_code IS NULL OR TRIM(diagnosis_code) = '';

-- Rows with missing cost
SELECT *
FROM healthcare_staging
WHERE cost IS NULL OR cost = '';


-- As some of the Diagnosis_codes are missing but in these rows other imp vals are present
-- so we will keep these rows but make a extra column where we will flag them as missing

-- 1. Add a new column to flag missing diagnosis
ALTER TABLE healthcare_staging
ADD COLUMN diagnosis_missing_flag BOOLEAN DEFAULT FALSE;


-- 2. Update rows where diagnosis_code is missing or empty

UPDATE healthcare_staging
SET diagnosis_missing_flag=true
WHERE diagnosis_code IS NULL OR TRIM(diagnosis_code)='';

-- Only 3 rows are missing it, so cost dropping them is safe.

DELETE FROM healthcare_staging
WHERE cost IS NULL OR TRIM(cost)='0';


-- Now checking if the date is ok or not 

-- Converting the text type to date type 

ALTER TABLE healthcare_staging
MODIFY COLUMN claim_date DATE;


-- Standardize Text Columns

-- Uppercase diagnosis codes
UPDATE healthcare_staging
SET diagnosis_code=UPPER (TRIM(diagnosis_code) );

-- Remove extra spaces from procedure codes
UPDATE healthcare_staging
SET procedure_code = TRIM(procedure_code);

-- Rounding all the value to 2 digits after the decimal.
-- Example: 45.959440 → becomes 45.96
UPDATE healthcare_staging
SET cost = ROUND(cost, 2);

-- Fixing the Hospital names issue 


SELECT Hospital_Name ,SUM(cost)
FROM healthcare_staging
GROUP BY Hospital_Name;

-- 'St. Maryâ€™s Clinic', 

-- Remove all characters except A-Z, a-z, 0-9, and spaces
UPDATE healthcare_staging
SET Hospital_Name = REGEXP_REPLACE(Hospital_Name, '[^A-Za-z0-9 ]', '');

-- Fixing the cost -500 lilke vals 

SELECT *
FROM healthcare_staging
WHERE Cost LIKE '%-%';



-- Making the negative cost as positive 
UPDATE healthcare_staging
SET Cost = ABS(Cost)
WHERE Cost < 0;




/*
-- Done with cleaning the data
1. Duplicates removed

2. Missing values handled

3. Zero costs removed

4. Negative costs converted to positive

5. Costs rounded to 2 decimals

6. Hospital names cleaned

7. Diagnosis codes standardized 

*/

-- Now I will Start the EDA Again and Understand patterns, trends, and insights in the data. 

-- Prepare for dashboards, reports, or business questions.

-- Step 1: Summary statistics


-- Total number of claims
SELECT COUNT(*) AS total_claims FROM healthcare_staging;

-- Total cost
SELECT SUM(Cost) AS total_cost FROM healthcare_staging;

-- AVG cost 
SELECT AVG(Cost) AS AVG_Cost FROM healthcare_staging;

-- Min and Max cost
SELECT MIN(Cost) AS min_cost, MAX(Cost) AS max_cost FROM healthcare_staging;



-- Step 2: Claims per hospital
SELECT Hospital_Name, count(*) AS num_of_Claim, SUM(Cost) AS total_cost_per_hospital
FROM healthcare_staging
GROUP BY Hospital_Name
ORDER BY total_cost_per_hospital DESC;

-- Step 3: Claims per diagnosis
SELECT Diagnosis_Code, count(*) AS num_of_Claim, SUM(Cost) AS total_cost_per_Diagnosis
FROM healthcare_staging
GROUP BY Diagnosis_Code
ORDER BY total_cost_per_Diagnosis DESC;


SELECT claim_date, count(*) AS num_of_Claim, SUM(Cost) AS total_cost_per_date
FROM healthcare_staging
GROUP BY claim_date
ORDER BY total_cost_per_date DESC;




-- Now as our dataset is cleaned up , so time to export 

SELECT * FROM healthcare_staging;
-- Now click on the export option over the table and save with a name as you like 