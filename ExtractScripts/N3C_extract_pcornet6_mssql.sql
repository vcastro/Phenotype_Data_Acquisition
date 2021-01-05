--PCORNet 6.0 extraction code for N3C
--This extract purposefully excludes the following PCORnet tables: ENROLLMENT, HARVEST, HASH_TOKEN, PCORNET_TRIAL, LAB_HISTORY
--Assumptions:
--	1. You have already built the N3C_COHORT table (with that name) prior to running this extract
--	2. You are extracting data with a lookback period to 1-1-2018

--MANIFEST TABLE: CHANGE PER YOUR SITE'S SPECS
--OUTPUT_FILE: MANIFEST.csv
select distinct
   '@siteAbbrev' as SITE_ABBREV,
   '@siteName'    AS SITE_NAME,
   '@contactName' as CONTACT_NAME,
   '@contactEmail' as CONTACT_EMAIL,
   '@cdmName' as CDM_NAME,
   '@cdmVersion' as CDM_VERSION,
   null AS VOCABULARY_VERSION, -- hardwired null for pcornet
   '@n3cPhenotypeYN' as N3C_PHENOTYPE_YN,
   (SELECT TOP 1 phenotype_version FROM @resultsDatabaseSchema.N3C_PRE_COHORT) as N3C_PHENOTYPE_VERSION,
   '@shiftDateYN' as SHIFT_DATE_YN, --if shifting dates prior to submission say Y, else N
   '@maxNumShiftDays' as MAX_NUM_SHIFT_DAYS, --maximum number of days that you are shifting dates, write UNKNOWN if you do not know, NA if not shifting
   CAST(GETDATE() as date) as RUN_DATE,
   CAST( DATEADD(day, -@dataLatencyNumDays, GETDATE()) as date) as UPDATE_DATE,	--change integer based on your site's data latency
   CAST( DATEADD(day, @daysBetweenSubmissions, GETDATE()) as date) as NEXT_SUBMISSION_DATE
FROM @resultsDatabaseSchema.N3C_COHORT;

--case-control map table
--OUTPUT_FILE: CONTROL_MAP.csv
SELECT * from @resultsDatabaseSchema.N3C_CONTROL_MAP;

-- pcornet duplicate key validation script
-- VALIDATION_SCRIPT
-- OUTPUT_FILE: EXTRACT_VALIDATION.csv
select * from
(
	SELECT 'DEMOGRAPHIC' as TABLE_NAME, 
	(
		SELECT COUNT(*) 
		FROM (
			SELECT DEMOGRAPHIC.PATID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.DEMOGRAPHIC 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON DEMOGRAPHIC.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
			GROUP BY DEMOGRAPHIC.PATID HAVING COUNT(*) >= 2
		) tbl
 ) as DUP_COUNT
	 UNION 
	 SELECT 'ENCOUNTER' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT ENCOUNTERID, COUNT(*) as COUNT_N
			FROM @cdmDatabaseSchema.ENCOUNTER 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON ENCOUNTER.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND ADMIT_DATE >= DATEFROMPARTS(2018,01,01) 
			GROUP BY ENCOUNTERID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	 UNION 
	 SELECT 'CONDITION' as TABLE_NAME,
	 (
		SELECT COUNT(*) FROM (
			SELECT CONDITIONID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.CONDITION 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON CONDITION.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND REPORT_DATE >= DATEFROMPARTS(2018,01,01) 
			GROUP BY CONDITIONID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'DEATH' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT DEATH.PATID, DEATH.DEATH_SOURCE, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.DEATH 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON DEATH.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
			GROUP BY DEATH.PATID, DEATH.DEATH_SOURCE
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'DEATH_CAUSE' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT DEATH_CAUSE.PATID, DEATH_CAUSE, DEATH_CAUSE_CODE, DEATH_CAUSE_TYPE, DEATH_CAUSE_SOURCE, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.DEATH_CAUSE 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON DEATH_CAUSE.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
			GROUP BY DEATH_CAUSE.PATID, DEATH_CAUSE, DEATH_CAUSE_CODE, DEATH_CAUSE_TYPE, DEATH_CAUSE_SOURCE 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'DIAGNOSIS' asTABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT DIAGNOSISID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.DIAGNOSIS 
			JOIN @resultsDatabaseSchema.N3C_COHORT ON DIAGNOSIS.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
				AND (
					DX_DATE >= DATEFROMPARTS(2018,01,01) 
					OR ADMIT_DATE >= DATEFROMPARTS(2018,01,01)
				) 
			GROUP BY DIAGNOSISID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'DISPENSING' asTABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT DISPENSINGID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.DISPENSING 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON DISPENSING.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND DISPENSE_DATE >= DATEFROMPARTS(2018,01,01) 
			GROUP BY DISPENSINGID HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'IMMUNIZATION' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT IMMUNIZATIONID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.IMMUNIZATION 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON IMMUNIZATION.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
			GROUP BY IMMUNIZATIONID HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'LAB_RESULT_CM' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT LAB_RESULT_CM_ID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.LAB_RESULT_CM 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON LAB_RESULT_CM.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND (
						LAB_ORDER_DATE >= DATEFROMPARTS(2018,01,01) 
						OR RESULT_DATE >= DATEFROMPARTS(2018,01,01)
					) 
			GROUP BY LAB_RESULT_CM_ID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'LDS_ADDRESS_HISTORY' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT ADDRESSID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.LDS_ADDRESS_HISTORY 
			JOIN @resultsDatabaseSchema.N3C_COHORT ON LDS_ADDRESS_HISTORY.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
				AND (
					ADDRESS_PERIOD_END is null 
					OR ADDRESS_PERIOD_END >= DATEFROMPARTS(2018,01,01)
				) 
			GROUP BY ADDRESSID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'MED_ADMIN' asTABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT MEDADMINID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.MED_ADMIN 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON MED_ADMIN.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND MEDADMIN_START_DATE >= DATEFROMPARTS(2018,01,01) 
			GROUP BY MEDADMINID HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'OBS_CLIN' asTABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT OBSCLINID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.OBS_CLIN 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON OBS_CLIN.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND OBSCLIN_START_DATE >= DATEFROMPARTS(2018,01,01)
			GROUP BY OBSCLINID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'OBS_GEN' asTABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT OBSGENID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.OBS_GEN 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON OBS_GEN.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND OBSGEN_START_DATE >= DATEFROMPARTS(2018,01,01) 
				GROUP BY OBSGENID 
				HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'PRESCRIBING' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT PRESCRIBINGID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.PRESCRIBING 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON PRESCRIBING.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND RX_ORDER_DATE >= DATEFROMPARTS(2018,01,01)
			GROUP BY PRESCRIBINGID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'PRO_CM' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT PRO_CM_ID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.PRO_CM 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON PRO_CM.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND PRO_DATE >= DATEFROMPARTS(2018,01,01) 
			GROUP BY PRO_CM_ID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'PROCEDURES' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT PROCEDURESID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.PROCEDURES 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON PROCEDURES.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND PX_DATE >= DATEFROMPARTS(2018,01,01) 
			GROUP BY PROCEDURESID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
	UNION 
	SELECT 'PROVIDER' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT PROVIDERID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.PROVIDER 
			GROUP BY PROVIDERID HAVING COUNT(*) >= 2) tbl) as DUP_COUNT
	UNION 
	select 'VITAL' as TABLE_NAME,
	(
		SELECT COUNT(*) FROM (
			SELECT VITALID, COUNT(*) as COUNT_N 
			FROM @cdmDatabaseSchema.VITAL 
				JOIN @resultsDatabaseSchema.N3C_COHORT ON VITAL.PATID = @resultsDatabaseSchema.N3C_COHORT.PATID 
					AND MEASURE_DATE >= DATEFROMPARTS(2018,01,01) 
			GROUP BY VITALID 
			HAVING COUNT(*) >= 2
		) tbl
	) as DUP_COUNT
) subq
where dup_count > 0
;

--DEMOGRAPHIC
--OUTPUT_FILE: DEMOGRAPHIC.csv
SELECT
   DEMOGRAPHIC.PATID,
   LEFT(CAST(convert(varchar, BIRTH_DATE, 23) as varchar),7) as BIRTH_DATE, --purposely removing day from birth date
   '00:00' as BIRTH_TIME, --purposely removing time from birth date
   SEX,
   SEXUAL_ORIENTATION,
   GENDER_IDENTITY,
   HISPANIC,
   RACE,
   BIOBANK_FLAG,
   PAT_PREF_LANGUAGE_SPOKEN,
   null as RAW_SEX,
   null as RAW_SEXUAL_ORIENTATION,
   null as RAW_GENDER_IDENTITY,
   null as RAW_HISPANIC,
   null as RAW_RACE,
   null as RAW_PAT_PREF_LANGUAGE_SPOKEN
FROM @cdmDatabaseSchema.DEMOGRAPHIC JOIN @resultsDatabaseSchema.N3C_COHORT ON DEMOGRAPHIC.PATID = N3C_COHORT.PATID;

--ENCOUNTER
--OUTPUT_FILE: ENCOUNTER.csv
SELECT
   ENCOUNTERID,
   ENCOUNTER.PATID,
   CAST(ADMIT_DATE as datetime) as ADMIT_DATE,
   ADMIT_TIME,
   CAST(DISCHARGE_DATE as datetime) as DISCHARGE_DATE,
   DISCHARGE_TIME,
   PROVIDERID,
   null as FACILITY_LOCATION,
   ENC_TYPE,
   null as FACILITYID,
   DISCHARGE_DISPOSITION,
   DISCHARGE_STATUS,
   DRG,
   DRG_TYPE,
   ADMITTING_SOURCE,
   PAYER_TYPE_PRIMARY,
   PAYER_TYPE_SECONDARY,
   FACILITY_TYPE,
   null as RAW_SITEID,
   null as RAW_ENC_TYPE,
   null as RAW_DISCHARGE_DISPOSITION,
   null as RAW_DISCHARGE_STATUS,
   null as RAW_DRG_TYPE,
   null as RAW_ADMITTING_SOURCE,
   null as RAW_FACILITY_TYPE,
   null as RAW_PAYER_TYPE_PRIMARY,
   null as RAW_PAYER_NAME_PRIMARY,
   null as RAW_PAYER_ID_PRIMARY,
   null as RAW_PAYER_TYPE_SECONDARY,
   null as RAW_PAYER_NAME_SECONDARY,
   null as RAW_PAYER_ID_SECONDARY
FROM @cdmDatabaseSchema.ENCOUNTER JOIN @resultsDatabaseSchema.N3C_COHORT ON ENCOUNTER.PATID = N3C_COHORT.PATID
WHERE ADMIT_DATE >= DATEFROMPARTS(2018,01,01);

--CONDITION
--OUTPUT_FILE: CONDITION.csv
SELECT
   CONDITIONID,
   CONDITION.PATID,
   ENCOUNTERID,
   CAST(REPORT_DATE as datetime) as REPORT_DATE,
   CAST(RESOLVE_DATE as datetime) as RESOLVE_DATE,
   CAST(ONSET_DATE as datetime) as ONSET_DATE,
   CONDITION_STATUS,
   CONDITION,
   CONDITION_TYPE,
   CONDITION_SOURCE,
   null as RAW_CONDITION_STATUS,
   null as RAW_CONDITION,
   null as RAW_CONDITION_TYPE,
   null as RAW_CONDITION_SOURCE
FROM @cdmDatabaseSchema.CONDITION JOIN @resultsDatabaseSchema.N3C_COHORT ON CONDITION.PATID = N3C_COHORT.PATID
WHERE REPORT_DATE >= DATEFROMPARTS(2018,01,01);

--DEATH
--OUTPUT_FILE: DEATH.csv
--No lookback period for death
SELECT
   DEATH.PATID,
   CAST(DEATH_DATE as datetime) as DEATH_DATE,
   DEATH_DATE_IMPUTE,
   DEATH_SOURCE,
   DEATH_MATCH_CONFIDENCE
FROM @cdmDatabaseSchema.DEATH JOIN @resultsDatabaseSchema.N3C_COHORT ON DEATH.PATID = N3C_COHORT.PATID;

--DEATH CAUSE
--OUTPUT_FILE: DEATH_CAUSE.csv
--No lookback period for death cause
SELECT
   DEATH_CAUSE.PATID,
   DEATH_CAUSE,
   DEATH_CAUSE_CODE,
   DEATH_CAUSE_TYPE,
   DEATH_CAUSE_SOURCE,
   DEATH_CAUSE_CONFIDENCE
FROM @cdmDatabaseSchema.DEATH_CAUSE JOIN @resultsDatabaseSchema.N3C_COHORT ON DEATH_CAUSE.PATID = N3C_COHORT.PATID;

--DIAGNOSIS
--OUTPUT_FILE: DIAGNOSIS.csv
SELECT
   DIAGNOSISID,
   DIAGNOSIS.PATID,
   ENCOUNTERID,
   ENC_TYPE,
   CAST(ADMIT_DATE as datetime) as ADMIT_DATE,
   PROVIDERID,
   DX,
   DX_TYPE,
   CAST(DX_DATE as datetime) as DX_DATE,
   DX_SOURCE,
   DX_ORIGIN,
   PDX,
   DX_POA,
   null as RAW_DX,
   null as RAW_DX_TYPE,
   null as RAW_DX_SOURCE,
   null as RAW_PDX,
   null as RAW_DX_POA
FROM @cdmDatabaseSchema.DIAGNOSIS JOIN @resultsDatabaseSchema.N3C_COHORT ON DIAGNOSIS.PATID = N3C_COHORT.PATID
WHERE DX_DATE >= DATEFROMPARTS(2018,01,01) OR ADMIT_DATE >= DATEFROMPARTS(2018,01,01);

--DISPENSING
--OUTPUT_FILE: DISPENSING.csv
SELECT
   DISPENSINGID,
   DISPENSING.PATID,
   PRESCRIBINGID,
   CAST(DISPENSE_DATE as datetime) as DISPENSE_DATE,
   NDC,
   DISPENSE_SOURCE,
   DISPENSE_SUP,
   DISPENSE_AMT,
   DISPENSE_DOSE_DISP,
   DISPENSE_DOSE_DISP_UNIT,
   DISPENSE_ROUTE,
   null as RAW_NDC,
   null as RAW_DISPENSE_DOSE_DISP,
   null as RAW_DISPENSE_DOSE_DISP_UNIT,
   null as RAW_DISPENSE_ROUTE
FROM @cdmDatabaseSchema.DISPENSING JOIN @resultsDatabaseSchema.N3C_COHORT ON DISPENSING.PATID = N3C_COHORT.PATID
WHERE DISPENSE_DATE >= DATEFROMPARTS(2018,01,01);

--IMMUNIZATION
--OUTPUT_FILE: IMMUNIZATION.csv
--No lookback period for immunizations
SELECT
   IMMUNIZATIONID,
   IMMUNIZATION.PATID,
   ENCOUNTERID,
   PROCEDURESID,
   VX_PROVIDERID,
   CAST(VX_RECORD_DATE as datetime) as VX_RECORD_DATE,
   CAST(VX_ADMIN_DATE as datetime) as VX_ADMIN_DATE,
   VX_CODE_TYPE,
   VX_CODE,
   VX_STATUS,
   VX_STATUS_REASON,
   VX_SOURCE,
   VX_DOSE,
   VX_DOSE_UNIT,
   VX_ROUTE,
   VX_BODY_SITE,
   VX_MANUFACTURER,
   VX_LOT_NUM,
   CAST(VX_EXP_DATE as datetime) as VX_EXP_DATE,
   null as RAW_VX_NAME,
   null as RAW_VX_CODE,
   null as RAW_VX_CODE_TYPE,
   null as RAW_VX_DOSE,
   null as RAW_VX_DOSE_UNIT,
   null as RAW_VX_ROUTE,
   null as RAW_VX_BODY_SITE,
   null as RAW_VX_STATUS,
   null as RAW_VX_STATUS_REASON,
   null as RAW_VX_MANUFACTURER
FROM @cdmDatabaseSchema.IMMUNIZATION JOIN @resultsDatabaseSchema.N3C_COHORT ON IMMUNIZATION.PATID = N3C_COHORT.PATID;

--LAB_RESULT_CM
--OUTPUT_FILE: LAB_RESULT_CM.csv
SELECT
   LAB_RESULT_CM_ID,
   LAB_RESULT_CM.PATID,
   ENCOUNTERID,
   SPECIMEN_SOURCE,
   LAB_LOINC,
   LAB_RESULT_SOURCE,
   LAB_LOINC_SOURCE,
   PRIORITY,
   RESULT_LOC,
   LAB_PX,
   LAB_PX_TYPE,
   CAST(LAB_ORDER_DATE as datetime) as LAB_ORDER_DATE,
   CAST(SPECIMEN_DATE as datetime) as SPECIMEN_DATE,
   SPECIMEN_TIME,
   CAST(RESULT_DATE as datetime) as RESULT_DATE,
   RESULT_TIME,
   RESULT_QUAL,
   RESULT_SNOMED,
   RESULT_NUM,
   RESULT_MODIFIER,
   RESULT_UNIT,
   NORM_RANGE_LOW,
   NORM_MODIFIER_LOW,
   NORM_RANGE_HIGH,
   NORM_MODIFIER_HIGH,
   ABN_IND,
   RAW_LAB_NAME,
   null as RAW_LAB_CODE,
   null as RAW_PANEL,
   RAW_RESULT,
   RAW_UNIT,
   null as RAW_ORDER_DEPT,
   null as RAW_FACILITY_CODE
FROM @cdmDatabaseSchema.LAB_RESULT_CM JOIN @resultsDatabaseSchema.N3C_COHORT ON LAB_RESULT_CM.PATID = N3C_COHORT.PATID
WHERE LAB_ORDER_DATE >= DATEFROMPARTS(2018,01,01) OR RESULT_DATE >= DATEFROMPARTS(2018,01,01);

--LDS_ADDRESS_HISTORY
--OUTPUT_FILE: LDS_ADDRESS_HISTORY.csv
SELECT
   ADDRESSID,
   LDS_ADDRESS_HISTORY.PATID,
   ADDRESS_USE,
   ADDRESS_TYPE,
   ADDRESS_PREFERRED,
   ADDRESS_CITY,
   ADDRESS_STATE,
   ADDRESS_ZIP5,
   ADDRESS_ZIP9,
   ADDRESS_PERIOD_START,
   ADDRESS_PERIOD_END
FROM @cdmDatabaseSchema.LDS_ADDRESS_HISTORY JOIN @resultsDatabaseSchema.N3C_COHORT ON LDS_ADDRESS_HISTORY.PATID = N3C_COHORT.PATID
WHERE ADDRESS_PERIOD_END is null OR ADDRESS_PERIOD_END >= DATEFROMPARTS(2018,01,01);

--MED_ADMIN
--OUTPUT_FILE: MED_ADMIN.csv
SELECT
   MEDADMINID,
   MED_ADMIN.PATID,
   ENCOUNTERID,
   PRESCRIBINGID,
   MEDADMIN_PROVIDERID,
   CAST(MEDADMIN_START_DATE as datetime) as MEDADMIN_START_DATE,
   MEDADMIN_START_TIME,
   CAST(MEDADMIN_STOP_DATE as datetime) as MEDADMIN_STOP_DATE,
   MEDADMIN_STOP_TIME,
   MEDADMIN_TYPE,
   MEDADMIN_CODE,
   MEDADMIN_DOSE_ADMIN,
   MEDADMIN_DOSE_ADMIN_UNIT,
   MEDADMIN_ROUTE,
   MEDADMIN_SOURCE,
   RAW_MEDADMIN_MED_NAME,
   null as RAW_MEDADMIN_CODE,
   null as RAW_MEDADMIN_DOSE_ADMIN,
   null as RAW_MEDADMIN_DOSE_ADMIN_UNIT,
   null as RAW_MEDADMIN_ROUTE
FROM @cdmDatabaseSchema.MED_ADMIN JOIN @resultsDatabaseSchema.N3C_COHORT ON MED_ADMIN.PATID = N3C_COHORT.PATID
WHERE MEDADMIN_START_DATE >= DATEFROMPARTS(2018,01,01);

--OBS_CLIN
--OUTPUT_FILE: OBS_CLIN.csv
SELECT
   OBSCLINID,
   OBS_CLIN.PATID,
   ENCOUNTERID,
   OBSCLIN_PROVIDERID,
   CAST(OBSCLIN_START_DATE as datetime) as OBSCLIN_START_DATE,
   OBSCLIN_START_TIME,
   CAST(OBSCLIN_STOP_DATE as datetime) as OBSCLIN_STOP_DATE,
   OBSCLIN_STOP_TIME,
   OBSCLIN_TYPE,
   OBSCLIN_CODE,
   OBSCLIN_RESULT_QUAL,
   OBSCLIN_RESULT_TEXT,
   OBSCLIN_RESULT_SNOMED,
   OBSCLIN_RESULT_NUM,
   OBSCLIN_RESULT_MODIFIER,
   OBSCLIN_RESULT_UNIT,
   OBSCLIN_SOURCE,
   OBSCLIN_ABN_IND,
   null as RAW_OBSCLIN_NAME,
   null as RAW_OBSCLIN_CODE,
   null as RAW_OBSCLIN_TYPE,
   null as RAW_OBSCLIN_RESULT,
   null as RAW_OBSCLIN_MODIFIER,
   null as RAW_OBSCLIN_UNIT
FROM @cdmDatabaseSchema.OBS_CLIN JOIN @resultsDatabaseSchema.N3C_COHORT ON OBS_CLIN.PATID = N3C_COHORT.PATID
WHERE OBSCLIN_START_DATE >= DATEFROMPARTS(2018,01,01);

--OBS_GEN
--OUTPUT_FILE: OBS_GEN.csv
SELECT
   OBSGENID,
   OBS_GEN.PATID,
   ENCOUNTERID,
   OBSGEN_PROVIDERID,
   CAST(OBSGEN_START_DATE as datetime) as OBSGEN_START_DATE,
   OBSGEN_START_TIME,
   CAST(OBSGEN_STOP_DATE as datetime) as OBSGEN_STOP_DATE,
   OBSGEN_STOP_TIME,
   OBSGEN_TYPE,
   OBSGEN_CODE,
   OBSGEN_RESULT_QUAL,
   OBSGEN_RESULT_TEXT,
   OBSGEN_RESULT_NUM,
   OBSGEN_RESULT_MODIFIER,
   OBSGEN_RESULT_UNIT,
   OBSGEN_TABLE_MODIFIED,
   OBSGEN_ID_MODIFIED,
   OBSGEN_SOURCE,
   OBSGEN_ABN_IND,
   null as RAW_OBSGEN_NAME,
   null as RAW_OBSGEN_CODE,
   null as RAW_OBSGEN_TYPE,
   null as RAW_OBSGEN_RESULT,
   null as RAW_OBSGEN_UNIT
FROM @cdmDatabaseSchema.OBS_GEN JOIN @resultsDatabaseSchema.N3C_COHORT ON OBS_GEN.PATID = N3C_COHORT.PATID
WHERE OBSGEN_START_DATE >= DATEFROMPARTS(2018,01,01);

--PRESCRIBING
--OUTPUT_FILE: PRESCRIBING.csv
SELECT
   PRESCRIBINGID,
   PRESCRIBING.PATID,
   ENCOUNTERID,
   RX_PROVIDERID,
   CAST(RX_ORDER_DATE as datetime) as RX_ORDER_DATE,
   RX_ORDER_TIME,
   CAST(RX_START_DATE as datetime) as RX_START_DATE,
   CAST(RX_END_DATE as datetime) as RX_END_DATE,
   RX_DOSE_ORDERED,
   RX_DOSE_ORDERED_UNIT,
   RX_QUANTITY,
   RX_DOSE_FORM,
   RX_REFILLS,
   RX_DAYS_SUPPLY,
   RX_FREQUENCY,
   RX_PRN_FLAG,
   RX_ROUTE,
   RX_BASIS,
   RXNORM_CUI,
   RX_SOURCE,
   RX_DISPENSE_AS_WRITTEN,
   RAW_RX_MED_NAME,
   null as RAW_RX_FREQUENCY,
   null as RAW_RXNORM_CUI,
   null as RAW_RX_QUANTITY,
   null as RAW_RX_NDC,
   null as RAW_RX_DOSE_ORDERED,
   null as RAW_RX_DOSE_ORDERED_UNIT,
   null as RAW_RX_ROUTE,
   null as RAW_RX_REFILLS
FROM @cdmDatabaseSchema.PRESCRIBING JOIN @resultsDatabaseSchema.N3C_COHORT ON PRESCRIBING.PATID = N3C_COHORT.PATID
WHERE RX_START_DATE >= DATEFROMPARTS(2018,01,01);

--PRO_CM
--OUTPUT_FILE: PRO_CM.csv
SELECT
   PRO_CM_ID,
   PRO_CM.PATID,
   ENCOUNTERID,
   CAST(PRO_DATE as datetime) as PRO_DATE,
   PRO_TIME,
   PRO_TYPE,
   PRO_ITEM_NAME,
   PRO_ITEM_LOINC,
   PRO_RESPONSE_TEXT,
   PRO_RESPONSE_NUM,
   PRO_METHOD,
   PRO_MODE,
   PRO_CAT,
   PRO_SOURCE,
   PRO_ITEM_VERSION,
   PRO_MEASURE_NAME,
   PRO_MEASURE_SEQ,
   PRO_MEASURE_SCORE,
   PRO_MEASURE_THETA,
   PRO_MEASURE_SCALED_TSCORE,
   PRO_MEASURE_STANDARD_ERROR,
   PRO_MEASURE_COUNT_SCORED,
   PRO_MEASURE_LOINC,
   PRO_MEASURE_VERSION,
   PRO_ITEM_FULLNAME,
   PRO_ITEM_TEXT,
   PRO_MEASURE_FULLNAME
FROM @cdmDatabaseSchema.PRO_CM JOIN @resultsDatabaseSchema.N3C_COHORT ON PRO_CM.PATID = N3C_COHORT.PATID
WHERE PRO_DATE >= DATEFROMPARTS(2018,01,01);

--PROCEDURES
--OUTPUT_FILE: PROCEDURES.csv
SELECT
   PROCEDURESID,
   PROCEDURES.PATID,
   ENCOUNTERID,
   ENC_TYPE,
   CAST(ADMIT_DATE as datetime) as ADMIT_DATE,
   PROVIDERID,
   CAST(PX_DATE as datetime) as PX_DATE,
   PX,
   PX_TYPE,
   PX_SOURCE,
   PPX,
   null as RAW_PX,
   null as RAW_PX_TYPE,
   null as RAW_PPX
FROM @cdmDatabaseSchema.PROCEDURES JOIN @resultsDatabaseSchema.N3C_COHORT ON PROCEDURES.PATID = N3C_COHORT.PATID
WHERE PX_DATE >= DATEFROMPARTS(2018,01,01);

--PROVIDER
--OUTPUT_FILE: PROVIDER.csv
SELECT
   PROVIDERID,
   PROVIDER_SEX,
   PROVIDER_SPECIALTY_PRIMARY,
   null as PROVIDER_NPI,	--to avoid accidentally identifying sites
   null as PROVIDER_NPI_FLAG,
   null as RAW_PROVIDER_SPECIALTY_PRIMARY
FROM @cdmDatabaseSchema.PROVIDER
;
--VITAL
--OUTPUT_FILE: VITAL.csv
SELECT
   VITALID,
   VITAL.PATID,
   ENCOUNTERID,
   CAST(MEASURE_DATE as datetime) as MEASURE_DATE,
   MEASURE_TIME,
   VITAL_SOURCE,
   HT,
   WT,
   DIASTOLIC,
   SYSTOLIC,
   ORIGINAL_BMI,
   BP_POSITION,
   SMOKING,
   TOBACCO,
   TOBACCO_TYPE,
   null as RAW_DIASTOLIC,
   null as RAW_SYSTOLIC,
   null as RAW_BP_POSITION,
   null as RAW_SMOKING,
   null as RAW_TOBACCO,
   null as RAW_TOBACCO_TYPE
FROM @cdmDatabaseSchema.VITAL JOIN @resultsDatabaseSchema.N3C_COHORT ON VITAL.PATID = N3C_COHORT.PATID
WHERE MEASURE_DATE >= DATEFROMPARTS(2018,01,01);

--DATA_COUNTS TABLE
--OUTPUT_FILE: DATA_COUNTS.csv
(select
   'DEMOGRAPHIC' as TABLE_NAME,
   (select count(*) FROM @cdmDatabaseSchema.DEMOGRAPHIC JOIN @resultsDatabaseSchema.N3C_COHORT ON DEMOGRAPHIC.PATID = N3C_COHORT.PATID) as ROW_COUNT

UNION

select
   'ENCOUNTER' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.ENCOUNTER JOIN @resultsDatabaseSchema.N3C_COHORT ON ENCOUNTER.PATID = N3C_COHORT.PATID AND ADMIT_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'CONDITION' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.CONDITION JOIN @resultsDatabaseSchema.N3C_COHORT ON CONDITION.PATID = N3C_COHORT.PATID AND REPORT_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'DEATH' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.DEATH JOIN @resultsDatabaseSchema.N3C_COHORT ON DEATH.PATID = N3C_COHORT.PATID) as ROW_COUNT

UNION

select
   'DEATH_CAUSE' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.DEATH_CAUSE JOIN @resultsDatabaseSchema.N3C_COHORT ON DEATH_CAUSE.PATID = N3C_COHORT.PATID) as ROW_COUNT

UNION

select
   'DIAGNOSIS' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.DIAGNOSIS JOIN @resultsDatabaseSchema.N3C_COHORT ON DIAGNOSIS.PATID = N3C_COHORT.PATID AND (DX_DATE >= DATEFROMPARTS(2018,01,01) OR ADMIT_DATE >= DATEFROMPARTS(2018,01,01))) as ROW_COUNT

UNION

select
   'DISPENSING' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.DISPENSING JOIN @resultsDatabaseSchema.N3C_COHORT ON DISPENSING.PATID = N3C_COHORT.PATID AND DISPENSE_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'IMMUNIZATION' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.IMMUNIZATION JOIN @resultsDatabaseSchema.N3C_COHORT ON IMMUNIZATION.PATID = N3C_COHORT.PATID) as ROW_COUNT

UNION

select
   'LAB_RESULT_CM' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.LAB_RESULT_CM JOIN @resultsDatabaseSchema.N3C_COHORT ON LAB_RESULT_CM.PATID = N3C_COHORT.PATID AND (LAB_ORDER_DATE >= DATEFROMPARTS(2018,01,01) OR RESULT_DATE >= DATEFROMPARTS(2018,01,01))) as ROW_COUNT

UNION

select
   'LDS_ADDRESS_HISTORY' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.LDS_ADDRESS_HISTORY JOIN @resultsDatabaseSchema.N3C_COHORT ON LDS_ADDRESS_HISTORY.PATID = N3C_COHORT.PATID
	AND (ADDRESS_PERIOD_END is null OR ADDRESS_PERIOD_END >= DATEFROMPARTS(2018,01,01))) as ROW_COUNT

UNION

select
   'MED_ADMIN' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.MED_ADMIN JOIN @resultsDatabaseSchema.N3C_COHORT ON MED_ADMIN.PATID = N3C_COHORT.PATID AND MEDADMIN_START_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'OBS_CLIN' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.OBS_CLIN JOIN @resultsDatabaseSchema.N3C_COHORT ON OBS_CLIN.PATID = N3C_COHORT.PATID AND OBSCLIN_START_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'OBS_GEN' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.OBS_GEN JOIN @resultsDatabaseSchema.N3C_COHORT ON OBS_GEN.PATID = N3C_COHORT.PATID and OBSGEN_START_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'PRESCRIBING' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.PRESCRIBING JOIN @resultsDatabaseSchema.N3C_COHORT ON PRESCRIBING.PATID = N3C_COHORT.PATID AND RX_START_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'PRO_CM' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.PRO_CM JOIN @resultsDatabaseSchema.N3C_COHORT ON PRO_CM.PATID = N3C_COHORT.PATID AND PRO_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'PROCEDURES' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.PROCEDURES JOIN @resultsDatabaseSchema.N3C_COHORT ON PROCEDURES.PATID = N3C_COHORT.PATID AND PX_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT

UNION

select
   'PROVIDER' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.PROVIDER) as ROW_COUNT

UNION


select
   'VITAL' as TABLE_NAME,
   (select count(*) from @cdmDatabaseSchema.VITAL JOIN @resultsDatabaseSchema.N3C_COHORT ON VITAL.PATID = N3C_COHORT.PATID AND MEASURE_DATE >= DATEFROMPARTS(2018,01,01)) as ROW_COUNT
);
