CREATE OR REPLACE PACKAGE "RPT_SGP_AGY_PKG" IS
	C_REMOVEDATE DATE := TO_DATE( '2200-01-01', 'YYYY-MM-DD' );

	V_ERROR_CODE	VARCHAR2( 255 );
	V_ERROR_MESSAGE	VARCHAR2( 255 );

	PROCEDURE ERROR_LOGGING;
	PROCEDURE INIT;
	
	PROCEDURE UPD_PAQPB_FRM_CRTBL( 
		strFieldName	IN VARCHAR2, 
		strKey			IN VARCHAR2, 
		strSelect		IN VARCHAR2, 
		rptPeriodSeq	IN RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE, 
		periodSeqInQtr	IN RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE
	);
	PROCEDURE UPD_PAQPB_FRM_INITTBL( 
		strFieldName	IN VARCHAR2, 
		strKey			IN VARCHAR2, 
		strKey2			IN VARCHAR2, 
		strSelect		IN VARCHAR2, 
		rptPeriodSeq	IN RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE, 
		periodSeqInQtr	IN RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE
	);
	
	--20140427: added by Donny
	PROCEDURE SP_RPT_SG_NSMAN_INCOME (V_PERIODSEQ RPT_SG_NSMAN_INCOME.PERIODSEQ%TYPE);
	
  PROCEDURE RPT_AIA_PARIS (V_PERIODSEQ CS_PERIOD.PERIODSEQ%TYPE);
  
	PROCEDURE RPT_CLERICAL_ALLOWANCE;
	PROCEDURE RPT_PA_QTR_PRD_BONUS;
	PROCEDURE RPT_PRD_BENEFIT_FRM_UM;
	PROCEDURE RPT_POPULATE_ALL;
END;
/
CREATE OR REPLACE PACKAGE BODY "RPT_SGP_AGY_PKG" IS
	------position version start date always equal to participant
	------position latest version end date always equal to end of time
	------position terminated status is updated on participant
	V_CALENDARNAME			CS_CALENDAR.NAME%TYPE;
	V_PERIODSEQ				CS_PERIOD.PERIODSEQ%TYPE;
	V_PERIODNAME			CS_PERIOD.NAME%TYPE;
	V_PERIODPARENTSEQ		CS_PERIOD.PARENTSEQ%TYPE;
	V_PERIODSTARTDATE		CS_PERIOD.STARTDATE%TYPE;
	V_PERIODENDDATE			CS_PERIOD.ENDDATE%TYPE;
	V_CALENDARSEQ			CS_CALENDAR.CALENDARSEQ%TYPE;
	V_PERIODTYPESEQ			CS_PERIODTYPE.PERIODTYPESEQ%TYPE;
	------the prior period
	V_PRIOR_PERIODSEQ		CS_PERIOD.PERIODSEQ%TYPE;
	
	V_FINYEAR_STARTDATE		DATE;
	V_CURR_CYCLE_DATE		DATE;
	
	-- Other variables
	nCount				NUMBER;
	dCycleDate			DATE;

	
	PROCEDURE ERROR_LOGGING IS BEGIN
		V_ERROR_CODE    := SQLCODE;
		V_ERROR_MESSAGE := SQLERRM;
		INSERT INTO AIA_ERROR_MESSAGE( RECORDNO, ERRORCODE, ERRORMESSAGE, ERRORBACKTRACE, CREATEDATE )
		VALUES( AIA_ERROR_MESSAGE_S.NEXTVAL, V_ERROR_CODE, V_ERROR_MESSAGE, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, SYSDATE );
		COMMIT;
	EXCEPTION
	WHEN OTHERS THEN
		NULL;
	END;
	
	PROCEDURE INIT 
	IS 
		sCurrCycleYear		VARCHAR2( 04 );
		sCurrCycleMonth		VARCHAR2( 02 );
	BEGIN
		SELECT PERD.PERIODSEQ, CAL.CALENDARSEQ, CAL.NAME, PERT.PERIODTYPESEQ, PERD.NAME, PERD.STARTDATE, PERD.ENDDATE, PERD.PARENTSEQ 
		INTO V_PERIODSEQ, V_CALENDARSEQ, V_CALENDARNAME, V_PERIODTYPESEQ, V_PERIODNAME, V_PERIODSTARTDATE, V_PERIODENDDATE, V_PERIODPARENTSEQ
		FROM CS_PERIOD PERD, CS_PERIODTYPE PERT, CS_CALENDAR CAL
		WHERE PERD.CALENDARSEQ = CAL.CALENDARSEQ
				AND PERD.PERIODTYPESEQ = PERT.PERIODTYPESEQ
				AND PERD.REMOVEDATE = C_REMOVEDATE
				AND PERT.REMOVEDATE = C_REMOVEDATE
				AND CAL.REMOVEDATE = C_REMOVEDATE
				AND CAL.NAME = 'AIA Singapore Calendar'
				--@TODO: May need to change this portion
				AND UPPER( PERD.NAME ) = ( SELECT TRIM( TO_CHAR( TO_DATE( txt_key_value, 'YYYY-MM-DD' ), 'MONTH' ) ) 
											|| ' ' || TO_CHAR( TO_DATE( txt_key_value, 'YYYY-MM-DD' ),'YYYY' )
											FROM in_etl_control
											WHERE txt_key_string = 'OPER_CYCLE_DATE'
											AND TXT_FILE_NAME = 'GLOBAL'
										);
				/*
				AND UPPER( PERD.NAME ) = ( SELECT TRIM( TO_CHAR( TO_DATE( txt_key_value, 'YYYY-MM-DD' ), 'MONTH' ) ) 
											|| ' ' || TO_CHAR( TO_DATE( txt_key_value, 'YYYY-MM-DD' ),'YYYY' )
											FROM in_etl_control
											WHERE txt_key_string = 'CYCLE_DATE'
											AND TXT_FILE_NAME = 'REPORT'
										);
				*/
				
		--get prior period key
		SELECT PERD.PERIODSEQ
		INTO V_PRIOR_PERIODSEQ
		FROM CS_PERIOD PERD
		WHERE PERD.REMOVEDATE = C_REMOVEDATE
				AND PERD.CALENDARSEQ = V_CALENDARSEQ
				AND PERD.PERIODTYPESEQ = V_PERIODTYPESEQ
				AND PERD.ENDDATE = V_PERIODSTARTDATE;	

		--get current cycle date and beginning date of financial year
		V_CURR_CYCLE_DATE := V_PERIODENDDATE - 1;
		sCurrCycleMonth := EXTRACT( MONTH FROM V_CURR_CYCLE_DATE );
		sCurrCycleYear := EXTRACT( YEAR FROM V_CURR_CYCLE_DATE );
		IF( sCurrCycleMonth != '12' ) THEN
			sCurrCycleYear := sCurrCycleYear - 1;
		END IF;
		V_FINYEAR_STARTDATE := TO_DATE( '01-12-' || sCurrCycleYear, 'DD-MM-YYYY' );

		DBMS_OUTPUT.PUT_LINE( 'V_PERIODSEQ: ' || V_PERIODSEQ );
		DBMS_OUTPUT.PUT_LINE( 'V_CALENDARSEQ: ' || V_CALENDARSEQ );
		DBMS_OUTPUT.PUT_LINE( 'V_CALENDARNAME: ' || V_CALENDARNAME );
		DBMS_OUTPUT.PUT_LINE( 'V_PERIODTYPESEQ: ' || V_PERIODTYPESEQ );
		DBMS_OUTPUT.PUT_LINE( 'V_PERIODNAME: ' || V_PERIODNAME );
		DBMS_OUTPUT.PUT_LINE( 'V_PERIODSTARTDATE: ' || V_PERIODSTARTDATE );
		DBMS_OUTPUT.PUT_LINE( 'V_PERIODENDDATE: ' || V_PERIODENDDATE );
		DBMS_OUTPUT.PUT_LINE( 'V_PRIOR_PERIODSEQ: ' || V_PRIOR_PERIODSEQ );
		DBMS_OUTPUT.PUT_LINE( 'V_PERIODPARENTSEQ: ' || V_PERIODPARENTSEQ );
		DBMS_OUTPUT.PUT_LINE( 'V_CURR_CYCLE_DATE: ' || V_CURR_CYCLE_DATE );
		DBMS_OUTPUT.PUT_LINE( 'V_FINYEAR_STARTDATE: ' || V_FINYEAR_STARTDATE );
	EXCEPTION
	WHEN OTHERS THEN
		ERROR_LOGGING;
	END;
	
	PROCEDURE RPT_CLERICAL_ALLOWANCE IS 	
		CURSOR AGENCY_CODE_Cur IS
			SELECT DISTRICT_CODE, UNIT_CODE
			FROM RPT_SGPAGY_CLERICAL_ALLOWANCE
			WHERE PERIODSEQ = V_PERIODSEQ;
		
		V_DISTRICT_CODE		RPT_SGPAGY_CLERICAL_ALLOWANCE.DISTRICT_CODE%TYPE;
		V_UNIT_CODE			RPT_SGPAGY_CLERICAL_ALLOWANCE.UNIT_CODE%TYPE;
		V_PREVIOUS_CLA		NUMBER( 15, 5 ) := 0;
		V_REPORT_ROWS		RPT_SGPAGY_CLERICAL_ALLOWANCE%ROWTYPE;
		V_DEPOSITSEQ		NUMBER( 38, 0 );	
		V_INCENTIVESEQ		NUMBER( 38, 0 );
		V_CLA_RATE			NUMBER( 15, 5 );
		V_IS_HELD			NUMBER( 1, 0 );
		V_RELEASE_DATE		DATE;
	BEGIN  
		/*
			Delete same cycle date if re-run multiple times for same period
		*/
		nCount := 0;
		SELECT COUNT( * ) INTO nCount
		FROM  RPT_SGPAGY_CLERICAL_ALLOWANCE
		WHERE PERIODSEQ = V_PERIODSEQ;
		DBMS_OUTPUT.PUT_LINE( 'Before Delete RPT_SGPAGY_CLERICAL_ALLOWANCE: ' || V_PERIODSEQ || ' ' || nCount );
		EXECUTE IMMEDIATE 'DELETE FROM RPT_SGPAGY_CLERICAL_ALLOWANCE WHERE PERIODSEQ = ' || V_PERIODSEQ;
		
		/*
			Eligible to receive CLA is DM only. Also show DM's team that make contribution for this CLA
			Base on Deposit D_Clerical_Allowance_SG
		*/
		-- District and its direct team
		INSERT INTO RPT_SGPAGY_CLERICAL_ALLOWANCE( PERIODSEQ, CYCLEDATE, PERIODNAME, 
					PARTICIPANTSEQ, POSITIONSEQ, POSITIONNAME, 
					DEPOSITSEQ, INCENTIVESEQ, 
					DISTRICT_CODE, DISTRICT_NAME, DISTRICT_LEADER_CODE, DISTRICT_LEADER_NAME, 
					UNIT_CODE, UNIT_NAME, UNIT_LEADER_CODE, UNIT_LEADER_NAME, 
					UNIT_LEADER_TITLE, UNIT_LEADER_CLASS, UNIT_DISSOLVED_DATE, 
					CLA_RATE, IS_HELD, RELEASE_DATE )
		SELECT	mtagent.PERIODSEQ, mtagent.CYCLEDATE, mtagent.PERIODNAME, 
				d.PAYEESEQ, d.POSITIONSEQ, mtagent.POSITIONNAME, 
				d.DEPOSITSEQ, i.INCENTIVESEQ, 
				mtagent.DISTRICT_CODE, mtagent.DISTRICT_NAME, mtagent.DISTRICT_LEADER_CODE, mtagent.DISTRICT_LEADER_NAME, 
				mtagent.UNIT_CODE, mtagent.UNIT_NAME, mtagent.UNIT_LEADER_CODE, mtagent.UNIT_LEADER_NAME, 
				mtagent.TITLE, mtagent.CLASS_CODE, mtagent.TERMINATION_DATE, 
				CASE
					WHEN( i.GENERICNUMBER1 = 0 OR i.GENERICNUMBER1 IS NULL ) THEN 2.5
					ELSE i.GENERICNUMBER1
				END AS CLA_RATE, 
				d.ISHELD, d.RELEASEDATE
		FROM	CS_DEPOSIT d
				LEFT JOIN CS_DEPOSITINCENTIVETRACE di ON d.depositseq = di.depositseq
				LEFT JOIN CS_INCENTIVE i ON di.incentiveseq = i.incentiveseq
				LEFT JOIN RPT_MASTER_AGENT mtagent ON mtagent.PERIODSEQ = V_PERIODSEQ AND d.POSITIONSEQ = mtagent.POSITIONSEQ
		WHERE	d.PERIODSEQ = V_PERIODSEQ
				AND d.NAME = 'D_Clerical_Allowance_SG';

		UPDATE	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
		SET	CURR_MONTH_PIB = ( SELECT SUM( m.VALUE ) 
								FROM CS_INCENTIVEPMTRACE ip 
								LEFT JOIN CS_MEASUREMENT m ON ip.measurementseq = m.measurementseq
								WHERE m.name IN( 'PM_PIB_DIRECT_TEAM_Manager_Personal', 'PM_PIB_DIRECT_TEAM_Not_Assigned' )
								AND ip.incentiveseq = rpt.INCENTIVESEQ
							)
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ;
		UPDATE	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
		SET	CURR_MONTH_RY_COMM = ( SELECT SUM( m.VALUE ) 
									FROM CS_INCENTIVEPMTRACE ip 
									LEFT JOIN CS_MEASUREMENT m ON ip.measurementseq = m.measurementseq
									WHERE m.name IN( 'PM_RYC_CS_DIRECT_TEAM', 'PM_RYC_PA_DIRECT_TEAM', 'PM_RYC_Y2-6_LF_DIRECT_TEAM' )
									AND ip.incentiveseq = rpt.INCENTIVESEQ
								)
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ;
		
		--V_DEPOSITSEQ, V_INCENTIVESEQ, V_CLA_RATE, V_IS_HELD, V_RELEASE_DATE	
		/*SELECT	*
		INTO	V_REPORT_ROWS
		FROM	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ;*/

		-- Unit and its team (Indirect team of District)
		INSERT INTO RPT_SGPAGY_CLA_TEMP
		SELECT	rpt.POSITIONSEQ, 'SGY' || c.genericattribute13, SUM( c.value ), 'SM_PIB_INDIRECT_TEAM_SG'
		FROM	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt 
				LEFT JOIN CS_INCENTIVEPMTRACE ip ON rpt.INCENTIVESEQ = ip.INCENTIVESEQ
				LEFT JOIN CS_MEASUREMENT m ON ip.measurementseq = m.measurementseq
				LEFT JOIN cs_pmselftrace pmst ON m.measurementseq = pmst.targetmeasurementseq
				LEFT JOIN cs_pmcredittrace pmct ON pmst.sourcemeasurementseq = pmct.measurementseq
				LEFT JOIN cs_credit c ON pmct.creditseq = c.creditseq
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ 
				AND m.name IN( 'SM_PIB_INDIRECT_TEAM_SG' )
				AND pmst.contributionvalue <> 0
		GROUP BY rpt.POSITIONSEQ, c.genericattribute13;
		INSERT INTO RPT_SGPAGY_CLA_TEMP
		SELECT	rpt.POSITIONSEQ, 'SGY' || c.genericattribute13, SUM( c.value ), 'SM_CA_RYC_INDIRECT_TEAM_SG'
		FROM	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt 
				LEFT JOIN CS_INCENTIVEPMTRACE ip ON rpt.INCENTIVESEQ = ip.INCENTIVESEQ
				LEFT JOIN CS_MEASUREMENT m ON ip.measurementseq = m.measurementseq
				LEFT JOIN cs_pmselftrace pmst ON m.measurementseq = pmst.targetmeasurementseq
				LEFT JOIN cs_pmcredittrace pmct ON pmst.sourcemeasurementseq = pmct.measurementseq
				LEFT JOIN cs_credit c ON pmct.creditseq = c.creditseq
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ
				AND m.name IN( 'SM_CA_RYC_INDIRECT_TEAM_SG' )
				AND pmst.contributionvalue <> 0
		GROUP BY rpt.POSITIONSEQ, c.genericattribute13;
	
		INSERT INTO RPT_SGPAGY_CLERICAL_ALLOWANCE( PERIODSEQ, CYCLEDATE, PERIODNAME, 
					PARTICIPANTSEQ, POSITIONSEQ, POSITIONNAME, 
					DEPOSITSEQ, INCENTIVESEQ,
					DISTRICT_CODE, DISTRICT_NAME, DISTRICT_LEADER_CODE, DISTRICT_LEADER_NAME, 
					UNIT_CODE, UNIT_NAME, UNIT_LEADER_CODE, UNIT_LEADER_NAME, 
					UNIT_LEADER_TITLE, UNIT_LEADER_CLASS, UNIT_DISSOLVED_DATE,
					CLA_RATE, IS_HELD, RELEASE_DATE )
		SELECT DISTINCT mtagent.PERIODSEQ, mtagent.CYCLEDATE, mtagent.PERIODNAME, 
				mtagent.PARTICIPANTSEQ, mtagent.POSITIONSEQ, temp.POSITIONNAME, 
				rpt.DEPOSITSEQ, rpt.INCENTIVESEQ, 
				mtagent.DISTRICT_CODE, mtagent.DISTRICT_NAME, mtagent.DISTRICT_LEADER_CODE, mtagent.DISTRICT_LEADER_NAME, 
				mtagent.UNIT_CODE, mtagent.UNIT_NAME, mtagent.UNIT_LEADER_CODE, mtagent.UNIT_LEADER_NAME, 
				mtagent.TITLE, mtagent.CLASS_CODE, mtagent.TERMINATION_DATE, 
				rpt.CLA_RATE, rpt.IS_HELD, rpt.RELEASE_DATE 
		FROM	RPT_SGPAGY_CLA_TEMP temp
				LEFT JOIN RPT_MASTER_AGENT mtagent ON mtagent.PERIODSEQ = V_PERIODSEQ AND temp.POSITIONNAME = mtagent.POSITIONNAME
				LEFT JOIN RPT_SGPAGY_CLERICAL_ALLOWANCE rpt ON rpt.PERIODSEQ = V_PERIODSEQ AND temp.PARENTPOSITIONSEQ = rpt.POSITIONSEQ;
		
		UPDATE	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
		SET	CURR_MONTH_PIB = ( SELECT temp.CONTRIBUTIONVALUE 
								FROM RPT_SGPAGY_CLA_TEMP temp 
								WHERE temp.MEASUREMENTNAME = 'SM_PIB_INDIRECT_TEAM_SG'
								AND temp.POSITIONNAME = rpt.POSITIONNAME
							)
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ
				AND rpt.POSITIONNAME IN( SELECT temp.POSITIONNAME 
									FROM RPT_SGPAGY_CLA_TEMP temp 
									WHERE temp.MEASUREMENTNAME = 'SM_PIB_INDIRECT_TEAM_SG'
								);
		UPDATE	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
		SET	CURR_MONTH_RY_COMM = ( SELECT temp.CONTRIBUTIONVALUE 
								FROM RPT_SGPAGY_CLA_TEMP temp 
								WHERE temp.MEASUREMENTNAME = 'SM_CA_RYC_INDIRECT_TEAM_SG'
								AND temp.POSITIONNAME = rpt.POSITIONNAME
							)
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ
				AND rpt.POSITIONNAME IN( SELECT temp.POSITIONNAME 
									FROM RPT_SGPAGY_CLA_TEMP temp 
									WHERE temp.MEASUREMENTNAME = 'SM_CA_RYC_INDIRECT_TEAM_SG'
								);
		UPDATE	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
		SET	UNIT_LEADER_TITLE = ( SELECT mtagent.TITLE
								FROM RPT_MASTER_AGENT mtagent
								WHERE mtagent.PERIODSEQ = V_PERIODSEQ 
								AND mtagent.POSITIONNAME = 'SGT' || rpt.UNIT_LEADER_CODE
							)
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ
				AND rpt.POSITIONNAME LIKE 'SGY%';
		
		-- Both district and unit
		UPDATE	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
		SET	CURR_MONTH_FY_CLA = CURR_MONTH_PIB * CLA_RATE,
			CURR_MONTH_RY_CLA = CURR_MONTH_RY_COMM * CLA_RATE
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ;
		UPDATE	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
		SET	CURR_MONTH_CLA_TOTAL = CURR_MONTH_FY_CLA + CURR_MONTH_RY_CLA
		WHERE	rpt.PERIODSEQ = V_PERIODSEQ;	
		
		OPEN AGENCY_CODE_Cur;
		LOOP
			FETCH AGENCY_CODE_Cur INTO V_DISTRICT_CODE, V_UNIT_CODE;
			EXIT WHEN AGENCY_CODE_Cur%NOTFOUND;
			
			V_PREVIOUS_CLA := 0;
			nCount := 0;
			SELECT	COUNT( * ) INTO nCount
			FROM	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
			WHERE	PERIODSEQ = V_PRIOR_PERIODSEQ
					AND DISTRICT_CODE = V_DISTRICT_CODE
					AND UNIT_CODE = V_UNIT_CODE;
			IF( nCount <= 0 ) THEN
				--DBMS_OUTPUT.PUT_LINE( V_PRIOR_PERIODSEQ || ' - District( ' || V_DISTRICT_CODE || ' ) and Unit( ' || V_UNIT_CODE || ' ). Not exist in RPT_SGPAGY_CLERICAL_ALLOWANCE...' );
				nCount := 0;
				SELECT	COUNT( * ) INTO nCount
				FROM	RPT_INIT_HISTORY_LKP
				WHERE	PERIODSEQ = V_PRIOR_PERIODSEQ
						AND KEY_STR_1 = 'SGPAGY_CLA'
						AND KEY_STR_2 = V_DISTRICT_CODE
						AND KEY_STR_3 = V_UNIT_CODE;
				IF( nCount <= 0 ) THEN
					--DBMS_OUTPUT.PUT_LINE( V_PRIOR_PERIODSEQ || ' - District( ' || V_DISTRICT_CODE || ' ) and Unit( ' || V_UNIT_CODE || ' ). Not exist in RPT_INIT_HISTORY_LKP...' );
					V_PREVIOUS_CLA := 0;
				ELSE
					SELECT	SUM( NVALUE_1 ) INTO V_PREVIOUS_CLA
					FROM	RPT_INIT_HISTORY_LKP
					WHERE	PERIODSEQ = V_PRIOR_PERIODSEQ
							AND KEY_STR_1 = 'SGPAGY_CLA'
							AND KEY_STR_2 = V_DISTRICT_CODE
							AND KEY_STR_3 = V_UNIT_CODE;
				END IF;
			ELSE 
				SELECT	SUM( YTD_CLA ) INTO V_PREVIOUS_CLA
				FROM	RPT_SGPAGY_CLERICAL_ALLOWANCE rpt
				WHERE	PERIODSEQ = V_PRIOR_PERIODSEQ
						AND DISTRICT_CODE= V_DISTRICT_CODE
						AND UNIT_CODE = V_UNIT_CODE;
			END IF;
			
			--DBMS_OUTPUT.PUT_LINE( 'Previous CLA for District( ' || V_DISTRICT_CODE || ' ) and Unit( ' || V_UNIT_CODE || ' ): ' || V_PREVIOUS_CLA );
			UPDATE	RPT_SGPAGY_CLERICAL_ALLOWANCE
			SET	YTD_CLA = CURR_MONTH_CLA_TOTAL + V_PREVIOUS_CLA
			WHERE	PERIODSEQ = V_PERIODSEQ
					AND DISTRICT_CODE= V_DISTRICT_CODE
					AND UNIT_CODE = V_UNIT_CODE;
			
			--DBMS_OUTPUT.PUT_LINE( 'Loop' );
		END LOOP;
		CLOSE AGENCY_CODE_Cur;
		
		DELETE FROM RPT_SGPAGY_CLERICAL_ALLOWANCE
		WHERE	PERIODSEQ = V_PERIODSEQ
				AND CURR_MONTH_FY_CLA = 0
				AND CURR_MONTH_RY_CLA = 0
				AND CURR_MONTH_CLA_TOTAL = 0;
		nCount := 0;
		SELECT COUNT( * ) INTO nCount
		FROM  RPT_SGPAGY_CLERICAL_ALLOWANCE
		WHERE PERIODSEQ = V_PERIODSEQ;
		DBMS_OUTPUT.PUT_LINE( 'Inserted ' || nCount || ' records into RPT_SGPAGY_CLERICAL_ALLOWANCE...' );
		IF( nCount <= 0 ) THEN        
			DBMS_OUTPUT.PUT_LINE( '0 Records in RPT_SGPAGY_CLERICAL_ALLOWANCE. Exiting...' );
			RETURN;
		END IF;
				
	EXCEPTION
	WHEN OTHERS THEN
		ERROR_LOGGING;
	END;
	
	PROCEDURE RPT_PA_QTR_PRD_BONUS IS 	
		CURSOR PERIODSEQ_Cur IS
			SELECT PERIODSEQ, PERIODNAME
			FROM RPT_SGPAGY_PAQPB_QTR_MTHS
			ORDER BY PERIODENDDATE ASC;
			
		CURSOR LY_PERIODSEQ_Cur IS
			SELECT PERIODSEQ, PERIODNAME
			FROM RPT_SGPAGY_PAQPB_LY_QTR_MTHS
			ORDER BY PERIODENDDATE ASC;
		
		V_PERIODSEQ_IN_QTR		RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE;
		V_PERIODNAME_IN_QTR		RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODNAME%TYPE;
		V_LY_PERDPARENTSEQ		RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE;
		V_LY_PERDSEQ_IN_QTR		RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE;
		V_LY_PERDNAME_IN_QTR	RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODNAME%TYPE;
		nSeq					NUMBER;
	BEGIN  
		/*
			Delete same cycle date if re-run multiple times for same period
		*/
		nCount := 0;
		SELECT COUNT( * ) INTO nCount
		FROM  RPT_SGPAGY_PA_QTR_PRD_BONUS;
		DBMS_OUTPUT.PUT_LINE( 'Before Delete RPT_SGPAGY_PA_QTR_PRD_BONUS: ' || V_PERIODSEQ || ' ' || nCount );
		EXECUTE IMMEDIATE 'DELETE FROM RPT_SGPAGY_PA_QTR_PRD_BONUS WHERE PERIODSEQ = ' || V_PERIODSEQ;
		
		INSERT INTO RPT_SGPAGY_PAQPB_QTR_MTHS
		SELECT	PERD.PERIODSEQ, PERD.CALENDARSEQ, PERD.PARENTSEQ, PERD.PERIODTYPESEQ, PERD.NAME, PERD.STARTDATE, PERD.ENDDATE
		FROM	CS_PERIOD PERD
		WHERE	PERD.REMOVEDATE = C_REMOVEDATE
				AND PERD.PARENTSEQ = V_PERIODPARENTSEQ
				AND PERD.ENDDATE <= V_PERIODENDDATE;
				
		SELECT	PERD.PERIODSEQ INTO V_LY_PERDPARENTSEQ
		FROM CS_PERIOD PERD, CS_PERIODTYPE PERT, CS_CALENDAR CAL
		WHERE PERD.CALENDARSEQ = CAL.CALENDARSEQ
				AND PERD.PERIODTYPESEQ = PERT.PERIODTYPESEQ
				AND PERD.REMOVEDATE = C_REMOVEDATE
				AND PERT.REMOVEDATE = C_REMOVEDATE
				AND CAL.REMOVEDATE = C_REMOVEDATE
				AND CAL.NAME = 'AIA Singapore Calendar'
				AND PERT.name = 'quarter'
				AND PERD.enddate = ( SELECT ADD_MONTHS( temp.enddate, -12 )
										FROM	CS_PERIOD temp
										WHERE	temp.periodseq = V_PERIODPARENTSEQ
									);
		INSERT INTO RPT_SGPAGY_PAQPB_LY_QTR_MTHS
		SELECT	PERD.PERIODSEQ, PERD.CALENDARSEQ, PERD.PARENTSEQ, PERD.PERIODTYPESEQ, PERD.NAME, PERD.STARTDATE, PERD.ENDDATE
		FROM	CS_PERIOD PERD
		WHERE	PERD.REMOVEDATE = C_REMOVEDATE
				AND PERD.PARENTSEQ = V_LY_PERDPARENTSEQ;
		
		/*
			All agents possible/eligible to get PAQPB. Those agents that have FYP, RYP (include Adjustment) and full fill Persistency
		*/
		INSERT INTO RPT_SGPAGY_PA_QTR_PRD_BONUS( PERIODSEQ, CYCLEDATE, PERIODNAME, PARTICIPANTSEQ, POSITIONSEQ, POSITIONNAME,
					AGENT_CODE, AGENT_NAME, AGENT_TITLE, AGENT_TERMINATION_DATE, 
					DISTRICT_CODE, DISTRICT_NAME, UNIT_CODE, UNIT_NAME )
		SELECT	mtagent.periodseq, mtagent.cycledate, mtagent.periodname, mtagent.participantseq, mtagent.positionseq, mtagent.positionname, 
				mtagent.agt_agy_code, mtagent.agt_agy_name, mtagent.title, mtagent.termination_date, 
				mtagent.district_code, mtagent.district_name, mtagent.unit_code, mtagent.unit_name
		FROM	RPT_MASTER_AGENT mtagent
		WHERE	mtagent.periodseq = V_PERIODSEQ
				AND mtagent.businessunit = 'SGPAGY'
				AND mtagent.positionname like '%T%';

		nSeq := 1;
		OPEN PERIODSEQ_Cur;
		LOOP
			FETCH PERIODSEQ_Cur INTO V_PERIODSEQ_IN_QTR, V_PERIODNAME_IN_QTR;
			EXIT WHEN PERIODSEQ_Cur%NOTFOUND;
			DBMS_OUTPUT.PUT_LINE( 'Current Period in Quarter (' || TO_CHAR( nSeq ) || '): ' || V_PERIODSEQ_IN_QTR || ' - ' || V_PERIODNAME_IN_QTR );
			
			nCount := 0;
			SELECT	COUNT( * ) INTO nCount
			FROM	CS_CREDIT c
			WHERE	c.PERIODSEQ = V_PERIODSEQ_IN_QTR;
      ------Begin Modified by Chao 20140803
			IF( nCount > 0 ) THEN
				--UPD_PAQPB_FRM_CRTBL( 'FYP_MTH' || nSeq || '_IN_QTR', '= ''C_FYP''', 'SUM( t.value )', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
        UPD_PAQPB_FRM_CRTBL( 'FYP_MTH' || nSeq || '_IN_QTR', '= ''PM_FYP_PA''', 'SUM( t.value )', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
				--UPD_PAQPB_FRM_CRTBL( 'RYP_MTH' || nSeq || '_IN_QTR', '= ''C_RYP''', 'SUM( t.value )', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
        UPD_PAQPB_FRM_CRTBL( 'RYP_MTH' || nSeq || '_IN_QTR', '= ''PM_RYP_PA''', 'SUM( t.value )', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
				--UPD_PAQPB_FRM_CRTBL( 'FYP_ADJ_END_QTR', '= ''C_FYP_Adjusted''', 'rpt.FYP_ADJ_END_QTR + SUM( t.value )', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
        UPD_PAQPB_FRM_CRTBL( 'FYP_ADJ_END_QTR', '= ''PM_FYP_PA_Adjusted''', 'rpt.FYP_ADJ_END_QTR + SUM( t.value )', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
				--UPD_PAQPB_FRM_CRTBL( 'RYP_ADJ_END_QTR', '= ''C_RYP_Adjusted''', 'rpt.RYP_ADJ_END_QTR + SUM( t.value )', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
        UPD_PAQPB_FRM_CRTBL( 'RYP_ADJ_END_QTR', '= ''PM_RYP_PA_Adjusted''', 'rpt.RYP_ADJ_END_QTR + SUM( t.value )', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
			ELSE
				nCount := 0;
				SELECT	COUNT( * ) INTO nCount
				FROM	RPT_INIT_HISTORY_LKP t
				WHERE	t.PERIODSEQ = V_PERIODSEQ_IN_QTR;
				IF( nCount > 0 ) THEN
					UPD_PAQPB_FRM_INITTBL( 'FYP_MTH' || nSeq || '_IN_QTR', '= ''FYP''', '', 't.NVALUE_1', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
					UPD_PAQPB_FRM_INITTBL( 'RYP_MTH' || nSeq || '_IN_QTR', '= ''RYP''', '', 't.NVALUE_1', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
					UPD_PAQPB_FRM_INITTBL( 'FYP_ADJ_END_QTR', '= ''FYP_Adjusted''', '', 'rpt.FYP_ADJ_END_QTR + t.NVALUE_1', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
					UPD_PAQPB_FRM_INITTBL( 'RYP_ADJ_END_QTR', '= ''RYP_Adjusted''', '', 'rpt.RYP_ADJ_END_QTR + t.NVALUE_1', V_PERIODSEQ, V_PERIODSEQ_IN_QTR );
				END IF;
			END IF;
      ------End Modified by Chao 20140803
			nSeq := nSeq + 1;
		END LOOP;
		CLOSE PERIODSEQ_Cur;
		
		nSeq := 1;
		OPEN LY_PERIODSEQ_Cur;
		LOOP
			FETCH LY_PERIODSEQ_Cur INTO V_LY_PERDSEQ_IN_QTR, V_LY_PERDNAME_IN_QTR;
			EXIT WHEN LY_PERIODSEQ_Cur%NOTFOUND;
			DBMS_OUTPUT.PUT_LINE( 'Last Year Period (' || TO_CHAR( nSeq ) || '): ' || V_LY_PERDSEQ_IN_QTR || ' - ' || V_LY_PERDNAME_IN_QTR );
			
			nCount := 0;
			SELECT	COUNT( * ) INTO nCount
			FROM	CS_CREDIT c
			WHERE	c.PERIODSEQ = V_LY_PERDSEQ_IN_QTR;
      ------Begin Modified by Chao 20140803
			IF( nCount > 0 ) THEN
				--UPD_PAQPB_FRM_CRTBL( 'LY_FYP_RYP_MTH' || nSeq || '_IN_QTR', 'IN( ''C_FYP'', ''C_RYP'' )', 'SUM( t.value )', V_PERIODSEQ, V_LY_PERDSEQ_IN_QTR );
        UPD_PAQPB_FRM_CRTBL( 'LY_FYP_RYP_MTH' || nSeq || '_IN_QTR', 'IN( ''PM_FYP_PA'', ''PM_RYP_PA'' )', 'SUM( t.value )', V_PERIODSEQ, V_LY_PERDSEQ_IN_QTR );
				--UPD_PAQPB_FRM_CRTBL( 'LY_FYP_RYP_ADJ_END_QTR', 'IN( ''C_FYP_Adjusted'', ''C_RYP_Adjusted'' )', 'rpt.LY_FYP_RYP_ADJ_END_QTR + SUM( t.value )', 
				--					V_PERIODSEQ, V_LY_PERDSEQ_IN_QTR );
        UPD_PAQPB_FRM_CRTBL( 'LY_FYP_RYP_ADJ_END_QTR', 'IN( ''PM_FYP_PA_Adjusted'', ''PM_RYP_PA_Adjusted'' )', 'rpt.LY_FYP_RYP_ADJ_END_QTR + SUM( t.value )', 
        		V_PERIODSEQ, V_LY_PERDSEQ_IN_QTR );
			ELSE
				nCount := 0;
				SELECT	COUNT( * ) INTO nCount
				FROM	RPT_INIT_HISTORY_LKP t
				WHERE	t.PERIODSEQ = V_LY_PERDSEQ_IN_QTR;
				IF( nCount > 0 ) THEN
					UPD_PAQPB_FRM_INITTBL( 'LY_FYP_RYP_MTH' || nSeq || '_IN_QTR', 'IN( ''FYP'', ''RYP'' )', 'GROUP BY rpt.AGENT_CODE', 'SUM( t.NVALUE_1 )', 
											V_PERIODSEQ, V_LY_PERDSEQ_IN_QTR );
					UPD_PAQPB_FRM_INITTBL( 'LY_FYP_RYP_ADJ_END_QTR', 'IN( ''FYP_Adjusted'', ''RYP_Adjusted'' )', 'GROUP BY rpt.AGENT_CODE', 
											'rpt.LY_FYP_RYP_ADJ_END_QTR + SUM( t.NVALUE_1 )', V_PERIODSEQ, V_LY_PERDSEQ_IN_QTR );
				END IF;
			END IF;
      ------End Modified by Chao 20140803
			nSeq := nSeq + 1;
		END LOOP;
		CLOSE LY_PERIODSEQ_Cur;
		
		-- By right only 1 credit C_PA_Persistency_QTD per agent each month
		UPDATE	RPT_SGPAGY_PA_QTR_PRD_BONUS rpt
		SET	PERSISTENCY = 
----Modified by bin replace the C_PA_Persistency_QTD with C_PA_Bonus_Qualification.GN1
    (SELECT c.GENERICNUMBER1
							FROM cs_credit c
								WHERE c.periodseq = V_PERIODSEQ
									AND c.name = 'C_PA_Bonus_Qualification'
									AND rpt.positionseq = c.positionseq)
    /*( SELECT SUM( c.value )
							FROM cs_credit c
								WHERE c.periodseq = V_PERIODSEQ
									AND c.name = 'C_PA_Persistency_QTD'
									AND rpt.positionseq = c.positionseq
								GROUP BY c.positionseq
							)*/
		WHERE	rpt.periodseq = V_PERIODSEQ
				AND rpt.positionseq IN( SELECT DISTINCT c.positionseq
										FROM	cs_credit c
										WHERE	c.periodseq = V_PERIODSEQ
												--AND c.name = 'C_PA_Persistency_QTD'
												AND c.name = 'C_PA_Bonus_Qualification'
                        AND rpt.positionseq = c.positionseq
									);
----Modified by bin 20140818               
		UPDATE	RPT_SGPAGY_PA_QTR_PRD_BONUS rpt
		SET	MEET = ( SELECT CASE 
								WHEN m.value >= 1 THEN 'Y'
								ELSE 'N'
							END AS MEET
					FROM	CS_MEASUREMENT m
					WHERE	m.periodseq = V_PERIODSEQ
							AND m.name = 'PM_PA_Bonus_Qualification'
							AND m.value <> 0
							AND rpt.positionseq = m.positionseq
					)
		WHERE	rpt.periodseq = V_PERIODSEQ
				AND rpt.positionseq IN( SELECT DISTINCT m.positionseq
										FROM	CS_MEASUREMENT m
										WHERE	m.periodseq = V_PERIODSEQ
												AND m.name = 'PM_PA_Bonus_Qualification'
												AND m.value <> 0
												AND rpt.positionseq = m.positionseq
									);
		------Begin Modified by Chao at 20140802
		UPDATE	RPT_SGPAGY_PA_QTR_PRD_BONUS rpt
		SET	RATE = ( SELECT	max(i.genericnumber1)--i.value
					FROM	CS_INCENTIVE i
					WHERE	i.periodseq = V_PERIODSEQ
							AND i.name = 'I_PA_Production_Bonus_SG'
							AND i.value <> 0
							AND rpt.positionseq = i.positionseq
					)
		WHERE	rpt.periodseq = V_PERIODSEQ
				/*AND rpt.positionseq IN( SELECT DISTINCT i.positionseq
										FROM	CS_INCENTIVE i
										WHERE	i.periodseq = V_PERIODSEQ
												AND i.name = 'I_PA_Production_Bonus_SG'
												AND i.value <> 0
												AND rpt.positionseq = i.positionseq
									)*/;
		UPDATE	RPT_SGPAGY_PA_QTR_PRD_BONUS rpt
		SET	BONUS = ( SELECT	nvl(sum(d.value),0)
					FROM	CS_DEPOSIT d
					WHERE	d.periodseq = V_PERIODSEQ
							AND d.name = 'D_PA_Production_Bonus_SG'
							AND rpt.positionseq = d.positionseq
					)
		WHERE	rpt.periodseq = V_PERIODSEQ
				/*AND rpt.positionseq IN( SELECT DISTINCT d.positionseq
										FROM	CS_DEPOSIT d
										WHERE	d.periodseq = V_PERIODSEQ
												AND d.name = 'D_PA_Production_Bonus_SG'
												AND rpt.positionseq = d.positionseq
									)*/;
    ------End Modified by Chao at 20140802
									
		-- Delete those agents with 0 value in all fields
		DELETE FROM RPT_SGPAGY_PA_QTR_PRD_BONUS rpt
		WHERE FYP_MTH1_IN_QTR = 0 
			AND FYP_MTH2_IN_QTR = 0
			AND FYP_MTH3_IN_QTR = 0
			AND FYP_ADJ_END_QTR = 0
			AND RYP_MTH1_IN_QTR = 0
			AND RYP_MTH2_IN_QTR = 0
			AND RYP_MTH3_IN_QTR = 0
			AND RYP_ADJ_END_QTR = 0;
		
	EXCEPTION
	WHEN OTHERS THEN
		ERROR_LOGGING;
	END;
	
	PROCEDURE UPD_PAQPB_FRM_CRTBL( 
		strFieldName	IN VARCHAR2, 
		strKey			IN VARCHAR2, 
		strSelect		IN VARCHAR2, 
		rptPeriodSeq	IN RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE, 
		periodSeqInQtr	IN RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE
	) 
	IS
		strSQL					VARCHAR2( 1024 );	
	BEGIN
      ------Begin Modified by Chao 20140803
		/*strSQL := 'UPDATE RPT_SGPAGY_PA_QTR_PRD_BONUS rpt ' || 
					'SET ' || strFieldName || ' = ( SELECT ' || strSelect || ' ' ||
													'FROM CS_CREDIT t ' ||
													'WHERE t.PERIODSEQ = ' || periodSeqInQtr || ' AND t.NAME ' || strKey || ' ' ||
															'AND rpt.positionseq = t.positionseq ' || 
													'GROUP BY rpt.positionseq ' || 
												') ' || 
					'WHERE	PERIODSEQ = ' || rptPeriodSeq || 
							' AND rpt.positionseq IN ( SELECT DISTINCT t.positionseq ' || 
													'FROM CS_CREDIT t ' ||
													'WHERE	t.PERIODSEQ = ' || periodSeqInQtr || ' AND t.NAME ' || strKey || ' ' ||
															'AND rpt.positionseq = t.positionseq ' || 
												')';*/
     strSQL := 'UPDATE RPT_SGPAGY_PA_QTR_PRD_BONUS rpt ' || 
					'SET ' || strFieldName || ' = ( SELECT ' || strSelect || ' ' ||
													'FROM CS_MEASUREMENT t ' ||
													'WHERE t.PERIODSEQ = ' || periodSeqInQtr || ' AND t.NAME ' || strKey || ' ' ||
															'AND rpt.positionseq = t.positionseq ' || 
													'GROUP BY rpt.positionseq ' || 
												') ' || 
					'WHERE	PERIODSEQ = ' || rptPeriodSeq || 
							' AND rpt.positionseq IN ( SELECT DISTINCT t.positionseq ' || 
													'FROM CS_MEASUREMENT t ' ||
													'WHERE	t.PERIODSEQ = ' || periodSeqInQtr || ' AND t.NAME ' || strKey || ' ' ||
															'AND rpt.positionseq = t.positionseq ' || 
												')';
		--DBMS_OUTPUT.PUT_LINE( 'SQL (from Credit): ' || strSQL );
    DBMS_OUTPUT.PUT_LINE( 'SQL (from Measurement): ' || strSQL );
    ------End Modified by Chao at 20140803
		EXECUTE IMMEDIATE( strSQL );
	EXCEPTION
	WHEN OTHERS THEN
		ERROR_LOGGING;
	END;
	
	PROCEDURE UPD_PAQPB_FRM_INITTBL( 
		strFieldName	IN VARCHAR2, 
		strKey			IN VARCHAR2, 
		strKey2			IN VARCHAR2, 
		strSelect		IN VARCHAR2, 
		rptPeriodSeq	IN RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE, 
		periodSeqInQtr	IN RPT_SGPAGY_PAQPB_QTR_MTHS.PERIODSEQ%TYPE
	) 
	IS
		strSQL					VARCHAR2( 1024 );	
	BEGIN
		strSQL := 'UPDATE RPT_SGPAGY_PA_QTR_PRD_BONUS rpt ' || 
					'SET ' || strFieldName || ' = ( SELECT ' || strSelect || ' ' ||
													'FROM RPT_INIT_HISTORY_LKP t ' ||
													'WHERE t.PERIODSEQ = ' || periodSeqInQtr || ' AND t.KEY_STR_1 = ''SGPAGY_PAQPB'' ' ||
															'AND t.KEY_STR_4 ' || strKey || ' ' ||
															'AND rpt.DISTRICT_CODE = t.KEY_STR_2 ' ||
															'AND rpt.AGENT_CODE = t.KEY_STR_3 ' || strKey2 || ' ' ||
												') ' || 
					'WHERE	PERIODSEQ = ' || rptPeriodSeq || 
							' AND rpt.AGENT_CODE IN ( SELECT DISTINCT t.KEY_STR_2 ' || 
													'FROM RPT_INIT_HISTORY_LKP t ' || 
													'WHERE t.PERIODSEQ = ' || periodSeqInQtr || ' AND t.KEY_STR_1 = ''SGPAGY_PAQPB'' ' ||
															'AND t.KEY_STR_4 ' || strKey || ' ' ||
															'AND rpt.DISTRICT_CODE = t.KEY_STR_2 ' ||
															'AND rpt.AGENT_CODE = t.KEY_STR_3 ' || 
												')';
		DBMS_OUTPUT.PUT_LINE( 'SQL (from Initial Value Setup): ' || strSQL );
		EXECUTE IMMEDIATE( strSQL );
	EXCEPTION
	WHEN OTHERS THEN
		ERROR_LOGGING;
	END;
	
	PROCEDURE RPT_PRD_BENEFIT_FRM_UM IS 
		cycleDate	DATE;
	BEGIN  
		/*
			Delete same cycle date if re-run multiple times for same period
		*/
		nCount := 0;
		SELECT COUNT( * ) INTO nCount
		FROM  RPT_SGPAGY_PBU;
		DBMS_OUTPUT.PUT_LINE( 'Before Delete RPT_SGPAGY_PBU: ' || V_PERIODSEQ || ' ' || nCount );
		EXECUTE IMMEDIATE 'DELETE FROM RPT_SGPAGY_PBU WHERE PERIODSEQ = ' || V_PERIODSEQ;
		
		cycleDate := V_PERIODENDDATE - 1;
		DBMS_OUTPUT.PUT_LINE( 'cycleDate: ' || cycleDate );
		
		/*
			PBU Buyout / Lump-sum payment
			- 1 Deposit => 1 Incentive => 1 main SM (SM_PBU_Lumpsum_District) => 1 SM from PBU_Roll relationship (SM_PBU_Lumpsum_New_FSD_SG)
				=> 1 PM from Assigned relationship (PM_PBU_Buyout) it seems not used
		*/
		INSERT INTO RPT_SGPAGY_PBU_P12PERD( PERIODSEQ )
		SELECT	PERIODSEQ
		FROM	CS_PERIOD PERD, CS_PERIODTYPE PERT, CS_CALENDAR CAL
		WHERE	PERD.CALENDARSEQ = CAL.CALENDARSEQ
				AND PERD.PERIODTYPESEQ = PERT.PERIODTYPESEQ
				AND PERD.REMOVEDATE = C_REMOVEDATE
				AND PERT.REMOVEDATE = C_REMOVEDATE
				AND CAL.REMOVEDATE = C_REMOVEDATE
				AND CAL.NAME = 'AIA Singapore Calendar'
				AND PERT.NAME = 'month'
				AND PERD.STARTDATE >= ADD_MONTHS( V_PERIODSTARTDATE, -12 ) AND PERD.STARTDATE < V_PERIODSTARTDATE;
		
		INSERT INTO RPT_SGPAGY_PBU_PAYER( PERIODSEQ, CYCLEDATE, PERIODNAME, PARTICIPANTSEQ, POSITIONSEQ, POSITIONNAME, 
				DEPOSITSEQ, PAYEE_FSD_CODE, PAYEE_FSD_NAME, PAYEE_FSD_AGENCY, 
				PAYER_SM_SEQ, PAYER_SM_NAME, PAYER_FSD_CODE, PAYER_FSD_NAME, PAYER_FSD_DISTRICT, PAYER_FSD_UNIT, 
				PAYER_FSD_PROMOTION_DATE, PAYER_FSD_DEMOTION_DATE, PAYER_FSD_REAPPOINT_DATE, PAYER_FSD_SERVICE_YEAR, 
				PBU_PAYMENT_TYPE, PBU_RATE_TO_PAYEE_FSD )
		SELECT	mtagent2.PERIODSEQ, mtagent2.CYCLEDATE, mtagent2.PERIODNAME, d.PAYEESEQ, d.POSITIONSEQ, mtagent2.POSITIONNAME, 
				d.depositseq, mtagent2.AGT_AGY_CODE, mtagent2.AGT_AGY_NAME, mtagent2.UNIT_CODE, 
				m1.measurementseq, m1.name, mtagent.AGT_AGY_CODE, mtagent.AGT_AGY_NAME, mtagent.DISTRICT_CODE, mtagent.UNIT_CODE,
				mtagent.PROMOTION_DATE, mtagent.DEMOTION_DATE, 
				CASE
					WHEN( gapo.GENERICATTRIBUTE10 IS NULL ) THEN NULL
					ELSE mtagent.PROMOTION_DATE
				END AS PAYER_FSD_REAPPOINT_DATE, 
				m1.genericnumber2,
				'LUMPSUM', m1.genericnumber1
		FROM	cs_deposit d
				LEFT JOIN RPT_MASTER_AGENT mtagent2 ON mtagent2.PERIODSEQ = V_PERIODSEQ AND d.positionseq = mtagent2.positionseq
				LEFT JOIN cs_depositincentivetrace dit ON d.periodseq = V_PERIODSEQ AND d.depositseq = dit.depositseq
				LEFT JOIN cs_incentivepmtrace ipt ON ipt.contributionvalue <> 0 AND dit.incentiveseq = ipt.incentiveseq
				LEFT JOIN cs_pmselftrace pst1 ON pst1.contributionvalue <> 0 AND ipt.measurementseq = pst1.targetmeasurementseq
				LEFT JOIN cs_measurement m1 ON m1.value <> 0 AND pst1.sourcemeasurementseq = m1.measurementseq			-- SM_PBU_Lumpsum_New_FSD_SG
				LEFT JOIN RPT_MASTER_AGENT mtagent ON mtagent.PERIODSEQ = V_PERIODSEQ AND m1.positionseq = mtagent.positionseq
				LEFT JOIN cs_gaposition gapo ON gapo.removedate = C_REMOVEDATE 
						AND mtagent.positionseq = gapo.ruleelementownerseq
						AND mtagent.poeffectivestartdate = gapo.effectivestartdate AND mtagent.poeffectiveenddate = gapo.effectiveenddate
        join CS_BUSINESSUNIT BU on BU.MASK = D.BUSINESSUNITMAP and BU.NAME = 'SGPAGY' -- MODIFIED BY FELIX 2014.8.1
		WHERE	d.PERIODSEQ = V_PERIODSEQ
				AND d.name = 'D_PBU_Buyout_SG';
				
		nCount := 0;
		SELECT COUNT( * ) INTO nCount
		FROM  RPT_SGPAGY_PBU_PAYER
		WHERE PERIODSEQ = V_PERIODSEQ 
			AND PBU_PAYMENT_TYPE = 'LUMPSUM';
		IF( nCount > 0 ) THEN
			INSERT INTO RPT_SGPAGY_PBU_PAYER_TEAM( PAYER_TEAM_UNIT_CODE, PAYER_TEAM_UNIT_NAME, PAYER_TEAM_LEADER_CODE, PAYER_TEAM_LEADER_NAME, 
					PAYER_TEAM_AGENT_CODE, PAYER_TEAM_AGENT_NAME, PAYER_TEAM_CLASS_CODE, PAYER_TEAM_CONTRACT_DATE, PAYER_TEAM_TRANSFER_DATE,
					PAYER_TEAM_ASSIGN_DATE, PAYER_TEAM_TERMINATE_DATE, PAYER_TEAM_TTL_PIB_P12, PAYER_TEAM_CONTRIBUTE_PBU, PBU_PAYMENT_TYPE )
			SELECT	mtagent.AGT_AGY_CODE, mtagent.AGT_AGY_NAME, mtagent.UNIT_LEADER_CODE, mtagent.UNIT_LEADER_NAME, 
					c.genericattribute12, mtagent1.AGT_AGY_NAME, mtagent1.CLASS_CODE, mtagent1.CONTRACT_DATE, mtagent1.TRANSFER_DATE, 
					mtagent1.ASSIGN_DATE, mtagent1.TERMINATION_DATE, SUM( c.value ), 
					CASE
						WHEN c.genericboolean4 = 1 THEN 'Yes'
						ELSE 'No'
					END AS PAYER_TEAM_CONTRIBUTE_PBU, 'LUMPSUM' 
			FROM	CS_CREDIT c
					LEFT JOIN RPT_MASTER_AGENT mtagent ON mtagent.PERIODSEQ = V_PERIODSEQ AND c.positionseq = mtagent.positionseq
					LEFT JOIN RPT_MASTER_AGENT mtagent1 ON mtagent1.PERIODSEQ = V_PERIODSEQ AND 'SGT'||c.genericattribute12 = mtagent1.POSITIONNAME
          join CS_BUSINESSUNIT BU on BU.MASK = C.BUSINESSUNITMAP and BU.NAME = 'SGPAGY' -- MODIFIED BY FELIX 2014.8.1
			WHERE	c.periodseq IN( SELECT periodseq FROM RPT_SGPAGY_PBU_P12PERD )
					AND mtagent.AGT_AGY_CODE IN( SELECT DISTINCT PAYER_FSD_UNIT FROM RPT_SGPAGY_PBU_PAYER )
			GROUP BY mtagent.AGT_AGY_CODE, mtagent.AGT_AGY_NAME, mtagent.UNIT_LEADER_CODE, mtagent.UNIT_LEADER_NAME, 
					c.genericattribute12, mtagent1.AGT_AGY_NAME, mtagent1.CLASS_CODE, mtagent1.CONTRACT_DATE, mtagent1.TRANSFER_DATE, 
					mtagent1.ASSIGN_DATE, mtagent1.TERMINATION_DATE, c.genericboolean4;
			UPDATE	RPT_SGPAGY_PBU_PAYER_TEAM
			SET		PAYER_TEAM_TTL_PIB_P12 = 0
			WHERE	PAYER_TEAM_CONTRIBUTE_PBU = 'No' OR PAYER_TEAM_CONTRIBUTE_PBU IS NULL;
			
			INSERT INTO RPT_SGPAGY_PBU( PERIODSEQ, CYCLEDATE, PERIODNAME, PARTICIPANTSEQ, POSITIONSEQ, POSITIONNAME, 
					DEPOSITSEQ, PAYEE_FSD_CODE, PAYEE_FSD_NAME, PAYEE_FSD_AGENCY, 
					PAYER_SM_SEQ, PAYER_SM_NAME, PAYER_FSD_CODE, PAYER_FSD_NAME, PAYER_FSD_DISTRICT, PAYER_FSD_UNIT, 
					PAYER_FSD_PROMOTION_DATE, PAYER_FSD_DEMOTION_DATE, PAYER_FSD_REAPPOINT_DATE, PAYER_FSD_SERVICE_YEAR, 
					PAYER_TEAM_UNIT_CODE, PAYER_TEAM_UNIT_NAME, PAYER_TEAM_LEADER_CODE, PAYER_TEAM_LEADER_NAME, 
					PAYER_TEAM_AGENT_CODE, PAYER_TEAM_AGENT_NAME, PAYER_TEAM_CLASS_CODE, PAYER_TEAM_CONTRACT_DATE, PAYER_TEAM_TRANSFER_DATE,
					PAYER_TEAM_ASSIGN_DATE, PAYER_TEAM_TERMINATE_DATE, PAYER_TEAM_TTL_PIB_MTH, PAYER_TEAM_TTL_PIB_YTD, PAYER_TEAM_TTL_PIB_P12, 
					PAYER_TEAM_CONTRIBUTE_PBU, PBU_PAYMENT_TYPE, PBU_RATE_TO_PAYEE_FSD, PBU_PAID_MTH_TO_PAYEE_FSD )
			SELECT	PERIODSEQ, CYCLEDATE, PERIODNAME, PARTICIPANTSEQ, POSITIONSEQ, POSITIONNAME, 
					DEPOSITSEQ, PAYEE_FSD_CODE, PAYEE_FSD_NAME, PAYEE_FSD_AGENCY, 
					PAYER_SM_SEQ, PAYER_SM_NAME, PAYER_FSD_CODE, PAYER_FSD_NAME, PAYER_FSD_DISTRICT, PAYER_FSD_UNIT, 
					PAYER_FSD_PROMOTION_DATE, PAYER_FSD_DEMOTION_DATE, PAYER_FSD_REAPPOINT_DATE, PAYER_FSD_SERVICE_YEAR, 
					PAYER_TEAM_UNIT_CODE, PAYER_TEAM_UNIT_NAME, PAYER_TEAM_LEADER_CODE, PAYER_TEAM_LEADER_NAME, 
					PAYER_TEAM_AGENT_CODE, PAYER_TEAM_AGENT_NAME, PAYER_TEAM_CLASS_CODE, PAYER_TEAM_CONTRACT_DATE, PAYER_TEAM_TRANSFER_DATE,
					PAYER_TEAM_ASSIGN_DATE, PAYER_TEAM_TERMINATE_DATE, NULL, NULL, PAYER_TEAM_TTL_PIB_P12, PAYER_TEAM_CONTRIBUTE_PBU,
					p.PBU_PAYMENT_TYPE, PBU_RATE_TO_PAYEE_FSD, PAYER_TEAM_TTL_PIB_P12 * PBU_RATE_TO_PAYEE_FSD
			FROM	RPT_SGPAGY_PBU_PAYER p
					RIGHT JOIN RPT_SGPAGY_PBU_PAYER_TEAM pt ON pt.PBU_PAYMENT_TYPE = 'LUMPSUM' AND p.PAYER_FSD_UNIT = pt.PAYER_TEAM_UNIT_CODE
			WHERE	p.PBU_PAYMENT_TYPE = 'LUMPSUM';			
		END IF;
		
		/*
			PBU Monthly
			- 1 Deposit => 1 Incentive => 1 main SM (SM_PBU_Current_Month_SG) => 1 SM from PBU_Roll relationship (SM_PBU_Current_Month_New_FSD_SG)
				=> 1 SM from Assigned relationship (SM_PBU_Current_Month_New_District_SG)
			- List SM and PM that contribute to SM_PBU_Current_Month_New_District_SG
				a) PM_PIB_DIRECT_TEAM_Manager_Personal
				b) PM_PIB_DIRECT_TEAM_Not_Assigned
				c) PM_PBU_Excl_Transfer_Less_than_3years_Monthly
				d) SM_PBU_UM_TEAM_PIB
				e) SM_PBU_SPOL2_UM_TEAM_PIB
			- List SM and PM that contribute to SM_PBU_UM_TEAM_PIB
				a) PM_PIB_DIRECT_TEAM_Assigned
				b) PM_PIB_DIRECT_TEAM_Manager_Personal
				c) PM_PIB_DIRECT_TEAM_Not_Assigned
				d) PM_PBU_Excl_Transfer_Less_than_3years_Monthly
				e) SM_PBU_Excl_Transfered_Assigned_FSC_Monthly
			- List SM and PM that contribute to SM_PBU_SPOL2_UM_TEAM_PIB
				a) PM_PIB_DIRECT_TEAM_Assigned
				b) PM_PIB_DIRECT_TEAM_Manager_Personal
				c) PM_PIB_DIRECT_TEAM_Not_Assigned
				d) PM_PBU_Excl_Transfer_Less_than_3years_Monthly
				e) SM_PBU_Excl_Transfered_Assigned_FSC_Monthly
				f) SM_PBU_SPOL2_TEAM_PIB_Agency
			- List SM and PM that contribute to SM_PBU_Excl_Transfered_Assigned_FSC_Monthly
				a) PM_PBU_Excl_Transfered_Assigned_FSC_Monthly
			- List SM and PM that contribute to SM_PBU_SPOL2_TEAM_PIB_Agency
				a) SM_PBU_UM_TEAM_PIB (same above)
			
			Incentive Trace
				SM_PBU_Current_Month_SG
			Level 1
				SM_PBU_Current_Month_New_FSD_SG
			Level 2
				SM_PBU_Current_Month_New_District_SG
			Level 3
				PM_PIB_DIRECT_TEAM_Manager_Personal
				PM_PIB_DIRECT_TEAM_Not_Assigned
				PM_PBU_Excl_Transfer_Less_than_3years_Monthly
				SM_PBU_UM_TEAM_PIB
				SM_PBU_SPOL2_UM_TEAM_PIB
			Level 4
				PM_PIB_DIRECT_TEAM_Assigned
				PM_PIB_DIRECT_TEAM_Manager_Personal
				PM_PIB_DIRECT_TEAM_Not_Assigned
				PM_PBU_Excl_Transfer_Less_than_3years_Monthly
				SM_PBU_Excl_Transfered_Assigned_FSC_Monthly
				SM_PBU_SPOL2_TEAM_PIB_Agency
			Level 5
				PM_PBU_Excl_Transfered_Assigned_FSC_Monthly
				SM_PBU_UM_TEAM_PIB
			Level 6
				PM_PIB_DIRECT_TEAM_Assigned
				PM_PIB_DIRECT_TEAM_Manager_Personal
				PM_PIB_DIRECT_TEAM_Not_Assigned
				PM_PBU_Excl_Transfer_Less_than_3years_Monthly
				SM_PBU_Excl_Transfered_Assigned_FSC_Monthly
			Level 7
				PM_PBU_Excl_Transfered_Assigned_FSC_Monthly
				
			PM here possible as agency and need to get agent under this agency
		*/
		INSERT INTO RPT_SGPAGY_PBU_PAYER( PERIODSEQ, CYCLEDATE, PERIODNAME, PARTICIPANTSEQ, POSITIONSEQ, POSITIONNAME, 
				DEPOSITSEQ, PAYEE_FSD_CODE, PAYEE_FSD_NAME, PAYEE_FSD_AGENCY, 
				PAYER_SM_SEQ, PAYER_SM_NAME, PAYER_FSD_CODE, PAYER_FSD_NAME, PAYER_FSD_DISTRICT, PAYER_FSD_UNIT, 
				PAYER_FSD_PROMOTION_DATE, PAYER_FSD_DEMOTION_DATE, PAYER_FSD_REAPPOINT_DATE, PAYER_FSD_SERVICE_YEAR, 
				PBU_PAYMENT_TYPE, PBU_RATE_TO_PAYEE_FSD )
		SELECT	mtagent2.PERIODSEQ, mtagent2.CYCLEDATE, mtagent2.PERIODNAME, d.PAYEESEQ, d.POSITIONSEQ, mtagent2.POSITIONNAME, 
				d.depositseq, mtagent2.AGT_AGY_CODE, mtagent2.AGT_AGY_NAME, mtagent2.UNIT_CODE, 
				m1.measurementseq, m1.name, mtagent.AGT_AGY_CODE, mtagent.AGT_AGY_NAME, mtagent.DISTRICT_CODE, mtagent.UNIT_CODE,
				mtagent.PROMOTION_DATE, mtagent.DEMOTION_DATE, 
				CASE
					WHEN( gapo.GENERICATTRIBUTE10 IS NULL ) THEN NULL
					ELSE mtagent.PROMOTION_DATE
				END AS PAYER_FSD_REAPPOINT_DATE, 
				m1.genericnumber2, 
				'MONTHLY', m1.genericnumber1
		FROM	cs_deposit d
				LEFT JOIN RPT_MASTER_AGENT mtagent2 ON mtagent2.PERIODSEQ = V_PERIODSEQ AND d.positionseq = mtagent2.positionseq
				LEFT JOIN cs_depositincentivetrace dit ON d.periodseq = V_PERIODSEQ AND d.depositseq = dit.depositseq
				LEFT JOIN cs_incentivepmtrace ipt ON ipt.contributionvalue <> 0 AND dit.incentiveseq = ipt.incentiveseq
				LEFT JOIN cs_pmselftrace pst1 ON pst1.contributionvalue <> 0 AND ipt.measurementseq = pst1.targetmeasurementseq
				LEFT JOIN cs_measurement m1 ON m1.value <> 0 AND pst1.sourcemeasurementseq = m1.measurementseq			-- SM_PBU_Current_Month_New_FSD_SG
				LEFT JOIN RPT_MASTER_AGENT mtagent ON mtagent.PERIODSEQ = V_PERIODSEQ AND m1.positionseq = mtagent.positionseq
				LEFT JOIN cs_gaposition gapo ON gapo.removedate = C_REMOVEDATE 
						AND mtagent.positionseq = gapo.ruleelementownerseq
						AND mtagent.poeffectivestartdate = gapo.effectivestartdate AND mtagent.poeffectiveenddate = gapo.effectiveenddate
        join CS_BUSINESSUNIT BU on BU.MASK = D.BUSINESSUNITMAP and BU.NAME = 'SGPAGY' -- MODIFIED BY FELIX 2014.8.1
		WHERE	d.PERIODSEQ = V_PERIODSEQ
				AND d.name = 'D_PBU_Monthly_SG';
				
		nCount := 0;
		SELECT COUNT( * ) INTO nCount
		FROM  RPT_SGPAGY_PBU_PAYER
		WHERE PERIODSEQ = V_PERIODSEQ 
			AND PBU_PAYMENT_TYPE = 'MONTHLY';
		IF( nCount > 0 ) THEN
			-- Level 3
			INSERT INTO RPT_SGPAGY_PBU_M_CRKEY( PAYER_SM_SEQ, PARENTMEASUREMENTSEQ, MEASUREMENTSEQ, MEASUREMENTNAME, MEASUREMENTLEVEL )
			SELECT	t.PAYER_SM_SEQ, pst3.targetmeasurementseq, pst3.sourcemeasurementseq, m2.name, '3'
			FROM	RPT_SGPAGY_PBU_PAYER t
					LEFT JOIN cs_pmselftrace pst2 ON pst2.contributionvalue <> 0 AND t.PAYER_SM_SEQ = pst2.targetmeasurementseq
					LEFT JOIN cs_pmselftrace pst3 ON pst3.contributionvalue <> 0 AND pst2.sourcemeasurementseq = pst3.targetmeasurementseq
					LEFT JOIN cs_measurement m2 ON m2.value <> 0 AND pst3.sourcemeasurementseq = m2.measurementseq;
			-- Level 4
			INSERT INTO RPT_SGPAGY_PBU_M_CRKEY( PAYER_SM_SEQ, PARENTMEASUREMENTSEQ, MEASUREMENTSEQ, MEASUREMENTNAME, MEASUREMENTLEVEL )
			SELECT	t.PAYER_SM_SEQ, pst.targetmeasurementseq, pst.sourcemeasurementseq, m.name, '4'
			FROM	RPT_SGPAGY_PBU_M_CRKEY t
					LEFT JOIN cs_pmselftrace pst ON pst.contributionvalue <> 0 AND t.measurementseq = pst.targetmeasurementseq
					LEFT JOIN cs_measurement m ON m.value <> 0 AND pst.sourcemeasurementseq = m.measurementseq
			WHERE	t.MEASUREMENTLEVEL = '3' AND t.MEASUREMENTNAME LIKE 'SM%';
			-- Level 5
			INSERT INTO RPT_SGPAGY_PBU_M_CRKEY( PAYER_SM_SEQ, PARENTMEASUREMENTSEQ, MEASUREMENTSEQ, MEASUREMENTNAME, MEASUREMENTLEVEL )
			SELECT	t.PAYER_SM_SEQ, pst.targetmeasurementseq, pst.sourcemeasurementseq, m.name, '5'
			FROM	RPT_SGPAGY_PBU_M_CRKEY t
					LEFT JOIN cs_pmselftrace pst ON pst.contributionvalue <> 0 AND t.measurementseq = pst.targetmeasurementseq
					LEFT JOIN cs_measurement m ON m.value <> 0 AND pst.sourcemeasurementseq = m.measurementseq
			WHERE	t.MEASUREMENTLEVEL = '4' AND t.MEASUREMENTNAME LIKE 'SM%';
			-- Level 6
			INSERT INTO RPT_SGPAGY_PBU_M_CRKEY( PAYER_SM_SEQ, PARENTMEASUREMENTSEQ, MEASUREMENTSEQ, MEASUREMENTNAME, MEASUREMENTLEVEL )
			SELECT	t.PAYER_SM_SEQ, pst.targetmeasurementseq, pst.sourcemeasurementseq, m.name, '6'
			FROM	RPT_SGPAGY_PBU_M_CRKEY t
					LEFT JOIN cs_pmselftrace pst ON pst.contributionvalue <> 0 AND t.measurementseq = pst.targetmeasurementseq
					LEFT JOIN cs_measurement m ON m.value <> 0 AND pst.sourcemeasurementseq = m.measurementseq
			WHERE	t.MEASUREMENTLEVEL = '5' AND t.MEASUREMENTNAME LIKE 'SM%';
			-- Level 7
			INSERT INTO RPT_SGPAGY_PBU_M_CRKEY( PAYER_SM_SEQ, PARENTMEASUREMENTSEQ, MEASUREMENTSEQ, MEASUREMENTNAME, MEASUREMENTLEVEL )
			SELECT	t.PAYER_SM_SEQ, pst.targetmeasurementseq, pst.sourcemeasurementseq, m.name, '7'
			FROM	RPT_SGPAGY_PBU_M_CRKEY t
					LEFT JOIN cs_pmselftrace pst ON pst.contributionvalue <> 0 AND t.measurementseq = pst.targetmeasurementseq
					LEFT JOIN cs_measurement m ON m.value <> 0 AND pst.sourcemeasurementseq = m.measurementseq
			WHERE	t.MEASUREMENTLEVEL = '6' AND t.MEASUREMENTNAME LIKE 'SM%';
			
			UPDATE	RPT_SGPAGY_PBU_M_CRKEY
			SET	PAYER_TEAM_CONTRIBUTE_PBU = 'No'
			WHERE	MEASUREMENTNAME = 'PM_PBU_Excl_Transfer_Less_than_3years_Monthly'
					OR MEASUREMENTNAME = 'PM_PBU_Excl_Transfered_Assigned_FSC_Monthly';
			
			UPDATE	RPT_SGPAGY_PBU_M_CRKEY
			SET	PAYER_TEAM_CONTRIBUTE_PBU = 'No'
			WHERE	PARENTMEASUREMENTSEQ IN ( SELECT t.MEASUREMENTSEQ
												FROM RPT_SGPAGY_PBU_M_CRKEY t
												WHERE t.MEASUREMENTNAME = 'SM_PBU_UM_TEAM_PIB' 
														AND t.PARENTMEASUREMENTSEQ IN ( SELECT t1.MEASUREMENTSEQ
																						FROM RPT_SGPAGY_PBU_M_CRKEY t1
																						WHERE t1.MEASUREMENTNAME = 'SM_PBU_SPOL2_TEAM_PIB_Agency'
																					)
											);
			
			INSERT INTO RPT_SGPAGY_PBU_M_CRVALUE( PAYER_SM_SEQ, PAYER_TEAM_AGENT_CODE, PAYER_TEAM_TTL_PIB_MTH, PAYER_TEAM_CONTRIBUTE_PBU )
			SELECT	t.PAYER_SM_SEQ, c.genericattribute12, SUM( c.value ), t.PAYER_TEAM_CONTRIBUTE_PBU
			FROM	RPT_SGPAGY_PBU_M_CRKEY t
					LEFT JOIN cs_pmcredittrace pct ON pct.contributionvalue <> 0 AND t.measurementseq = pct.measurementseq
					LEFT JOIN cs_credit c ON pct.creditseq = c.creditseq
			WHERE	t.MEASUREMENTNAME LIKE 'PM%'
			GROUP BY t.PAYER_SM_SEQ, c.genericattribute12, t.PAYER_TEAM_CONTRIBUTE_PBU;
			
			INSERT INTO RPT_SGPAGY_PBU( PERIODSEQ, CYCLEDATE, PERIODNAME, PARTICIPANTSEQ, POSITIONSEQ, POSITIONNAME, 
					DEPOSITSEQ, PAYEE_FSD_CODE, PAYEE_FSD_NAME, PAYEE_FSD_AGENCY, 
					PAYER_SM_SEQ, PAYER_SM_NAME, PAYER_FSD_CODE, PAYER_FSD_NAME, PAYER_FSD_DISTRICT, PAYER_FSD_UNIT, 
					PAYER_FSD_PROMOTION_DATE, PAYER_FSD_DEMOTION_DATE, PAYER_FSD_REAPPOINT_DATE, PAYER_FSD_SERVICE_YEAR, 
					PAYER_TEAM_UNIT_CODE, PAYER_TEAM_UNIT_NAME, PAYER_TEAM_LEADER_CODE, PAYER_TEAM_LEADER_NAME, 
					PAYER_TEAM_AGENT_CODE, PAYER_TEAM_AGENT_NAME, PAYER_TEAM_CLASS_CODE, PAYER_TEAM_CONTRACT_DATE, PAYER_TEAM_TRANSFER_DATE,
					PAYER_TEAM_ASSIGN_DATE, PAYER_TEAM_TERMINATE_DATE, PAYER_TEAM_TTL_PIB_MTH, PAYER_TEAM_TTL_PIB_P12, 
					PAYER_TEAM_CONTRIBUTE_PBU, PBU_PAYMENT_TYPE, PBU_RATE_TO_PAYEE_FSD, PBU_PAID_MTH_TO_PAYEE_FSD )
			SELECT	p.PERIODSEQ, p.CYCLEDATE, p.PERIODNAME, p.PARTICIPANTSEQ, p.POSITIONSEQ, p.POSITIONNAME, 
					p.DEPOSITSEQ, p.PAYEE_FSD_CODE, p.PAYEE_FSD_NAME, p.PAYEE_FSD_AGENCY, 
					p.PAYER_SM_SEQ, p.PAYER_SM_NAME, p.PAYER_FSD_CODE, p.PAYER_FSD_NAME, p.PAYER_FSD_DISTRICT, p.PAYER_FSD_UNIT, 
					p.PAYER_FSD_PROMOTION_DATE, p.PAYER_FSD_DEMOTION_DATE, p.PAYER_FSD_REAPPOINT_DATE, p.PAYER_FSD_SERVICE_YEAR, 
					mtagent.UNIT_CODE, mtagent.UNIT_NAME, mtagent.UNIT_LEADER_CODE, mtagent.UNIT_LEADER_NAME, 
					mtagent.AGT_AGY_CODE, mtagent.AGT_AGY_NAME, mtagent.CLASS_CODE, mtagent.CONTRACT_DATE, mtagent.TRANSFER_DATE, 
					mtagent.ASSIGN_DATE, mtagent.TERMINATION_DATE, t.PAYER_TEAM_TTL_PIB_MTH, 0, /*NULL -> 0 MODIFIED BY FELIX 2014.8.1*/
					t.PAYER_TEAM_CONTRIBUTE_PBU, p.PBU_PAYMENT_TYPE, p.PBU_RATE_TO_PAYEE_FSD, t.PAYER_TEAM_TTL_PIB_MTH * p.PBU_RATE_TO_PAYEE_FSD
			FROM	RPT_SGPAGY_PBU_PAYER p
					LEFT JOIN RPT_SGPAGY_PBU_M_CRVALUE t ON p.PAYER_SM_SEQ = t.PAYER_SM_SEQ
					LEFT JOIN RPT_MASTER_AGENT mtagent ON mtagent.PERIODSEQ = V_PERIODSEQ AND t.PAYER_TEAM_AGENT_CODE = mtagent.AGT_AGY_CODE
			WHERE	p.PBU_PAYMENT_TYPE = 'MONTHLY';
		END IF;
		
		INSERT INTO RPT_SGPAGY_PBU_YTD_VALUE( PAYEE_FSD_CODE, PAYEE_FSD_AGENCY, PAYER_FSD_DISTRICT, 
											PAYER_TEAM_UNIT_CODE, PAYER_TEAM_LEADER_CODE, PAYER_TEAM_AGENT_CODE, 
											PIB_CONTRIBUTION_YTD, PBU_CONTRIBUTION_YTD, PBU_PAYMENT_TYPE )
		SELECT	PAYEE_FSD_CODE, PAYEE_FSD_AGENCY, PAYER_FSD_DISTRICT, 
				PAYER_TEAM_UNIT_CODE, PAYER_TEAM_LEADER_CODE, PAYER_TEAM_AGENT_CODE, 
				SUM( PAYER_TEAM_TTL_PIB_MTH ), SUM( PBU_PAID_MTH_TO_PAYEE_FSD ), PBU_PAYMENT_TYPE
		FROM	RPT_SGPAGY_PBU rpt
		WHERE	rpt.cycledate <= cycleDate
		GROUP BY PAYEE_FSD_CODE, PAYEE_FSD_AGENCY, PAYER_FSD_DISTRICT, 
				PAYER_TEAM_UNIT_CODE, PAYER_TEAM_LEADER_CODE, PAYER_TEAM_AGENT_CODE, PBU_PAYMENT_TYPE;

		UPDATE	RPT_SGPAGY_PBU_YTD_VALUE rpt
		SET	rpt.pib_contribution_ytd = ( SELECT rpt.pib_contribution_ytd + lkp.nvalue_1
											FROM	RPT_INIT_HISTORY_LKP lkp 
											WHERE	lkp.key_str_1 = 'SGPAGY_PBU' AND lkp.key_str_3 = 'MONTHLY_PIB_YTD' 
													AND lkp.cycle_date <= cycleDate
													AND lkp.key_str_2 = rpt.payer_team_agent_code
										)
		WHERE	rpt.pbu_payment_type = 'MONTHLY'
				AND rpt.payer_team_agent_code IN ( SELECT lkp.key_str_2
													FROM	RPT_INIT_HISTORY_LKP lkp 
													WHERE	lkp.key_str_1 = 'SGPAGY_PBU' AND lkp.key_str_3 = 'MONTHLY_PIB_YTD' 
															AND lkp.cycle_date <= cycleDate
															AND lkp.key_str_2 = rpt.payer_team_agent_code
												);
		UPDATE	RPT_SGPAGY_PBU_YTD_VALUE rpt
		SET	rpt.pbu_contribution_ytd = ( SELECT rpt.pbu_contribution_ytd + lkp.nvalue_1
											FROM	RPT_INIT_HISTORY_LKP lkp 
											WHERE	lkp.key_str_1 = 'SGPAGY_PBU' AND lkp.key_str_3 = 'MONTHLY_PBU_YTD' 
													AND lkp.cycle_date <= cycleDate
													AND lkp.key_str_2 = rpt.payer_team_agent_code
										)
		WHERE	rpt.payer_team_agent_code IN ( SELECT lkp.key_str_2
													FROM	RPT_INIT_HISTORY_LKP lkp 
													WHERE	lkp.key_str_1 = 'SGPAGY_PBU' AND lkp.key_str_3 = 'MONTHLY_PBU_YTD' 
															AND lkp.cycle_date <= cycleDate
															AND lkp.key_str_2 = rpt.payer_team_agent_code
												);
		UPDATE	RPT_SGPAGY_PBU rpt
		SET	( rpt.PAYER_TEAM_TTL_PIB_YTD, 
			rpt.PBU_PAID_YTD_TO_PAYEE_FSD ) = ( SELECT	pib_contribution_ytd, pbu_contribution_ytd
												FROM	RPT_SGPAGY_PBU_YTD_VALUE ytd
												WHERE	ytd.payee_fsd_code = rpt.payee_fsd_code
														AND ytd.payee_fsd_agency = rpt.payee_fsd_agency
														AND ytd.payer_fsd_district = rpt.payer_fsd_district
														AND ytd.payer_team_unit_code = rpt.payer_team_unit_code
														AND ytd.payer_team_leader_code = rpt.payer_team_leader_code
														AND ytd.payer_team_agent_code = rpt.payer_team_agent_code
														AND ytd.pbu_payment_type = rpt.pbu_payment_type
											);

	EXCEPTION
	WHEN OTHERS THEN
		ERROR_LOGGING;
	END;
	
	/*
	Name:         RPT_SG_NSMAN_INCOME
	Description:  To populate the NSMan Income report table
	Parameter:    Nil

	History:

	Version          Date               Author                Description
	---------------------------------------------------------------------
	001              20140406           Donny                  Initial


	*/

	PROCEDURE SP_RPT_SG_NSMAN_INCOME (V_PERIODSEQ	    RPT_SG_NSMAN_INCOME.PERIODSEQ%TYPE) IS 
			
		v_nCount 			INTEGER;		
		v_dteEOT			DATE;
		v_dteCycle			DATE;
		v_periodName		RPT_SG_NSMAN_INCOME.PERIODNAME%TYPE;
	BEGIN  
		 v_nCount :=0;
		 v_dteEOT :=TO_DATE('01-01-2200','DD-MM-YYYY');
		 
		 SELECT TO_DATE(TXT_KEY_VALUE,'YYYY-MM-DD') INTO v_dteCycle FROM IN_ETL_CONTROL WHERE 
		 TXT_KEY_STRING='OPER_CYCLE_DATE' and TXT_FILE_NAME='GLOBAL' ;
		 
		 select NAME into v_periodName from CS_PERIOD where PERIODSEQ = V_PERIODSEQ;

		 DBMS_OUTPUT.PUT_LINE( 'Start NSMan Income report population for ' || v_periodName );
	     -- CLEAR the temp table 
		 DBMS_OUTPUT.PUT_LINE( 'Truncate RPT_SG_NSMAN_INCOME_TMP' );
		  EXECUTE IMMEDIATE 'TRUNCATE table RPT_SG_NSMAN_INCOME_TMP';
		 
		/*
			Delete same cycle date if re-run multiple times for same period
		*/
		SELECT COUNT( * ) INTO v_nCount FROM  RPT_SG_NSMAN_INCOME WHERE PERIODSEQ=V_PERIODSEQ;
		
		DBMS_OUTPUT.PUT_LINE( 'Before Delete RPT_SG_NSMAN_INCOME: ' || V_PERIODSEQ || ', COUNT = ' || v_nCount );
		EXECUTE IMMEDIATE 'DELETE FROM RPT_SG_NSMAN_INCOME WHERE PERIODSEQ = ' || V_PERIODSEQ;
		
		SELECT COUNT( * ) INTO v_nCount FROM  RPT_SG_NSMAN_INCOME WHERE PERIODSEQ=V_PERIODSEQ;
		DBMS_OUTPUT.PUT_LINE( 'After Delete RPT_SG_NSMAN_INCOME: ' || V_PERIODSEQ || ',COUNT = ' || v_nCount );

		/*
			populate the agent deposit (released + paid) into the temp table for current period based on creation date
		*/
		
		/*
			insert FYC/RYC to RPT_SG_NSMAN_INCOME_TMP
		*/
		DBMS_OUTPUT.PUT_LINE( 'Start populate RPT_SG_NSMAN_INCOME_TMP: FYC/RYC');

		INSERT INTO RPT_SG_NSMAN_INCOME_TMP( 
			PERIODSEQ               ,CYCLEDATE               ,PERIODNAME              ,
			PERIODSTARTDATE         ,PERIODENDDATE           ,PARTICIPANTSEQ          ,
			POSITIONSEQ             ,POSITIONNAME            ,DEPOSITSEQ              ,
			DEPOSITNAME             ,MEASUREMENTSEQ          ,MEASURMETNAME           ,
			CREDITSEQ               ,CREDITNAME              ,AGENT_CODE              ,
			AGENT_NAME              ,AGENT_NRIC              ,AGENCY_CODE             ,
			AGENCY_NAME             ,
			AMOUNT                  ,
			AMOUNT_TYPE             , --FYC_RP, FYC_SP, RYC, BENEFIT 
			CREATE_DATE
		)
		SELECT	
		pd.PERIODSEQ, 		v_dteCycle, 		pd.NAME, 
		pd.STARTDATE, 		pd.ENDDATE,		par.PAYEESEQ,
		pos.RULEELEMENTOWNERSEQ,		pos.NAME, 		dep.DEPOSITSEQ,
		dep.NAME, 		mea.MEASUREMENTSEQ, 		mea.NAME, 
		crd.CREDITSEQ, 		crd.NAME, 		SUBSTR(pos.NAME,4,5),
		par.FIRSTNAME || par.MIDDLENAME || par.LASTNAME, 	par.GENERICATTRIBUTE15,
		pos.GENERICATTRIBUTE1,	parAgy.FIRSTNAME || parAgy.MIDDLENAME || parAgy.LASTNAME,
		crd.VALUE,
		CASE
		    WHEN crd.GENERICATTRIBUTE4 in ('PAY0','PAY1') THEN 'FYC_RP'
			WHEN crd.GENERICATTRIBUTE4 in ('PAYS','PAYT','PAYE','PAYF','PTAF','PTAX') THEN 'FYC_SP'
			ELSE 'RYC'
		END AS AMOUNT_TYPE,
		SYSDATE
		
		FROM	CS_PERIOD pd, CS_DEPOSIT dep, CS_DEPOSITPMTRACE deppmtrace, CS_MEASUREMENT mea, CS_PMCREDITTRACE pmctrace, CS_CREDIT crd,
		CS_POSITION pos, CS_PARTICIPANT par, CS_POSITION posAgy, CS_PARTICIPANT parAgy, CS_BUSINESSUNIT   bus
		WHERE	
		pd.PERIODSEQ = V_PERIODSEQ and 
		dep.PERIODSEQ = pd.PERIODSEQ and
		dep.NAME in ('D_APF_Payable_SGD_SG','D_API_IFYC_SGD_SG','D_API_SSC_SGD_SG','D_FYC_Initial_Excl_LF_SGD_SG','D_FYC_Initial_LF_SGD_SG',
		'D_FYC_Non_Initial_Excl_LF_SGD_SG','D_FYC_Non_Initial_LF_SGD_SG','D_RYC_Excl_LF_SGD_SG','D_RYC_LF_SGD_SG','D_SSC_Payable_SGD_SG') and
		dep.BUSINESSUNITMAP = bus.MASK and
		bus.NAME IN ('SGPAGY') and
		dep.DEPOSITSEQ = deppmtrace.DEPOSITSEQ and deppmtrace.MEASUREMENTSEQ = mea.MEASUREMENTSEQ and
		mea.MEASUREMENTSEQ = pmctrace.MEASUREMENTSEQ and pmctrace.CREDITSEQ = crd.CREDITSEQ and 
		dep.POSITIONSEQ = pos.RULEELEMENTOWNERSEQ and
		pos.PAYEESEQ = par.PAYEESEQ and
		posAgy.NAME = 'SGY' || pos.GENERICATTRIBUTE1 and
		pd.ENDDATE between pos.EFFECTIVESTARTDATE and pos.EFFECTIVEENDDATE -1 and pos.REMOVEDATE = v_dteEOT and
		pd.ENDDATE between par.EFFECTIVESTARTDATE and par.EFFECTIVEENDDATE -1 and par.REMOVEDATE = v_dteEOT and
		pd.ENDDATE between posAgy.EFFECTIVESTARTDATE and posAgy.EFFECTIVEENDDATE -1 and posAgy.REMOVEDATE = v_dteEOT and
		pd.ENDDATE between parAgy.EFFECTIVESTARTDATE and parAgy.EFFECTIVEENDDATE -1 and parAgy.REMOVEDATE = v_dteEOT and
		
		posAgy.PAYEESEQ = parAgy.PAYEESEQ ;
		
			
		SELECT COUNT( * ) INTO v_nCount FROM  RPT_SG_NSMAN_INCOME_TMP;
		DBMS_OUTPUT.PUT_LINE( 'Insert to RPT_SG_NSMAN_INCOME_TMP for FYC_RP, FYC_SP, RYC completed: ' || v_nCount );
		
		
		/*
			insert benefit to RPT_SG_NSMAN_INCOME_TMP
		*/
		DBMS_OUTPUT.PUT_LINE( 'Start populate RPT_SG_NSMAN_INCOME_TMP: Benefit ' );

		INSERT INTO RPT_SG_NSMAN_INCOME_TMP( 
			PERIODSEQ               ,CYCLEDATE               ,PERIODNAME              ,
			PERIODSTARTDATE         ,PERIODENDDATE           ,PARTICIPANTSEQ          ,
			POSITIONSEQ             ,POSITIONNAME            ,DEPOSITSEQ              ,
			DEPOSITNAME             ,MEASUREMENTSEQ          ,MEASURMETNAME           ,
			CREDITSEQ               ,CREDITNAME              ,AGENT_CODE              ,
			AGENT_NAME              ,AGENT_NRIC              ,AGENCY_CODE             ,
			AGENCY_NAME             ,
			AMOUNT                  ,
			AMOUNT_TYPE             , --FYC_RP, FYC_SP, RYC, BENEFIT 
			CREATE_DATE
		)
		SELECT	
		pd.PERIODSEQ, 		v_dteCycle, 		pd.NAME, 
		pd.STARTDATE, 		pd.ENDDATE,		par.PAYEESEQ,
		pos.RULEELEMENTOWNERSEQ,		pos.NAME,		dep.DEPOSITSEQ,
		dep.NAME,		NULL,		NULL, 
		NULL, 		NULL, 		SUBSTR(pos.NAME,4,5),
		par.FIRSTNAME || par.MIDDLENAME || par.LASTNAME,		par.GENERICATTRIBUTE15, pos.GENERICATTRIBUTE1,		parAgy.FIRSTNAME || parAgy.MIDDLENAME || parAgy.LASTNAME,
		dep.VALUE,
		'BENEFIT' AS AMOUNT_TYPE,
		SYSDATE
		
		FROM	CS_PERIOD pd, CS_DEPOSIT dep, CS_POSITION pos, CS_PARTICIPANT par, CS_POSITION posAgy, CS_PARTICIPANT parAgy, 
		CS_BUSINESSUNIT   bus
		WHERE	
		pd.PERIODSEQ = V_PERIODSEQ and 
		dep.PERIODSEQ = pd.PERIODSEQ and
		dep.NAME in ('D_Clerical_Allowance_SG','D_DPI_SG','D_Daily_Ad_Hoc_Before_Tax','D_FSAD_Self_Override_SG','D_M_BEFORE_TAX_SG','D_Monthly_Allowance_SG',
		'D_NADOR_SG','D_NLPI_SG','D_OPI_First_Year_SG','D_OPI_Renewal_SG','D_PA_Production_Bonus_SG','D_PBA_SG','D_PBU_Buyout_SG','D_PBU_Monthly_SG',
		'D_PI_UM_SG','D_PI_FSD_SG','D_PLOR_SG','D_PL_Year_End_Bonus','D_Productivity_Allowance_SG','D_SPI_SG','D_VLOR_SG','D_MD_Distribution_SG',
		'D_ADPI_SG','D_AOR_SG','D_PARIS_AM_SG','D_PARIS_DM_SG'				
		) and
		dep.BUSINESSUNITMAP = bus.MASK and
		bus.NAME IN ('SGPAGY') and
		dep.POSITIONSEQ = pos.RULEELEMENTOWNERSEQ and
		pos.PAYEESEQ = par.PAYEESEQ and
		posAgy.NAME = 'SGY' || pos.GENERICATTRIBUTE1 and
		pd.ENDDATE between pos.EFFECTIVESTARTDATE and pos.EFFECTIVEENDDATE -1 and pos.REMOVEDATE = v_dteEOT and
		pd.ENDDATE between par.EFFECTIVESTARTDATE and par.EFFECTIVEENDDATE -1 and par.REMOVEDATE = v_dteEOT and
		pd.ENDDATE between posAgy.EFFECTIVESTARTDATE and posAgy.EFFECTIVEENDDATE -1 and posAgy.REMOVEDATE = v_dteEOT and
		pd.ENDDATE between parAgy.EFFECTIVESTARTDATE and parAgy.EFFECTIVEENDDATE -1 and parAgy.REMOVEDATE = v_dteEOT and
		posAgy.PAYEESEQ = parAgy.PAYEESEQ ;
			
		
		SELECT COUNT( * ) INTO v_nCount FROM  RPT_SG_NSMAN_INCOME_TMP WHERE AMOUNT_TYPE='BENEFIT';

		DBMS_OUTPUT.PUT_LINE( 'Insert to RPT_SG_NSMAN_INCOME_TMP for BENEFIT completed: ' || v_nCount );
		
		--CREATE TABLE "tbl_TMP_INCOME" AS select * from RPT_SG_NSMAN_INCOME where 1=2;
		/*
			Aggregate result into final RPT_SG_NSMAN_INCOME table
		*/
		DBMS_OUTPUT.PUT_LINE( 'Start populate RPT_SG_NSMAN_INCOME with default value ' );

		--	INSERT INTO tbl_TMP_INCOME(
		INSERT INTO RPT_SG_NSMAN_INCOME( 
				PERIODSEQ        ,CYCLEDATE        ,PERIODNAME       ,
				PERIODSTARTDATE  ,PERIODENDDATE    ,PARTICIPANTSEQ   ,
				POSITIONSEQ      ,POSITIONNAME     ,AGENT_CODE       ,
				AGENT_NAME       ,AGENT_NRIC       ,AGENCY_CODE      ,
				AGENCY_NAME      ,
				FYC_RP           ,
				FYC_SP           ,
				RYC              ,
				BENEFIT          ,
				CREATE_DATE
		)
		SELECT	distinct 
			PERIODSEQ               ,CYCLEDATE               ,PERIODNAME              ,
			PERIODSTARTDATE         ,PERIODENDDATE           ,PARTICIPANTSEQ          ,
			POSITIONSEQ             ,POSITIONNAME            ,AGENT_CODE              ,
			AGENT_NAME              ,AGENT_NRIC,             AGENCY_CODE              ,
			AGENCY_NAME             ,
			0 ,-- FYC_RP,
			0 ,-- FYC_SP,
			0 ,-- RYC,
			0 ,-- BENEFIT,
			SYSDATE	
		FROM	RPT_SG_NSMAN_INCOME_TMP;

		SELECT COUNT( * ) INTO v_nCount FROM  RPT_SG_NSMAN_INCOME WHERE PERIODSEQ=V_PERIODSEQ;
		DBMS_OUTPUT.PUT_LINE( 'Populate RPT_SG_NSMAN_INCOME with default completed: ' || v_nCount );
			
		DBMS_OUTPUT.PUT_LINE( 'update RPT_SG_NSMAN_INCOME from RPT_SG_NSMAN_INCOME_TMP ' );
		
		update RPT_SG_NSMAN_INCOME a set 
		a.FYC_RP= 
		( select 
		NVL(sum(NVL(AMOUNT,0)),0) from RPT_SG_NSMAN_INCOME_TMP b
		where a.PERIODSEQ=b.PERIODSEQ and a.POSITIONSEQ=b.POSITIONSEQ and b.AMOUNT_TYPE='FYC_RP'
		)	,
    
		a.FYC_SP= 
		( select 
		NVL(sum(NVL(AMOUNT,0)),0) from RPT_SG_NSMAN_INCOME_TMP c
		where a.PERIODSEQ=c.PERIODSEQ and a.POSITIONSEQ=c.POSITIONSEQ and c.AMOUNT_TYPE='FYC_SP'
		),
		
		a.RYC= 
		( select 
		NVL(sum(NVL(AMOUNT,0)),0) from RPT_SG_NSMAN_INCOME_TMP d
		where a.PERIODSEQ=d.PERIODSEQ and a.POSITIONSEQ=d.POSITIONSEQ and d.AMOUNT_TYPE='RYC'
		),
		
		a.BENEFIT= 
		( select 
		NVL(sum(NVL(AMOUNT,0)),0) from RPT_SG_NSMAN_INCOME_TMP e
		where a.PERIODSEQ=e.PERIODSEQ and a.POSITIONSEQ=e.POSITIONSEQ and e.AMOUNT_TYPE='BENEFIT'
		)
		where a.PERIODSEQ=V_PERIODSEQ;
		
		DBMS_OUTPUT.PUT_LINE( 'update RPT_SG_NSMAN_INCOME from RPT_SG_NSMAN_INCOME_TMP completed ' );

		/*
		update RPT_SG_NSMAN_INCOME_TMP a set a set 
		a.FYC_RP= ( select sum(AMOUNT) from RPT_SG_NSMAN_INCOME_TMP b
		where a.PERIODSEQ=b.PERIODSEQ and a.POSITIONSEQ=b.POSITIONSEQ and b.AMOUNT_TYPE='FYC_RP');
		
		update RPT_SG_NSMAN_INCOME_TMP a set a.RYC= ( select sum(AMOUNT) from RPT_SG_NSMAN_INCOME_TMP b
		where a.PERIODSEQ=b.PERIODSEQ and a.POSITIONSEQ=b.POSITIONSEQ and b.AMOUNT_TYPE='FYC_SP');

		update RPT_SG_NSMAN_INCOME_TMP a set a.RYC= ( select sum(AMOUNT) from RPT_SG_NSMAN_INCOME_TMP b
		where a.PERIODSEQ=b.PERIODSEQ and a.POSITIONSEQ=b.POSITIONSEQ and b.AMOUNT_TYPE='RYC');
		
		update RPT_SG_NSMAN_INCOME_TMP a set a.RYC= ( select sum(AMOUNT) from RPT_SG_NSMAN_INCOME_TMP b
		where a.PERIODSEQ=b.PERIODSEQ and a.POSITIONSEQ=b.POSITIONSEQ and b.AMOUNT_TYPE='BENEFIT');
		*/
				
/*		INSERT INTO RPT_SG_NSMAN_INCOME( 
				PERIODSEQ        ,CYCLEDATE        ,PERIODNAME       ,
				PERIODSTARTDATE  ,PERIODENDDATE    ,PARTICIPANTSEQ   ,
				POSITIONSEQ      ,POSITIONNAME     ,AGENT_CODE       ,
				AGENT_NAME       ,AGENCY_CODE      ,AGENCY_NAME      ,
				FYC_RP           ,
				FYC_SP           ,
				RYC              ,
				BENEFIT          ,
				CREATE_DATE
		)
		SELECT	
			PERIODSEQ               ,CYCLEDATE               ,PERIODNAME              ,
			PERIODSTARTDATE         ,PERIODENDDATE           ,PARTICIPANTSEQ          ,
			POSITIONSEQ             ,POSITIONNAME            ,AGENT_CODE              ,
			AGENT_NAME              ,AGENCY_CODE             ,AGENCY_NAME             ,
			CASE 
				WHEN AMOUNT_TYPE = 'FYC_RP' THEN SUM(AMOUNT)
				ELSE 0
			END AS FYC_RP,
			CASE 
				WHEN AMOUNT_TYPE = 'FYC_SP' THEN SUM(AMOUNT)
				ELSE 0
			END AS FYC_SP,
			CASE 
				WHEN AMOUNT_TYPE = 'RYC' THEN SUM(AMOUNT)
				ELSE 0
			END AS RYC,
			CASE 
				WHEN AMOUNT_TYPE = 'BENEFIT' THEN SUM(AMOUNT)
				ELSE 0
			END AS BENEFIT,
			SYSDATE
		
		FROM	RPT_SG_NSMAN_INCOME_TMP
		GROUP BY PERIODSEQ               ,CYCLEDATE               ,PERIODNAME              ,
			PERIODSTARTDATE         ,PERIODENDDATE           ,PARTICIPANTSEQ          ,
			POSITIONSEQ             ,POSITIONNAME            ,AGENT_CODE              ,
			AGENT_NAME              ,AGENCY_CODE             ,AGENCY_NAME             ,
			AMOUNT_TYPE ;
*/		
		
		EXCEPTION
		WHEN OTHERS THEN
			ERROR_LOGGING;
		
	END;	
	
  PROCEDURE RPT_AIA_PARIS(V_PERIODSEQ CS_PERIOD.PERIODSEQ%TYPE) IS 
  
    VL_CYCLE_MONTH NUMBER;
    VL_CYCLE_YEAR NUMBER;
  BEGIN
    --V_PERIODSEQ := 2533274790398893;
    
    SELECT to_number(to_char(STARTDATE, 'MM')), 
      to_number(to_char(STARTDATE, 'YYYY'))
      INTO VL_CYCLE_MONTH, VL_CYCLE_YEAR FROM CS_PERIOD WHERE PERIODSEQ = V_PERIODSEQ;
    
    DELETE FROM AIA_PARIS WHERE DEC_MONTH = VL_CYCLE_MONTH AND DEC_YEAR = VL_CYCLE_YEAR;
    
    -- STANDALONE UM
    INSERT INTO AIA_PARIS 
      (DEC_MONTH,DEC_YEAR,
      TXT_DISTRICT_CODE,TXT_DISTRICT_NAME,TXT_AGENCY_CODE,TXT_AGENCY_NAME,
      TXT_LEADER_CODE,TXT_LEADER_NAME,TXT_LEADER_TITLE, DTE_AGENCY_DISSOLVED,TXT_STANDALONE_UM,
      DEC_CURR_YTD_FYP,DEC_CURR_YTD_RYP,DEC_LY_FYP,DEC_LY_RYP,
      DEC_CURR_YTD_FYP_B4_SOC,DEC_CURR_YTD_RYP_B4_SOC,DEC_LY_FYP_B4_SOC,DEC_LY_RYP_B4_SOC,
      DEC_L_YTD_TP,
      DEC_PERSISTENCY,
      TXT_MIN_RYP,
      TXT_MIN_FYP,
      TXT_MIN_PER,DEC_BONUS,DEC_BONUS_PAYMENT)
      SELECT distinct 
      VL_CYCLE_MONTH, VL_CYCLE_YEAR,
      pos.GENERICATTRIBUTE3 as distric_cd, districtpar.LASTNAME, SUBSTR(pos.NAME, -5) as agency_cd, (par.FIRSTNAME || ' ' || par.MIDDLENAME || ' ' || par.LASTNAME) as agency_name, 
      pos.GENERICATTRIBUTE2 as agent_cd, pos.GENERICATTRIBUTE7 as agent_name, pos.GENERICATTRIBUTE11 as rank, par.TERMINATIONDATE as dissolved_dt, 'Y', 
      0, 0, 0, 0, 
      coalesce(ytdparis.DEC_CURR_YTD_FYP_B4_SOC,0) + coalesce(fypmea.VALUE,0), coalesce(ytdparis.DEC_CURR_YTD_RYP_B4_SOC,0) + coalesce(rypmea.VALUE,0), coalesce(lyparis.DEC_LY_FYP_B4_SOC,0), coalesce(lyparis.DEC_LY_RYP_B4_SOC,0),
      (coalesce(lyparis.DEC_LY_FYP_B4_SOC,0) + coalesce(lyparis.DEC_LY_RYP_B4_SOC,0)) as pytd_tp,
      permea.VALUE, 
      CASE WHEN (coalesce(ytdparis.DEC_CURR_YTD_FYP_B4_SOC,0) + coalesce(fypmea.VALUE,0)) >= fvfypparis.value THEN 'Y' ELSE 'N' END as min_fyp,
      CASE WHEN (coalesce(ytdparis.DEC_CURR_YTD_RYP_B4_SOC,0) + coalesce(rypmea.VALUE,0)) >= fvrypparis.value THEN 'Y' ELSE 'N' END as min_ryp,
      CASE WHEN permea.VALUE >= fvperparis.VALUE THEN 'Y' ELSE 'N' END as min_per,
      incentive.GENERICNUMBER1, dep.VALUE
      FROM CS_MEASUREMENT mea
      INNER JOIN CS_PERIOD period ON period.PERIODSEQ = mea.PERIODSEQ AND period.REMOVEDATE > SYSDATE
      INNER JOIN CS_PAYEE pay ON mea.PAYEESEQ = pay.PAYEESEQ AND pay.REMOVEDATE > period.ENDDATE AND period.ENDDATE BETWEEN pay.EFFECTIVESTARTDATE AND pay.EFFECTIVEENDDATE - 1
      INNER JOIN CS_POSITION pos ON pos.PAYEESEQ = mea.PAYEESEQ AND pos.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN pos.EFFECTIVESTARTDATE AND pos.EFFECTIVEENDDATE - 1
      INNER JOIN CS_POSITION districtpos ON ('SGY' || pos.GENERICATTRIBUTE3) = districtpos.NAME AND districtpos.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpos.EFFECTIVESTARTDATE AND districtpos.EFFECTIVEENDDATE - 1
      INNER JOIN CS_PAYEE districtpay ON districtpos.PAYEESEQ = districtpay.PAYEESEQ AND districtpay.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpay.EFFECTIVESTARTDATE AND districtpay.EFFECTIVEENDDATE - 1
      INNER JOIN CS_PARTICIPANT districtpar ON districtpar.PAYEESEQ = districtpay.PAYEESEQ AND districtpar.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpar.EFFECTIVESTARTDATE AND districtpar.EFFECTIVEENDDATE - 1
      INNER JOIN CS_PARTICIPANT par ON par.PAYEESEQ = mea.PAYEESEQ AND par.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN par.EFFECTIVESTARTDATE and par.EFFECTIVEENDDATE - 1
      LEFT  JOIN (SELECT TXT_AGENCY_CODE, sum(coalesce(DEC_CURR_YTD_FYP_B4_SOC,0)) as DEC_CURR_YTD_FYP_B4_SOC, SUM(coalesce(DEC_CURR_YTD_RYP_B4_SOC,0)) as DEC_CURR_YTD_RYP_B4_SOC FROM AIA_PARIS WHERE VL_CYCLE_MONTH > DEC_MONTH AND VL_CYCLE_YEAR = DEC_YEAR GROUP BY TXT_AGENCY_CODE) ytdparis 
      -----modified by zhubin remove the prefix of position name  
            --ON pos.NAME = ytdparis.TXT_AGENCY_CODE
            ON substr(pos.name, -5) = ytdparis.TXT_AGENCY_CODE
      -----modified by zhubin 20130813
      LEFT JOIN (SELECT TXT_AGENCY_CODE, sum(coalesce(DEC_LY_FYP_B4_SOC,0)) as DEC_LY_FYP_B4_SOC, SUM(coalesce(DEC_LY_RYP_B4_SOC,0)) as DEC_LY_RYP_B4_SOC FROM AIA_PARIS WHERE VL_CYCLE_MONTH > DEC_MONTH AND (VL_CYCLE_YEAR - 1) = DEC_YEAR GROUP BY TXT_AGENCY_CODE) lyparis 
      -----modified by zhubin remove the prefix of position name  
           --ON pos.NAME = lyparis.TXT_AGENCY_CODE 
           ON substr(pos.name, -5) = lyparis.TXT_AGENCY_CODE
      -----modified by zhubin 20130813     
      LEFT JOIN CS_MEASUREMENT fypmea ON fypmea.PAYEESEQ = mea.PAYEESEQ AND fypmea.PERIODSEQ = mea.PERIODSEQ AND fypmea.NAME = 'PM_PARIS_FYP_Standalone_AM_Direct_Team'
      LEFT JOIN CS_MEASUREMENT rypmea ON rypmea.PAYEESEQ = mea.PAYEESEQ AND rypmea.PERIODSEQ = mea.PERIODSEQ AND rypmea.NAME = 'PM_PARIS_RYP_Standalone_AM_Direct_Team'
      LEFT JOIN CS_MEASUREMENT fypmea ON fypmea.PAYEESEQ = mea.PAYEESEQ AND fypmea.PERIODSEQ = mea.PERIODSEQ AND fypmea.NAME = 'PM_PARIS_FYP_Standalone_AM_Direct_Team'LEFT JOIN CS_MEASUREMENT permea ON permea.PAYEESEQ = mea.PAYEESEQ AND permea.PERIODSEQ = mea.PERIODSEQ AND fypmea.NAME = 'PM_Standalone_AM_PA_Persistency'
      INNER JOIN CS_FIXEDVALUE fvfypparis ON fvfypparis.NAME = 'FV_PARIS_FYP_UM' AND fvfypparis.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN fvfypparis.EFFECTIVESTARTDATE AND fvfypparis.EFFECTIVEENDDATE
      INNER JOIN CS_FIXEDVALUE fvrypparis ON fvrypparis.NAME = 'FV_PARIS_RYP_UM' AND fvrypparis.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN fvrypparis.EFFECTIVESTARTDATE AND fvrypparis.EFFECTIVEENDDATE
      INNER JOIN CS_FIXEDVALUE fvperparis ON fvperparis.NAME = 'FV_PARIS_PERSISTENCY' AND fvperparis.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN fvperparis.EFFECTIVESTARTDATE AND fvperparis.EFFECTIVEENDDATE
      LEFT JOIN CS_INCENTIVE incentive ON incentive.NAME = 'I_PARIS_AM_SG' AND incentive.PAYEESEQ = mea.PAYEESEQ AND incentive.PERIODSEQ = mea.PERIODSEQ
      LEFT JOIN CS_DEPOSIT dep ON dep.NAME = 'D_PARIS_AM_SG' AND incentive.PAYEESEQ = mea.PAYEESEQ AND incentive.PERIODSEQ = mea.PERIODSEQ
      WHERE mea.NAME = 'PM_PARIS_RYP_Standalone_AM_Direct_Team' and mea.PERIODSEQ = V_PERIODSEQ;
      
    DBMS_OUTPUT.PUT_LINE( 'INSERT for PARIS Standalone UM completed' );
    
    --DM
    INSERT INTO AIA_PARIS 
      (DEC_MONTH,DEC_YEAR,
      TXT_DISTRICT_CODE,TXT_DISTRICT_NAME,TXT_AGENCY_CODE,TXT_AGENCY_NAME,
      TXT_LEADER_CODE,TXT_LEADER_NAME,TXT_LEADER_TITLE, DTE_AGENCY_DISSOLVED,TXT_STANDALONE_UM,
      DEC_CURR_YTD_FYP,DEC_CURR_YTD_RYP,DEC_LY_FYP,DEC_LY_RYP,
      DEC_CURR_YTD_FYP_B4_SOC,DEC_CURR_YTD_RYP_B4_SOC,DEC_LY_FYP_B4_SOC,DEC_LY_RYP_B4_SOC,
      DEC_L_YTD_TP,
      DEC_PERSISTENCY,
      TXT_MIN_RYP,
      TXT_MIN_FYP,
      TXT_MIN_PER,DEC_BONUS,DEC_BONUS_PAYMENT)
      SELECT distinct
      VL_CYCLE_MONTH, VL_CYCLE_YEAR,
      pos.GENERICATTRIBUTE3 as distric_cd, districtpar.LASTNAME, SUBSTR(pos.NAME, -5) as agency_cd, (par.FIRSTNAME || ' ' || par.MIDDLENAME || ' ' || par.LASTNAME) as agency_name, 
      pos.GENERICATTRIBUTE2 as agent_cd, pos.GENERICATTRIBUTE7 as agent_name, pos.GENERICATTRIBUTE11 as rank, par.TERMINATIONDATE as dissolved_dt, 'Y', 
      coalesce(ytdparis.DEC_CURR_YTD_FYP,0) + coalesce(fypmea.VALUE,0), coalesce(ytdparis.DEC_CURR_YTD_RYP,0) + coalesce(mea.VALUE,0), coalesce(lyparis.DEC_LY_FYP,0), coalesce(lyparis.DEC_LY_RYP,0),
      0, 0, 0, 0, 
      (coalesce(lyparis.DEC_LY_FYP,0) + coalesce(lyparis.DEC_LY_RYP,0)) as pytd_tp,
      coalesce(permea.VALUE,0), 
      CASE WHEN (coalesce(ytdparis.DEC_CURR_YTD_FYP,0) + coalesce(fypmea.VALUE,0)) >= rypyearmea.GENERICNUMBER1 THEN 'Y' ELSE 'N' END as min_fyp,
      CASE WHEN (coalesce(ytdparis.DEC_CURR_YTD_RYP,0) + coalesce(mea.VALUE,0)) >= rypyearmea.GENERICNUMBER2 THEN 'Y' ELSE 'N' END as min_ryp,
      CASE WHEN permea.VALUE >= fvperparis.VALUE THEN 'Y' ELSE 'N' END as min_per,
      incentive.GENERICNUMBER1, dep.VALUE
      FROM CS_MEASUREMENT mea
      INNER JOIN CS_PERIOD period ON period.PERIODSEQ = mea.PERIODSEQ AND period.REMOVEDATE > SYSDATE
      INNER JOIN CS_PAYEE pay ON mea.PAYEESEQ = pay.PAYEESEQ AND pay.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN pay.EFFECTIVESTARTDATE AND pay.EFFECTIVEENDDATE - 1
      INNER JOIN CS_POSITION pos ON pos.PAYEESEQ = mea.PAYEESEQ AND pos.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN pos.EFFECTIVESTARTDATE AND pos.EFFECTIVEENDDATE - 1
      INNER JOIN CS_POSITION districtpos ON ('SGY' || pos.GENERICATTRIBUTE3) = districtpos.NAME AND districtpos.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpos.EFFECTIVESTARTDATE AND districtpos.EFFECTIVEENDDATE - 1
      INNER JOIN CS_PAYEE districtpay ON districtpos.PAYEESEQ = districtpay.PAYEESEQ AND districtpay.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpay.EFFECTIVESTARTDATE AND districtpay.EFFECTIVEENDDATE - 1
      INNER JOIN CS_PARTICIPANT districtpar ON districtpar.PAYEESEQ = districtpay.PAYEESEQ AND districtpar.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpar.EFFECTIVESTARTDATE AND districtpar.EFFECTIVEENDDATE - 1
      INNER JOIN CS_PARTICIPANT par ON par.PAYEESEQ = mea.PAYEESEQ AND par.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN par.EFFECTIVESTARTDATE and par.EFFECTIVEENDDATE - 1
      LEFT  JOIN (SELECT TXT_AGENCY_CODE, sum(DEC_CURR_YTD_FYP) as DEC_CURR_YTD_FYP, SUM(DEC_CURR_YTD_RYP) as DEC_CURR_YTD_RYP FROM AIA_PARIS WHERE to_number(to_char(SYSDATE, 'MM')) > DEC_MONTH AND to_number(to_char(SYSDATE, 'YYYY')) = DEC_YEAR GROUP BY TXT_AGENCY_CODE) ytdparis 
      -----modified by zhubin remove the prefix of position name  
            --ON pos.NAME = ytdparis.TXT_AGENCY_CODE
            ON substr(pos.name, -5) = ytdparis.TXT_AGENCY_CODE
      -----modified by zhubin 20130813
      LEFT  JOIN (SELECT TXT_AGENCY_CODE, sum(DEC_LY_FYP) as DEC_LY_FYP, SUM(DEC_LY_RYP) as DEC_LY_RYP FROM AIA_PARIS WHERE to_number(to_char(SYSDATE, 'MM')) > DEC_MONTH AND (to_number(to_char(SYSDATE, 'YYYY')) - 1) = DEC_YEAR GROUP BY TXT_AGENCY_CODE) lyparis 
      -----modified by zhubin remove the prefix of position name  
            --ON pos.NAME = lyparis.TXT_AGENCY_CODE 
            ON substr(pos.name, -5) = lyparis.TXT_AGENCY_CODE
      -----modified by zhubin 20130813
      LEFT JOIN CS_MEASUREMENT fypmea ON fypmea.PAYEESEQ = mea.PAYEESEQ AND fypmea.PERIODSEQ = mea.PERIODSEQ AND fypmea.NAME = 'PM_PARIS_FYP_Exluding_Standalone_AM_Direct_Team'
      LEFT JOIN CS_MEASUREMENT permea ON permea.PAYEESEQ = mea.PAYEESEQ AND permea.PERIODSEQ = mea.PERIODSEQ AND fypmea.NAME = 'PM_District_PA_Persistency'
      LEFT JOIN CS_MEASUREMENT rypyearmea ON rypyearmea.PAYEESEQ = mea.PAYEESEQ AND rypyearmea.PERIODSEQ = mea.PERIODSEQ AND rypyearmea.NAME = 'SM_DM_PARIS_RYP_YEAR_SG'
      INNER JOIN CS_FIXEDVALUE fvperparis ON fvperparis.NAME = 'FV_PARIS_PERSISTENCY' AND fvperparis.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN fvperparis.EFFECTIVESTARTDATE AND fvperparis.EFFECTIVEENDDATE
      LEFT JOIN CS_INCENTIVE incentive ON incentive.NAME = 'I_PARIS_DM_SG' AND incentive.PAYEESEQ = mea.PAYEESEQ AND incentive.PERIODSEQ = mea.PERIODSEQ
      LEFT JOIN CS_DEPOSIT dep ON dep.NAME = 'D_PARIS_DM_SG' AND incentive.PAYEESEQ = mea.PAYEESEQ AND incentive.PERIODSEQ = mea.PERIODSEQ
      WHERE mea.NAME = 'PM_PARIS_RYP_Exluding_Standalone_AM_Direct_Team' and mea.PERIODSEQ = V_PERIODSEQ AND 
      NOT EXISTS(SELECT 1 FROM AIA_PARIS WHERE DEC_MONTH = VL_CYCLE_MONTH AND DEC_YEAR = VL_CYCLE_YEAR AND TXT_DISTRICT_CODE = pos.GENERICATTRIBUTE3 AND TXT_AGENCY_CODE = SUBSTR(pos.NAME, -5));
    
    DBMS_OUTPUT.PUT_LINE( 'INSERT for PARIS DM is completed ' );
    
    --	For DM Update
    UPDATE AIA_PARIS P SET (P.DEC_CURR_YTD_FYP,P.DEC_CURR_YTD_RYP,P.DEC_LY_FYP,P.DEC_LY_RYP, 
      P.DEC_L_YTD_TP,
      P.DEC_PERSISTENCY,
      P.TXT_MIN_RYP,
      P.TXT_MIN_FYP,
      P.TXT_MIN_PER,
      P.DEC_BONUS,DEC_BONUS_PAYMENT) = 
      (SELECT distinct
      coalesce(ytdparis.DEC_CURR_YTD_FYP,0) + coalesce(fypmea.VALUE,0), coalesce(ytdparis.DEC_CURR_YTD_RYP,0) + coalesce(mea.VALUE,0), coalesce(lyparis.DEC_LY_FYP,0), coalesce(lyparis.DEC_LY_RYP,0),
      (coalesce(lyparis.DEC_LY_FYP,0) + coalesce(lyparis.DEC_LY_RYP,0)),
      coalesce(permea.VALUE,0), 
      CASE WHEN (coalesce(ytdparis.DEC_CURR_YTD_FYP,0) + coalesce(fypmea.VALUE,0)) >= rypyearmea.GENERICNUMBER1 THEN 'Y' ELSE 'N' END as min_fyp,
      CASE WHEN (coalesce(ytdparis.DEC_CURR_YTD_RYP,0) + coalesce(mea.VALUE,0)) >= rypyearmea.GENERICNUMBER2 THEN 'Y' ELSE 'N' END as min_ryp,
      CASE WHEN permea.VALUE >= fvperparis.VALUE THEN 'Y' ELSE 'N' END as min_per,
      incentive.GENERICNUMBER1, dep.VALUE
      FROM CS_MEASUREMENT mea
      INNER JOIN CS_PERIOD period ON period.PERIODSEQ = mea.PERIODSEQ AND period.REMOVEDATE > SYSDATE
      INNER JOIN CS_PAYEE pay ON mea.PAYEESEQ = pay.PAYEESEQ AND pay.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN pay.EFFECTIVESTARTDATE AND pay.EFFECTIVEENDDATE - 1
      INNER JOIN CS_POSITION pos ON pos.PAYEESEQ = mea.PAYEESEQ AND pos.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN pos.EFFECTIVESTARTDATE AND pos.EFFECTIVEENDDATE - 1
      INNER JOIN CS_POSITION districtpos 
      ----modified by Bin maybe the pos'SELECT prefix is 'BRY'       
            --ON ('SGY' || pos.GENERICATTRIBUTE3) = substr(districtpos.NAME,-5) AND districtpos.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpos.EFFECTIVESTARTDATE AND districtpos.EFFECTIVEENDDATE - 1
            ON pos.GENERICATTRIBUTE3 = substr(districtpos.NAME,-5) AND districtpos.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpos.EFFECTIVESTARTDATE AND districtpos.EFFECTIVEENDDATE - 1
      ----modified by Bin 20140814
      INNER JOIN CS_PAYEE districtpay ON districtpos.PAYEESEQ = districtpay.PAYEESEQ AND districtpay.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpay.EFFECTIVESTARTDATE AND districtpay.EFFECTIVEENDDATE - 1
      INNER JOIN CS_PARTICIPANT districtpar ON districtpar.PAYEESEQ = districtpay.PAYEESEQ AND districtpar.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN districtpar.EFFECTIVESTARTDATE AND districtpar.EFFECTIVEENDDATE - 1
      INNER JOIN CS_PARTICIPANT par ON par.PAYEESEQ = mea.PAYEESEQ AND par.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN par.EFFECTIVESTARTDATE and par.EFFECTIVEENDDATE - 1
      LEFT  JOIN (SELECT TXT_AGENCY_CODE, sum(DEC_CURR_YTD_FYP) as DEC_CURR_YTD_FYP, SUM(DEC_CURR_YTD_RYP) as DEC_CURR_YTD_RYP FROM AIA_PARIS WHERE to_number(to_char(SYSDATE, 'MM')) > DEC_MONTH AND to_number(to_char(SYSDATE, 'YYYY')) = DEC_YEAR GROUP BY TXT_AGENCY_CODE) ytdparis 
      -----modified by zhubin remove the prefix of position name  
            --ON pos.NAME = ytdparis.TXT_AGENCY_CODE
            ON substr(pos.name, -5) = ytdparis.TXT_AGENCY_CODE
      -----modified by zhubin 20130813
      LEFT  JOIN (SELECT TXT_AGENCY_CODE, sum(DEC_LY_FYP) as DEC_LY_FYP, SUM(DEC_LY_RYP) as DEC_LY_RYP FROM AIA_PARIS WHERE to_number(to_char(SYSDATE, 'MM')) > DEC_MONTH AND (to_number(to_char(SYSDATE, 'YYYY')) - 1) = DEC_YEAR GROUP BY TXT_AGENCY_CODE) lyparis 
      -----modified by zhubin remove the prefix of position name  
            --ON pos.NAME = lyparis.TXT_AGENCY_CODE 
            ON substr(pos.name, -5) = lyparis.TXT_AGENCY_CODE
      -----modified by zhubin 20130813
      LEFT JOIN CS_MEASUREMENT fypmea ON fypmea.PAYEESEQ = mea.PAYEESEQ AND fypmea.PERIODSEQ = mea.PERIODSEQ AND fypmea.NAME = 'PM_PARIS_FYP_Exluding_Standalone_AM_Direct_Team'
      LEFT JOIN CS_MEASUREMENT permea ON permea.PAYEESEQ = mea.PAYEESEQ AND permea.PERIODSEQ = mea.PERIODSEQ AND fypmea.NAME = 'PM_District_PA_Persistency'
      LEFT JOIN CS_MEASUREMENT rypyearmea ON rypyearmea.PAYEESEQ = mea.PAYEESEQ AND rypyearmea.PERIODSEQ = mea.PERIODSEQ AND rypyearmea.NAME = 'SM_DM_PARIS_RYP_YEAR_SG'
      INNER JOIN CS_FIXEDVALUE fvperparis ON fvperparis.NAME = 'FV_PARIS_PERSISTENCY' AND fvperparis.REMOVEDATE > SYSDATE AND period.ENDDATE BETWEEN fvperparis.EFFECTIVESTARTDATE AND fvperparis.EFFECTIVEENDDATE
      LEFT JOIN CS_INCENTIVE incentive ON incentive.NAME = 'I_PARIS_DM_SG' AND incentive.PAYEESEQ = mea.PAYEESEQ AND incentive.PERIODSEQ = mea.PERIODSEQ
      LEFT JOIN CS_DEPOSIT dep ON dep.NAME = 'D_PARIS_DM_SG' AND incentive.PAYEESEQ = mea.PAYEESEQ AND incentive.PERIODSEQ = mea.PERIODSEQ
      WHERE mea.NAME = 'PM_PARIS_RYP_Exluding_Standalone_AM_Direct_Team' and mea.PERIODSEQ = V_PERIODSEQ AND 
      VL_CYCLE_MONTH = p.DEC_MONTH AND p.DEC_YEAR = VL_CYCLE_YEAR AND p.TXT_DISTRICT_CODE = pos.GENERICATTRIBUTE3 AND p.TXT_AGENCY_CODE = SUBSTR(pos.NAME, -5) AND
      EXISTS(SELECT 1 FROM AIA_PARIS WHERE DEC_MONTH = VL_CYCLE_MONTH AND DEC_YEAR = VL_CYCLE_YEAR AND TXT_DISTRICT_CODE = pos.GENERICATTRIBUTE3 AND TXT_AGENCY_CODE = SUBSTR(pos.NAME, -5)))
      ----added by zhubin just update the cycle period records
      WHERE P.DEC_MONTH = VL_CYCLE_MONTH AND P.DEC_YEAR = VL_CYCLE_YEAR
      ----added by zhubin
      ;
      
      DBMS_OUTPUT.PUT_LINE( 'Update PARIS DM completed ' );
      DBMS_OUTPUT.PUT_LINE( 'RPT_AIA_PARIS completed ' );
  END;
  
	PROCEDURE RPT_POPULATE_ALL IS BEGIN  
		INIT;
		------
		RPT_CLERICAL_ALLOWANCE;
		RPT_PA_QTR_PRD_BONUS;
		RPT_PRD_BENEFIT_FRM_UM;
		-- Added by Donny-20140613
		SP_RPT_SG_NSMAN_INCOME( V_PERIODSEQ );
		------
    RPT_AIA_PARIS ( V_PERIODSEQ);
		COMMIT;  
	EXCEPTION
	WHEN OTHERS THEN
		NULL;
	END;
BEGIN
	DBMS_OUTPUT.PUT_LINE( 'Init...' );
	
	/*
		SELECT * FROM RPT_SGPAGY_CLERICAL_ALLOWANCE
		order by district_code;
		
		--February 2000
		UPDATE in_etl_control
		SET txt_key_value = '2000-02-29'
		WHERE txt_key_string = 'OPER_CYCLE_DATE'
		AND TXT_FILE_NAME = 'GLOBAL'
		
		BEGIN
			RPT_SGP_AGY_PKG.RPT_POPULATE_ALL;
		END;
		
		SIT December 2013 = 2533274790398889
		
		January 2015 = 2533274790398907
		January 2016 = 2533274790398924
		January 2017 = 2533274790398941
	*/
END;
/
