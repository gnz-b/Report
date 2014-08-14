CREATE OR REPLACE PACKAGE AIA_SINGAPORE_REPORT_PKG IS

  --All organise information use newest, so islast = 1

  C_REMOVEDATE DATE := TO_DATE('2200-1-1', 'YYYY-MM-DD');

  V_ERROR_CODE    VARCHAR2(255);
  V_ERROR_MESSAGE VARCHAR2(255);

  PROCEDURE AIA_ERROR_LOG;
  PROCEDURE AIA_AGENT_INFORMATION;
  PROCEDURE AIA_DISTRICT_UNIT_AGENT_INFOR;
  PROCEDURE AIA_DEPOSIT_TRACE_BACK;

  PROCEDURE AIA_INCOME_SUMMARY_PROC;
  PROCEDURE AIA_INCOME_SUMMARY_BRUNEI_PROC;
  PROCEDURE AIA_NLPI_PROC;
  PROCEDURE AIA_SPI_PROC;
  PROCEDURE AIA_RENEWAL_COMMISSION_PROC;
  PROCEDURE AIA_DIRECT_OVERRIDE_PROC;
  PROCEDURE AIA_RENEWAL_OVERRIDE_PROC;
  PROCEDURE AIA_CAREER_BENEFIT_PROC;
  ------
  PROCEDURE AIA_BALANCE_DATA;
  PROCEDURE AIA_AGEING_DETAIL_PROC;
  ------
  PROCEDURE AIA_QTRLY_PROD_BONUS_PROC;
  PROCEDURE AIA_INDIRECT_OVERRIDE_PROC;
  ------
  PROCEDURE AIA_AOR_PROC;
  PROCEDURE AIA_AOR_UNIT_PROC;
  ------
  PROCEDURE AIA_ADPI_PROC;

  PROCEDURE AIA_SINGAPORE_REPORT_PROC;

END;
/
CREATE OR REPLACE PACKAGE BODY AIA_SINGAPORE_REPORT_PKG IS
  ------position version start date always equal to participant
  ------position latest version end date always equal to end of time
  ------position terminated status is updated on participant
  V_CALENDARNAME    CS_CALENDAR.NAME%TYPE;
  V_PERIODSEQ       CS_PERIOD.PERIODSEQ%TYPE;
  V_PERIODNAME      CS_PERIOD.NAME%TYPE;
  V_PERIODSTARTDATE CS_PERIOD.STARTDATE%TYPE;
  V_PERIODENDDATE   CS_PERIOD.ENDDATE%TYPE;
  V_CALENDARSEQ     CS_CALENDAR.CALENDARSEQ%TYPE;
  V_PERIODTYPESEQ   CS_PERIODTYPE.PERIODTYPESEQ%TYPE;
  ------the prior period
  V_PRIOR_PERIODSEQ CS_PERIOD.PERIODSEQ%TYPE;

  PROCEDURE AIA_ERROR_LOG IS
  BEGIN
    V_ERROR_CODE    := SQLCODE;
    V_ERROR_MESSAGE := SQLERRM;
    INSERT INTO AIA_ERROR_MESSAGE
      (RECORDNO, ERRORCODE, ERRORMESSAGE, ERRORBACKTRACE, CREATEDATE)
    VALUES
      (AIA_ERROR_MESSAGE_S.NEXTVAL,
       V_ERROR_CODE,
       V_ERROR_MESSAGE,
       DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
       SYSDATE);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  PROCEDURE AIA_AGENT_INFORMATION IS
  
  BEGIN
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE AIA_PAYEE_INFOR';
    ------All SGPAGY Agents' Information, latest version in this period
    INSERT INTO AIA_PAYEE_INFOR
      (PARTICIPANTSEQ,
       POSITIONSEQ,
       PARTICIPANTID,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       BUSINESSUNITNAME,
       CREATE_DATE)
      SELECT MAX(PAY.PAYEESEQ),
             MAX(POS.RULEELEMENTOWNERSEQ),
             UPPER(SUBSTR(PAY.PAYEEID, 4)),
             MAX(POS.EFFECTIVESTARTDATE),
             MAX(POS.EFFECTIVEENDDATE),
             BUS.NAME,
             SYSDATE
        FROM CS_PAYEE PAY, CS_POSITION POS, CS_BUSINESSUNIT BUS
       WHERE POS.PAYEESEQ = PAY.PAYEESEQ
         AND PAY.REMOVEDATE = C_REMOVEDATE
         AND POS.REMOVEDATE = C_REMOVEDATE
         AND POS.EFFECTIVEENDDATE - 1 BETWEEN PAY.EFFECTIVESTARTDATE AND
             PAY.EFFECTIVEENDDATE - 1
         AND PAY.BUSINESSUNITMAP = BUS.MASK
         AND BUS.NAME IN ('SGPAGY',
                          'BRUAGY',
                          'SGPPD',
                          'BRUPD',
                          'SGP_Multi_Channel',
                          'BRU_Multi_Channel')
         AND V_PERIODENDDATE - 1 BETWEEN POS.EFFECTIVESTARTDATE AND
             POS.EFFECTIVEENDDATE - 1
       GROUP BY PAY.PAYEEID, BUS.NAME;
    -------update Position/Participant information
    UPDATE AIA_PAYEE_INFOR T
       SET (MANAGERSEQ,
            PREFIX,
            FIRSTNAME,
            MIDDLENAME,
            LASTNAME,
            SUFFIX,
            POSITIONNAME,
            POSITIONTITLE,
            SALARY,
            HIREDATE,
            TERMINATIONDATE,
            GENERICATTRIBUTE1, --Status Code
            GENERICATTRIBUTE2, --Agency Code
            GENERICATTRIBUTE4, --Leader Code
            GENERICATTRIBUTE5, --Leader Name
            GENERICATTRIBUTE6, --District Code
            GENERICATTRIBUTE8, --Class Code
            GENERICATTRIBUTE9,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE8) =
           (SELECT POS.MANAGERSEQ,
                   UPPER(PAR.PREFIX),
                   UPPER(PAR.FIRSTNAME),
                   UPPER(PAR.MIDDLENAME),
                   UPPER(PAR.LASTNAME),
                   UPPER(PAR.SUFFIX),
                   UPPER(POS.NAME),
                   UPPER(TIT.NAME),
                   PAR.SALARY,
                   PAR.HIREDATE,
                   PAR.TERMINATIONDATE,
                   CASE
                     WHEN PAR.GENERICATTRIBUTE1 < 50 THEN
                      'Inforce'
                     WHEN PAR.GENERICATTRIBUTE1 >= 50 THEN
                      'Terminated'
                     ELSE
                      ''
                   END, ------Status Code
                   UPPER(POS.GENERICATTRIBUTE1), ------Agency Code
                   UPPER(POS.GENERICATTRIBUTE2), ------Leader Code
                   UPPER(POS.GENERICATTRIBUTE7), ------Leader Name
                   UPPER(POS.GENERICATTRIBUTE3), ------District Code
                   UPPER(POS.GENERICATTRIBUTE4), ------Class Code
                   PAR.GENERICATTRIBUTE1, ------Status Number
                   POS.GENERICDATE1, ------Promotion Date
                   POS.GENERICDATE2, ------Demotion Date
                   POS.GENERICDATE4 ------Assigned_Date
              FROM CS_PARTICIPANT PAR, CS_POSITION POS, CS_TITLE TIT
             WHERE POS.PAYEESEQ = PAR.PAYEESEQ
               AND POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
               AND POS.EFFECTIVEENDDATE - 1 BETWEEN PAR.EFFECTIVESTARTDATE AND
                   PAR.EFFECTIVEENDDATE - 1
               AND POS.EFFECTIVEENDDATE - 1 BETWEEN TIT.EFFECTIVESTARTDATE AND
                   TIT.EFFECTIVEENDDATE - 1
               AND POS.REMOVEDATE = C_REMOVEDATE
               AND PAR.REMOVEDATE = C_REMOVEDATE
               AND TIT.REMOVEDATE = C_REMOVEDATE
               AND POS.RULEELEMENTOWNERSEQ = T.POSITIONSEQ
               AND POS.EFFECTIVESTARTDATE = T.EFFECTIVESTARTDATE
               AND ROWNUM = 1),
           UPDATE_DATE = SYSDATE;
    ---------update Agency/District name
    UPDATE AIA_PAYEE_INFOR T
       SET T.GENERICATTRIBUTE3 =
           /*(SELECT API.PREFIX || API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME ||
                 API.SUFFIX
            FROM AIA_PAYEE_INFOR API
           WHERE API.PARTICIPANTID = T.GENERICATTRIBUTE2 ------Agency Code
             AND T.EFFECTIVEENDDATE - 1 BETWEEN API.EFFECTIVESTARTDATE AND
                 API.EFFECTIVEENDDATE - 1
             AND (UPPER(API.POSITIONTITLE) LIKE '%AGENCY' OR
                 UPPER(API.POSITIONTITLE) LIKE '%DISTRICT')
             AND API.BUSINESSUNITNAME = T.BUSINESSUNITNAME
             AND ROWNUM = 1),*/(SELECT PAR.PREFIX || PAR.FIRSTNAME ||
                                       PAR.MIDDLENAME || PAR.LASTNAME ||
                                       PAR.SUFFIX
                                  FROM CS_PAYEE        PAY,
                                       CS_PARTICIPANT  PAR,
                                       CS_POSITION     POS,
                                       CS_TITLE        TIT,
                                       CS_BUSINESSUNIT BUS
                                 WHERE PAY.PAYEESEQ = PAR.PAYEESEQ
                                   AND PAY.EFFECTIVESTARTDATE =
                                       PAR.EFFECTIVESTARTDATE
                                   AND PAY.REMOVEDATE = PAR.REMOVEDATE
                                   AND PAY.REMOVEDATE = C_REMOVEDATE
                                   AND TIT.REMOVEDATE = C_REMOVEDATE
                                   AND TIT.ISLAST = 1
                                   AND (UPPER(TIT.NAME) LIKE '%AGENCY' OR
                                       UPPER(TIT.NAME) LIKE '%DISTRICT')
                                   AND PAY.BUSINESSUNITMAP = BUS.MASK
                                   AND POS.PAYEESEQ = PAY.PAYEESEQ
                                   AND POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
                                   AND POS.EFFECTIVEENDDATE - 1 BETWEEN
                                       PAY.EFFECTIVESTARTDATE AND
                                       PAY.EFFECTIVEENDDATE - 1
                                   AND T.EFFECTIVEENDDATE - 1 BETWEEN
                                       POS.EFFECTIVESTARTDATE AND
                                       POS.EFFECTIVEENDDATE - 1
                                   AND UPPER(SUBSTR(PAY.PAYEEID, 4)) =
                                       T.GENERICATTRIBUTE2 ------Agency Code
                                   AND BUS.NAME = T.BUSINESSUNITNAME
                                   AND ROWNUM = 1),
           T.GENERICATTRIBUTE7 =
           /*(SELECT API.PREFIX || API.FIRSTNAME ||
                 API.MIDDLENAME || API.LASTNAME ||
                 API.SUFFIX
            FROM AIA_PAYEE_INFOR API
           WHERE API.PARTICIPANTID = T.GENERICATTRIBUTE6 ------District Code
             AND T.EFFECTIVEENDDATE - 1 BETWEEN
                 API.EFFECTIVESTARTDATE AND
                 API.EFFECTIVEENDDATE - 1
             AND UPPER(API.POSITIONTITLE) LIKE '%DISTRICT'
             AND API.BUSINESSUNITNAME = T.BUSINESSUNITNAME
             AND ROWNUM = 1),*/(SELECT PAR.PREFIX || PAR.FIRSTNAME ||
                                       PAR.MIDDLENAME || PAR.LASTNAME ||
                                       PAR.SUFFIX
                                  FROM CS_PAYEE        PAY,
                                       CS_PARTICIPANT  PAR,
                                       CS_POSITION     POS,
                                       CS_TITLE        TIT,
                                       CS_BUSINESSUNIT BUS
                                 WHERE PAY.PAYEESEQ = PAR.PAYEESEQ
                                   AND PAY.EFFECTIVESTARTDATE =
                                       PAR.EFFECTIVESTARTDATE
                                   AND PAY.REMOVEDATE = PAR.REMOVEDATE
                                   AND PAY.REMOVEDATE = C_REMOVEDATE
                                   AND TIT.REMOVEDATE = C_REMOVEDATE
                                   AND TIT.ISLAST = 1
                                      --Modified by zhubin 20140808 temp 
                                      --AND UPPER(TIT.NAME) LIKE '%DISTRICT'
                                   AND (UPPER(TIT.NAME) LIKE '%AGENCY' OR
                                       UPPER(TIT.NAME) LIKE '%DISTRICT')
                                      --Modified by zhubin
                                   AND PAY.BUSINESSUNITMAP = BUS.MASK
                                   AND POS.PAYEESEQ = PAY.PAYEESEQ
                                   AND POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
                                   AND POS.EFFECTIVEENDDATE - 1 BETWEEN
                                       PAY.EFFECTIVESTARTDATE AND
                                       PAY.EFFECTIVEENDDATE - 1
                                   AND T.EFFECTIVEENDDATE - 1 BETWEEN
                                       POS.EFFECTIVESTARTDATE AND
                                       POS.EFFECTIVEENDDATE - 1
                                   AND UPPER(SUBSTR(PAY.PAYEEID, 4)) =
                                       T.GENERICATTRIBUTE6 ------District Code
                                   AND BUS.NAME = T.BUSINESSUNITNAME
                                   AND ROWNUM = 1),
           (T.GENERICDATE3, T.GENERICDATE4, T.GENERICBOOLEAN1) =
           (SELECT GPOS.GENERICDATE1, GPOS.GENERICDATE2, GPOS.GENERICBOOLEAN4 ------NLPI Exception Indicator
              FROM CS_GAPOSITION GPOS
             WHERE GPOS.RULEELEMENTOWNERSEQ = T.POSITIONSEQ
               AND GPOS.EFFECTIVESTARTDATE = T.EFFECTIVESTARTDATE
               AND GPOS.REMOVEDATE = C_REMOVEDATE
               AND GPOS.PAGENUMBER = 0
               AND ROWNUM = 1),
           (T.GENERICDATE5, T.GENERICDATE6) =
           (SELECT GPOS.GENERICDATE7, ------Suspend Date
                   GPOS.GENERICDATE8 ------Release Date
              FROM CS_GAPOSITION GPOS
             WHERE GPOS.RULEELEMENTOWNERSEQ = T.POSITIONSEQ
               AND GPOS.EFFECTIVESTARTDATE = T.EFFECTIVESTARTDATE
               AND GPOS.REMOVEDATE = C_REMOVEDATE
               AND GPOS.PAGENUMBER = 0
               AND ROWNUM = 1),
           T.GENERICDATE7 =
           (SELECT DTEEFFECTIVEDATE AS CROSSOVERDATE
              FROM IN_PI_AOR_SETUP
             WHERE TXTTYPE IN ('C', 'D')
               AND DTEEFFECTIVEDATE IS NOT NULL
               AND DTECYCLE = LAST_DAY(V_PERIODSTARTDATE)
               AND TXTOLDDMNAME = T.PARTICIPANTID
               AND DECSTATUS = 0
               AND ROWNUM = 1),
           T.GENERICDATE9 =
           (SELECT GPOS.GENERICDATE9 ------Appointment_Date
              FROM CS_GAPOSITION GPOS
             WHERE GPOS.RULEELEMENTOWNERSEQ = T.POSITIONSEQ
               AND GPOS.EFFECTIVESTARTDATE = T.EFFECTIVESTARTDATE
               AND GPOS.REMOVEDATE = C_REMOVEDATE
               AND GPOS.PAGENUMBER = 0
               AND ROWNUM = 1),
           UPDATE_DATE = SYSDATE;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_DISTRICT_UNIT_AGENT_INFOR IS
  BEGIN
    DELETE FROM AIA_DISTRICT_UNIT_AGENT T WHERE T.PERIODSEQ = V_PERIODSEQ;
    INSERT INTO AIA_DISTRICT_UNIT_AGENT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PERIODYEAR,
       PERIODMONTH,
       PERIODMONTHSEQ,
       BUSINESSUNITNAME,
       --POSITIONTITLE,
       DISTRICT_CODE,
       DISTRICT_CODE_DESC,
       UNIT_CODE,
       UNIT_CODE_DESC,
       --AGENT_CODE,
       --AGENT_CODE_DESC,
       CREATE_DATE)
      SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      EXTRACT(YEAR FROM V_PERIODSTARTDATE),
                      SUBSTR(V_PERIODNAME, 0, LENGTH(V_PERIODNAME) - 5),
                      SUBSTR('0' || MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 13), -2),
                      T.BUSINESSUNITNAME,
                      --T.POSITIONTITLE,
                      T.GENERICATTRIBUTE6 DISTRICT_CODE,
                      T.GENERICATTRIBUTE6 || ' - ' || T.GENERICATTRIBUTE7 DISTRICT_CODE_DESC,
                      T.GENERICATTRIBUTE2 UNIT_CODE,
                      T.GENERICATTRIBUTE2 || ' - ' || T.GENERICATTRIBUTE3 UNIT_CODE_DESC,
                      --T.PARTICIPANTID AGENT_CODE,
                      --T.PARTICIPANTID || ' - ' || T.FIRSTNAME || T.MIDDLENAME ||
                      --T.LASTNAME AGENT_CODE_DESC,
                      SYSDATE
        FROM AIA_PAYEE_INFOR T
       WHERE T.GENERICATTRIBUTE6 IS NOT NULL
         AND T.GENERICATTRIBUTE2 IS NOT NULL
      UNION ALL
      SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      EXTRACT(YEAR FROM V_PERIODSTARTDATE),
                      SUBSTR(V_PERIODNAME, 0, LENGTH(V_PERIODNAME) - 5),
                      SUBSTR('0' || MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 13), -2),
                      T.BUSINESSUNITNAME,
                      --T.POSITIONTITLE,
                      'All' DISTRICT_CODE,
                      ' All District' DISTRICT_CODE_DESC,
                      T.GENERICATTRIBUTE2 UNIT_CODE,
                      T.GENERICATTRIBUTE2 || ' - ' || T.GENERICATTRIBUTE3 UNIT_CODE_DESC,
                      --T.PARTICIPANTID AGENT_CODE,
                      --T.PARTICIPANTID || ' - ' || T.FIRSTNAME || T.MIDDLENAME ||
                      --T.LASTNAME AGENT_CODE_DESC,
                      SYSDATE
        FROM AIA_PAYEE_INFOR T
       WHERE T.GENERICATTRIBUTE2 IS NOT NULL
      UNION ALL
      SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      EXTRACT(YEAR FROM V_PERIODSTARTDATE),
                      SUBSTR(V_PERIODNAME, 0, LENGTH(V_PERIODNAME) - 5),
                      SUBSTR('0' || MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 13), -2),
                      T.BUSINESSUNITNAME,
                      --T.POSITIONTITLE,
                      T.GENERICATTRIBUTE6 DISTRICT_CODE,
                      T.GENERICATTRIBUTE6 || ' - ' || T.GENERICATTRIBUTE7 DISTRICT_CODE_DESC,
                      'All' UNIT_CODE,
                      ' All Unit' UNIT_CODE_DESC,
                      --T.PARTICIPANTID AGENT_CODE,
                      --T.PARTICIPANTID || ' - ' || T.FIRSTNAME || T.MIDDLENAME ||
                      --T.LASTNAME AGENT_CODE_DESC,
                      SYSDATE
        FROM AIA_PAYEE_INFOR T
       WHERE T.GENERICATTRIBUTE6 IS NOT NULL
      UNION ALL
      SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      EXTRACT(YEAR FROM V_PERIODSTARTDATE),
                      SUBSTR(V_PERIODNAME, 0, LENGTH(V_PERIODNAME) - 5),
                      SUBSTR('0' || MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 13), -2),
                      T.BUSINESSUNITNAME,
                      --T.POSITIONTITLE,
                      'All' DISTRICT_CODE,
                      ' All District' DISTRICT_CODE_DESC,
                      'All' UNIT_CODE,
                      ' All Unit' UNIT_CODE_DESC,
                      --T.PARTICIPANTID AGENT_CODE,
                      --T.PARTICIPANTID || ' - ' || T.FIRSTNAME || T.MIDDLENAME ||
                      --T.LASTNAME AGENT_CODE_DESC,
                      SYSDATE
        FROM AIA_PAYEE_INFOR T;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_DEPOSIT_TRACE_BACK IS
  BEGIN
    ------All specified deposit trace back
    --DELETE FROM AIA_DEPOSIT_TRACE_INFOR T WHERE T.PERIODSEQ = V_PERIODSEQ;
    EXECUTE IMMEDIATE 'TRUNCATE TABLE AIA_DEPOSIT_TRACE_INFOR';
    --'D_FYC_Non_Initial_Excl_LF_SGD_SG',
    --'D_FYC_Non_Initial_Excl_LF_BND_BN'
    --Measurement Level
    ------Deposit-->Primary Measurement
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       PMEASUREMENTSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       PMEASUREMENTNAME,
       DEPOSITVALUE,
       PMEASUREMENTVALUE,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             DEPM.MEASUREMENTSEQ,
             'Primary Measurement Level',
             DEP.NAME,
             MEAP.NAME,
             DEP.VALUE,
             MEAP.VALUE,
             SYSDATE
        FROM CS_DEPOSIT DEP, CS_DEPOSITPMTRACE DEPM, CS_MEASUREMENT MEAP
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME IN ('D_FYC_Non_Initial_Excl_LF_SGD_SG',
                          'D_FYC_Non_Initial_Excl_LF_BND_BN')
         AND DEP.DEPOSITSEQ = DEPM.DEPOSITSEQ
         AND DEPM.MEASUREMENTSEQ = MEAP.MEASUREMENTSEQ;
  
    --'D_RYC_LF_SGD_SG',--
    --'D_RYC_Excl_LF_SGD_SG',--
    --'D_RYC_LF_BND_BN',
    --'D_RYC_Excl_LF_BND_BN'
    --Credit Level
    ------Deposit-->Primary Measurement-->Credit
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       PMEASUREMENTSEQ,
       CREDITSEQ,
       TRANSACTIONSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       PMEASUREMENTNAME,
       CREDITNAME,
       CREDITTYPE,
       GENERICATTRIBUTE2, ------Reason_Code
       GENERICATTRIBUTE3, ------Business_Line
       GENERICATTRIBUTE4, ------Pay_Year
       DEPOSITVALUE,
       PMEASUREMENTVALUE,
       CREDITVALUE,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             DEPM.MEASUREMENTSEQ,
             CRD.CREDITSEQ,
             CRD.SALESTRANSACTIONSEQ,
             'Credit Level',
             DEP.NAME,
             MEAP.NAME,
             CRD.NAME,
             CDTY.CREDITTYPEID,
             CRD.GENERICATTRIBUTE16, ------Reason_Code
             CRD.GENERICATTRIBUTE2, ------Business_Line
             CRD.GENERICATTRIBUTE4, ------Pay_Year
             DEP.VALUE,
             MEAP.VALUE,
             CRD.VALUE,
             SYSDATE
        FROM CS_DEPOSIT        DEP,
             CS_DEPOSITPMTRACE DEPM,
             CS_MEASUREMENT    MEAP,
             CS_PMCREDITTRACE  CRDT,
             CS_CREDIT         CRD,
             CS_CREDITTYPE     CDTY
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME IN ('D_RYC_LF_SGD_SG',
                          'D_RYC_Excl_LF_SGD_SG',
                          'D_RYC_LF_BND_BN',
                          'D_RYC_Excl_LF_BND_BN')
         AND DEP.DEPOSITSEQ = DEPM.DEPOSITSEQ
         AND DEPM.MEASUREMENTSEQ = CRDT.MEASUREMENTSEQ
         AND CRDT.CREDITSEQ = CRD.CREDITSEQ
         AND DEPM.MEASUREMENTSEQ = MEAP.MEASUREMENTSEQ
         AND CRD.CREDITTYPESEQ = CDTY.DATATYPESEQ
         AND CDTY.REMOVEDATE = C_REMOVEDATE;
    --'D_M_BEFORE_TAX'--
    --'D_Daily_Ad_Hoc_Before_Tax'--
    --Credit Level
    ------Deposit-->Primary Measurement-->Credit
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       --DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       PMEASUREMENTSEQ,
       CREDITSEQ,
       TRANSACTIONSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       PMEASUREMENTNAME,
       CREDITNAME,
       CREDITTYPE,
       GENERICATTRIBUTE2, ------Reason_Code
       GENERICATTRIBUTE3, ------Business_Line
       GENERICATTRIBUTE4, ------Pay_Year
       --DEPOSITVALUE,
       PMEASUREMENTVALUE,
       CREDITVALUE,
       CREATE_DATE)
      SELECT DISTINCT DEP.PERIODSEQ,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      --DEP.DEPOSITSEQ,
                      DEP.POSITIONSEQ,
                      DEP.PAYEESEQ,
                      DEPM.MEASUREMENTSEQ,
                      CRD.CREDITSEQ,
                      CRD.SALESTRANSACTIONSEQ,
                      'Credit Level',
                      DEP.NAME,
                      MEAP.NAME,
                      CRD.NAME,
                      CDTY.CREDITTYPEID,
                      CRD.GENERICATTRIBUTE16, ------Reason_Code
                      CRD.GENERICATTRIBUTE2, ------Business_Line
                      CRD.GENERICATTRIBUTE4, ------Pay_Year
                      --DEP.VALUE,
                      MEAP.VALUE,
                      CRD.VALUE,
                      SYSDATE
        FROM CS_DEPOSIT        DEP,
             CS_DEPOSITPMTRACE DEPM,
             CS_MEASUREMENT    MEAP,
             CS_PMCREDITTRACE  CRDT,
             CS_CREDIT         CRD,
             CS_CREDITTYPE     CDTY
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME IN ('D_M_BEFORE_TAX_SG', 'D_Daily_Ad_Hoc_Before_Tax')
         AND DEP.DEPOSITSEQ = DEPM.DEPOSITSEQ
         AND DEPM.MEASUREMENTSEQ = CRDT.MEASUREMENTSEQ
         AND CRDT.CREDITSEQ = CRD.CREDITSEQ
         AND DEPM.MEASUREMENTSEQ = MEAP.MEASUREMENTSEQ
         AND CRD.CREDITTYPESEQ = CDTY.DATATYPESEQ
         AND CDTY.REMOVEDATE = C_REMOVEDATE;
    --'D_Direct_Override_BN'--
    --'D_Renewal_Override_BN'--
    --'D_Renewal_Override_Probation_BN'--
    --Secondary Measurement Level
    ------Deposit-->Incentive-->Secondary Measurement-- 
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       SMEASUREMENTSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       SMEASUREMENTNAME,
       DEPOSITVALUE,
       SMEASUREMENTVALUE,
       GENERICNUMBER6, --I_DirectRenewal_Override_BN_Rate
       GENERICDATE3, --Probation_BN_Release_Date
       GENERICBOOLEAN1, --Probation_BN_EVER_HELD
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             INCM.MEASUREMENTSEQ,
             'Secondary Measurement Level',
             DEP.NAME,
             MEAS.NAME,
             DEP.VALUE,
             MEAS.VALUE,
             INC.GENERICNUMBER1,
             CASE
               WHEN DEP.NAME = 'D_Renewal_Override_Probation_BN' THEN
                DEP.RELEASEDATE
               ELSE
                NULL
             END,
             CASE
               WHEN DEP.NAME = 'D_Renewal_Override_Probation_BN' THEN
                DEP.ISHELD
               ELSE
                NULL
             END,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_INCENTIVE             INC,
             CS_MEASUREMENT           MEAS
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME IN ('D_Direct_Override_BN',
                          'D_Renewal_Override_BN',
                          'D_Renewal_Override_Probation_BN')
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.INCENTIVESEQ = INC.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAS.MEASUREMENTSEQ
         AND MEAS.NAME IN ('SM_DO_Base_BN',
                           'SM_DO_New_Agent_BN',
                           'SM_DO_Quater_Qualifying_Agent_BN',
                           'SM_RO_CB_Monthly_DIRECT_TEAM_BN',
                           'SM_RO_RYC_LF_DIRECT_TEAM_BN');
    --'D_Direct_Override_BN'--
    --Measurement Level
    ------Deposit-->Incentive-->Primary Measurement-- 
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       SMEASUREMENTSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       PMEASUREMENTNAME,
       DEPOSITVALUE,
       PMEASUREMENTVALUE,
       GENERICNUMBER6, --I_Direct_Override_BN_Rate
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             INCM.MEASUREMENTSEQ,
             'Primary Measurement Level',
             DEP.NAME,
             MEAP.NAME,
             DEP.VALUE,
             MEAP.VALUE,
             INC.GENERICNUMBER1,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_INCENTIVE             INC,
             CS_MEASUREMENT           MEAP
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME = 'D_Direct_Override_BN'
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.INCENTIVESEQ = INC.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAP.MEASUREMENTSEQ
         AND MEAP.NAME = 'PM_DO_QTR_BN'
         AND INC.NAME = 'I_Direct_Override_BN';
    --'D_NLPI_SG'
    --Credit Level
    ------Deposit-->Incentive-->Secondary Measurement-->Primary Measurement-->Credit
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       SMEASUREMENTSEQ,
       PMEASUREMENTSEQ,
       CREDITSEQ,
       TRANSACTIONSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       SMEASUREMENTNAME,
       PMEASUREMENTNAME,
       CREDITNAME,
       GENERICATTRIBUTE1, ------Contribute Agent Code
       GENERICDATE1, ------Commissionable_Agent_Transfer_Date
       GENERICDATE2, ------Commissionable_Agent_Assignment_Date
       GENERICNUMBER1, ------SM_NLPI_Rate
       DEPOSITVALUE,
       SMEASUREMENTVALUE,
       PMEASUREMENTVALUE,
       CREDITVALUE,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             MEAT.TARGETMEASUREMENTSEQ,
             MEAT.SOURCEMEASUREMENTSEQ,
             CRD.CREDITSEQ,
             CRD.SALESTRANSACTIONSEQ,
             'Credit Level',
             DEP.NAME,
             MEAS.NAME,
             MEAP.NAME,
             CRD.NAME,
             CRD.GENERICATTRIBUTE12,
             CRD.GENERICDATE4,
             CRD.GENERICDATE5,
             MEAS.GENERICNUMBER1,
             DEP.VALUE,
             MEAS.VALUE,
             MEAP.VALUE,
             CRD.VALUE,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_PMSELFTRACE           MEAT,
             CS_MEASUREMENT           MEAS,
             CS_MEASUREMENT           MEAP,
             CS_PMCREDITTRACE         CRDT,
             CS_CREDIT                CRD
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME = 'D_NLPI_SG'
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAT.TARGETMEASUREMENTSEQ
         AND MEAT.SOURCEMEASUREMENTSEQ = CRDT.MEASUREMENTSEQ
         AND CRDT.CREDITSEQ = CRD.CREDITSEQ
         AND MEAT.TARGETMEASUREMENTSEQ = MEAS.MEASUREMENTSEQ
         AND MEAT.SOURCEMEASUREMENTSEQ = MEAP.MEASUREMENTSEQ;
  
    --'D_SPI_SG',--
    --Incentive Level
    ------Deposit-->Incentive-->Incentive
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       INCENTIVESEQ,
       TRACELEVEL,
       DEPOSITNAME,
       INCENTIVENAME,
       DEPOSITVALUE,
       INCENTIVEVALUE,
       GENERICNUMBER2,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             INC.INCENTIVESEQ,
             'Incentive Level',
             DEP.NAME,
             INC.NAME,
             DEP.VALUE,
             INC.VALUE,
             INC.GENERICNUMBER1,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVESELFTRACE    INCT,
             CS_INCENTIVE             INC
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME = 'D_SPI_SG'
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCT.TARGETINCENTIVESEQ
         AND INCT.SOURCEINCENTIVESEQ = INC.INCENTIVESEQ
         AND INC.PERIODSEQ = DEP.PERIODSEQ;
    --'D_Direct_Override_BN'
    --Credit Level
    ------Deposit-->Incentive-->Secondary Measurement-->
    ------Secondary Measurement(+)-->Primary Measurement-->Credit
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       SMEASUREMENTSEQ,
       PMEASUREMENTSEQ,
       CREDITSEQ,
       TRANSACTIONSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       SMEASUREMENTNAME,
       PMEASUREMENTNAME,
       CREDITNAME,
       GENERICATTRIBUTE1, ------Contribute Agent Code
       GENERICNUMBER3, ------SM_DO_Base_BN_Rate
       DEPOSITVALUE,
       SMEASUREMENTVALUE,
       PMEASUREMENTVALUE,
       CREDITVALUE,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             MEAT.TARGETMEASUREMENTSEQ,
             MEAT.SOURCEMEASUREMENTSEQ,
             CRD.CREDITSEQ,
             CRD.SALESTRANSACTIONSEQ,
             'Credit Level',
             DEP.NAME,
             MEAS.NAME,
             MEAP.NAME,
             CRD.NAME,
             CRD.GENERICATTRIBUTE12,
             MEAS.GENERICNUMBER1,
             DEP.VALUE,
             MEAS.VALUE,
             MEAP.VALUE,
             CRD.VALUE,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_PMSELFTRACE           MEAT,
             CS_PMSELFTRACE           MEATS,
             CS_MEASUREMENT           MEAS,
             CS_MEASUREMENT           MEAP,
             CS_PMCREDITTRACE         CRDT,
             CS_CREDIT                CRD
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME = 'D_Direct_Override_BN'
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAT.TARGETMEASUREMENTSEQ
         AND MEAT.SOURCEMEASUREMENTSEQ = MEATS.TARGETMEASUREMENTSEQ
         AND MEATS.SOURCEMEASUREMENTSEQ = CRDT.MEASUREMENTSEQ
         AND CRDT.CREDITSEQ = CRD.CREDITSEQ
         AND MEAT.TARGETMEASUREMENTSEQ = MEAS.MEASUREMENTSEQ
         AND MEATS.SOURCEMEASUREMENTSEQ = MEAP.MEASUREMENTSEQ
         AND MEAS.NAME = 'SM_DO_Base_BN';
    --'D_Direct_Override_BN'
    --Credit Level
    ------Deposit-->Incentive-->Secondary Measurement-->Primary Measurement-->Credit
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       SMEASUREMENTSEQ,
       PMEASUREMENTSEQ,
       CREDITSEQ,
       TRANSACTIONSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       SMEASUREMENTNAME,
       PMEASUREMENTNAME,
       CREDITNAME,
       GENERICATTRIBUTE1, ------Contribute Agent Code
       GENERICNUMBER4, ------SM_DO_New_Agent_BN_Rate
       DEPOSITVALUE,
       SMEASUREMENTVALUE,
       PMEASUREMENTVALUE,
       CREDITVALUE,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             MEAT.TARGETMEASUREMENTSEQ,
             MEAT.SOURCEMEASUREMENTSEQ,
             CRD.CREDITSEQ,
             CRD.SALESTRANSACTIONSEQ,
             'Credit Level',
             DEP.NAME,
             MEAS.NAME,
             MEAP.NAME,
             CRD.NAME,
             CRD.GENERICATTRIBUTE12,
             MEAS.GENERICNUMBER1,
             DEP.VALUE,
             MEAS.VALUE,
             MEAP.VALUE,
             CRD.VALUE,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_PMSELFTRACE           MEAT,
             CS_MEASUREMENT           MEAS,
             CS_MEASUREMENT           MEAP,
             CS_PMCREDITTRACE         CRDT,
             CS_CREDIT                CRD
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME = 'D_Direct_Override_BN'
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAT.TARGETMEASUREMENTSEQ
         AND MEAT.SOURCEMEASUREMENTSEQ = CRDT.MEASUREMENTSEQ
         AND CRDT.CREDITSEQ = CRD.CREDITSEQ
         AND MEAT.TARGETMEASUREMENTSEQ = MEAS.MEASUREMENTSEQ
         AND MEAT.SOURCEMEASUREMENTSEQ = MEAP.MEASUREMENTSEQ
         AND MEAS.NAME = 'SM_DO_New_Agent_BN';
  
    --'D_Direct_Override_BN'
    --Credit Level
    ------Deposit-->Incentive-->Primary Measurement-->Credit
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       PMEASUREMENTSEQ,
       CREDITSEQ,
       TRANSACTIONSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       PMEASUREMENTNAME,
       CREDITNAME,
       GENERICATTRIBUTE1, ------Contribute Agent Code
       GENERICNUMBER6, ------I_Direct_Override_BN_Rate
       GENERICBOOLEAN3, ------C_DO_QTR_BN.GB3
       DEPOSITVALUE,
       PMEASUREMENTVALUE,
       CREDITVALUE,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             INCM.MEASUREMENTSEQ,
             CRD.CREDITSEQ,
             CRD.SALESTRANSACTIONSEQ,
             'Credit Level',
             DEP.NAME,
             MEAP.NAME,
             CRD.NAME,
             CRD.GENERICATTRIBUTE12,
             INC.GENERICNUMBER1,
             CRD.GENERICBOOLEAN3,
             DEP.VALUE,
             MEAP.VALUE,
             CRD.VALUE,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_INCENTIVE             INC,
             CS_MEASUREMENT           MEAP,
             CS_PMCREDITTRACE         CRDT,
             CS_CREDIT                CRD
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME = 'D_Direct_Override_BN'
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = CRDT.MEASUREMENTSEQ
         AND CRDT.CREDITSEQ = CRD.CREDITSEQ
         AND INCM.INCENTIVESEQ = INC.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAP.MEASUREMENTSEQ
         AND MEAP.NAME = 'PM_DO_QTR_BN'
         AND INC.NAME = 'I_Direct_Override_BN';
    ------'D_Renewal_Override_BN'
    ------'D_Renewal_Override_Probation_BN'
    --Secondary Measurement Level
    ------Deposit-->Incentive-->Secondary Measurement-->Secondary Measurement(+)
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       SMEASUREMENTSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       SMEASUREMENTNAME,
       DEPOSITVALUE,
       SMEASUREMENTVALUE,
       GENERICATTRIBUTE1, ------Contribute Agent Code
       GENERICNUMBER6, --I_Renewal_Override_BN_Rate
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             INCM.MEASUREMENTSEQ,
             'Secondary2 Measurement Level',
             DEP.NAME,
             MEAS2.NAME,
             DEP.VALUE,
             MEAS2.VALUE,
             API.PARTICIPANTID,
             INC.GENERICNUMBER1,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_PMSELFTRACE           MEAT,
             CS_INCENTIVE             INC,
             CS_MEASUREMENT           MEAS,
             CS_MEASUREMENT           MEAS2,
             AIA_PAYEE_INFOR          API
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME IN
             ('D_Renewal_Override_BN', 'D_Renewal_Override_Probation_BN')
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAT.TARGETMEASUREMENTSEQ
         AND MEAT.SOURCEMEASUREMENTSEQ = MEAS2.MEASUREMENTSEQ
         AND INCM.INCENTIVESEQ = INC.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAS.MEASUREMENTSEQ
         AND MEAS.NAME = 'SM_RO_CB_Monthly_DIRECT_TEAM_BN'
         AND MEAS2.NAME IN
             ('SM_RO_CB_Monthly_FSC_BN', 'SM_RO_CB_Monthly_SUB_MANAGER_BN')
         AND MEAS2.POSITIONSEQ = API.POSITIONSEQ;
    ------'D_Renewal_Override_BN'
    ------'D_Renewal_Override_Probation_BN'
    --Credit Level
    ------Deposit-->Incentive-->Secondary Measurement-->Primary Measurement-->Credit
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       CREDITSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       CREDITNAME,
       DEPOSITVALUE,
       CREDITVALUE,
       GENERICATTRIBUTE1, ------Contribute Agent Code
       GENERICATTRIBUTE5, ------Contribute Unit Code
       GENERICATTRIBUTE6, ------Contribute Class Code
       GENERICNUMBER6, --I_Renewal_Override_BN_Rate
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             CRD.CREDITSEQ,
             'Credit Level',
             DEP.NAME,
             CRD.NAME,
             DEP.VALUE,
             CRD.VALUE,
             CRD.GENERICATTRIBUTE12,
             CRD.GENERICATTRIBUTE13,
             CRD.GENERICATTRIBUTE14,
             INC.GENERICNUMBER1,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_PMSELFTRACE           MEAT,
             CS_PMCREDITTRACE         MEAC,
             CS_INCENTIVE             INC,
             CS_MEASUREMENT           MEAS,
             CS_CREDIT                CRD
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME IN
             ('D_Renewal_Override_BN', 'D_Renewal_Override_Probation_BN')
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAT.TARGETMEASUREMENTSEQ
         AND MEAT.SOURCEMEASUREMENTSEQ = MEAC.MEASUREMENTSEQ
         AND MEAC.CREDITSEQ = CRD.CREDITSEQ
         AND INCM.INCENTIVESEQ = INC.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAS.MEASUREMENTSEQ
         AND MEAS.NAME = 'SM_RO_RYC_LF_DIRECT_TEAM_BN';
  
    ------Modified by Chao 20140814
    ------'D_Renewal_Override_BN'
    ------'D_Renewal_Override_Probation_BN'
    --Credit Level
    ------Deposit-->Incentive-->Secondary Measurement
    -->Secondary Measurement-->Primary Measurement-->Credit
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       CREDITSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       CREDITNAME,
       DEPOSITVALUE,
       CREDITVALUE,
       GENERICATTRIBUTE1, ------Contribute Agent Code
       GENERICATTRIBUTE5, ------Contribute Unit Code
       GENERICATTRIBUTE6, ------Contribute Class Code
       GENERICNUMBER6, --I_Renewal_Override_BN_Rate
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             CRD.CREDITSEQ,
             'Credit Level',
             DEP.NAME,
             CRD.NAME,
             DEP.VALUE,
             CRD.VALUE,
             CRD.GENERICATTRIBUTE12,
             CRD.GENERICATTRIBUTE13,
             CRD.GENERICATTRIBUTE14,
             INC.GENERICNUMBER1,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVEPMTRACE      INCM,
             CS_PMSELFTRACE           MEAT,
             CS_PMSELFTRACE           MEAT2,
             CS_PMCREDITTRACE         MEAC,
             CS_INCENTIVE             INC,
             CS_MEASUREMENT           MEAS,
             CS_CREDIT                CRD
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME IN
             ('D_Renewal_Override_BN', 'D_Renewal_Override_Probation_BN')
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCM.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAT.TARGETMEASUREMENTSEQ
         AND MEAT.SOURCEMEASUREMENTSEQ = MEAT2.TARGETMEASUREMENTSEQ
         AND MEAT2.SOURCEMEASUREMENTSEQ = MEAC.MEASUREMENTSEQ
         AND MEAC.CREDITSEQ = CRD.CREDITSEQ
         AND INCM.INCENTIVESEQ = INC.INCENTIVESEQ
         AND INCM.MEASUREMENTSEQ = MEAS.MEASUREMENTSEQ
         AND MEAS.NAME = 'SM_RO_RYC_LF_DIRECT_TEAM_BN';
    --'D_Indirect_Override_BN',--
    --Incentive Level
    ------Deposit-->Incentive-->Incentive-->Incentive
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       INCENTIVESEQ,
       TRACELEVEL,
       DEPOSITNAME,
       INCENTIVENAME,
       DEPOSITVALUE,
       INCENTIVEVALUE,
       GENERICATTRIBUTE1,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             DEP.POSITIONSEQ,
             DEP.PAYEESEQ,
             INC.INCENTIVESEQ,
             'Incentive Level',
             DEP.NAME,
             INC.NAME,
             DEP.VALUE,
             INC.VALUE,
             INC.PAYEESEQ,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVESELFTRACE    INCT,
             CS_INCENTIVESELFTRACE    INCT2,
             CS_INCENTIVE             INC
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME = 'D_Indirect_Override_BN'
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCT.TARGETINCENTIVESEQ
         AND INCT.SOURCEINCENTIVESEQ = INCT2.TARGETINCENTIVESEQ
         AND INCT2.SOURCEINCENTIVESEQ = INC.INCENTIVESEQ
         AND INC.NAME = 'I_Direct_Override_BN';
    --'D_Indirect_Override_BN',--
    --Measurement Level
    ------Deposit-->Incentive-->Incentive-->Incentive-->Measurement
    INSERT INTO AIA_DEPOSIT_TRACE_INFOR
      (PERIODSEQ,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DEPOSITSEQ,
       POSITIONSEQ,
       PAYEESEQ,
       SMEASUREMENTSEQ,
       TRACELEVEL,
       DEPOSITNAME,
       SMEASUREMENTNAME,
       DEPOSITVALUE,
       SMEASUREMENTVALUE,
       GENERICNUMBER7,
       CREATE_DATE)
      SELECT DEP.PERIODSEQ,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             DEP.DEPOSITSEQ,
             --MEA.POSITIONSEQ,
             --MEA.PAYEESEQ,
             INC.POSITIONSEQ,
             INC.PAYEESEQ,
             MEA.MEASUREMENTSEQ,
             'Measurement Level',
             DEP.NAME,
             MEA.NAME,
             DEP.VALUE,
             MEA.VALUE,
             INC.GENERICNUMBER1,
             SYSDATE
        FROM CS_DEPOSIT               DEP,
             CS_DEPOSITINCENTIVETRACE DEPI,
             CS_INCENTIVESELFTRACE    INCT,
             CS_INCENTIVESELFTRACE    INCT2,
             CS_INCENTIVEPMTRACE      PMT,
             CS_INCENTIVE             INC,
             CS_MEASUREMENT           MEA
       WHERE DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.NAME = 'D_Indirect_Override_BN'
         AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
         AND DEPI.INCENTIVESEQ = INCT.TARGETINCENTIVESEQ
         AND INCT.SOURCEINCENTIVESEQ = INCT2.TARGETINCENTIVESEQ
         AND INCT2.SOURCEINCENTIVESEQ = INC.INCENTIVESEQ
         AND INCT2.SOURCEINCENTIVESEQ = PMT.INCENTIVESEQ
         AND PMT.MEASUREMENTSEQ = MEA.MEASUREMENTSEQ
         AND INC.NAME = 'I_Direct_Override_BN'
         AND MEA.NAME IN
             ('SM_DO_Base_BN', 'SM_DO_New_Agent_BN', 'PM_DO_QTR_BN');
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_BALANCE_DATA IS
  BEGIN
  
    DELETE FROM AIA_HELD_DEPOSIT_BALANCE T WHERE T.PERIODSEQ = V_PERIODSEQ;
    /*INSERT INTO AIA_HELD_DEPOSIT_BALANCE
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       DEPOSITSEQ,
       DEPOSITNAME,
       ISHELD,
       RELEASEDATE,
       EARNINGCODEID,
       EARNINGGROUPID,
       CURRENCY,
       VALUE,
       CREATE_DATE)
    ------Current Month Held Deposit
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             DEP.DEPOSITSEQ,
             DEP.NAME,
             DEP.ISHELD,
             DEP.RELEASEDATE,
             DEP.EARNINGCODEID,
             SUBSTR(DEP.EARNINGGROUPID, 1, 3),
             UNT.NAME,
             DEP.VALUE,
             SYSDATE
        FROM CS_DEPOSIT DEP, CS_UNITTYPE UNT, AIA_PAYEE_INFOR API
       WHERE DEP.UNITTYPEFORVALUE = UNT.UNITTYPESEQ
         AND DEP.POSITIONSEQ = API.POSITIONSEQ
         AND UNT.REMOVEDATE = C_REMOVEDATE
         AND DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.ISHELD = 1
         AND (DEP.RELEASEDATE IS NULL OR DEP.RELEASEDATE > V_PERIODENDDATE)
      UNION ALL
      ------Prior Month Held Deposit
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             AHDB.PARTICIPANTSEQ,
             AHDB.POSITIONSEQ,
             AHDB.EFFECTIVESTARTDATE,
             AHDB.EFFECTIVEENDDATE,
             AHDB.MANAGERSEQ,
             AHDB.POSITIONNAME,
             AHDB.POSITIONTITLE,
             AHDB.DEPOSITSEQ,
             AHDB.DEPOSITNAME,
             AHDB.ISHELD,
             AHDB.RELEASEDATE,
             AHDB.EARNINGCODEID,
             SUBSTR(AHDB.EARNINGGROUPID, 1, 3),
             AHDB.CURRENCY,
             AHDB.VALUE,
             SYSDATE
        FROM AIA_HELD_DEPOSIT_BALANCE AHDB, CS_DEPOSIT DEP
       WHERE AHDB.PERIODSEQ = V_PRIOR_PERIODSEQ
         AND AHDB.DEPOSITSEQ = DEP.DEPOSITSEQ
         AND DEP.ISHELD = 1
         AND (DEP.RELEASEDATE IS NULL OR DEP.RELEASEDATE > V_PERIODENDDATE);
    INSERT INTO AIA_HELD_DEPOSIT_BALANCE
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       BALANCESEQ,
       EARNINGCODEID,
       EARNINGGROUPID,
       CURRENCY,
       VALUE,
       CREATE_DATE)
    ------Current Month Balance
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             BLN.BALANCESEQ,
             BLN.EARNINGCODEID,
             SUBSTR(BLN.EARNINGGROUPID, 1, 3),
             UNT.NAME,
             BLN.VALUE,
             SYSDATE
        FROM CS_BALANCE BLN, AIA_PAYEE_INFOR API, CS_UNITTYPE UNT
       WHERE BLN.PERIODSEQ = V_PERIODSEQ
         AND BLN.UNITTYPEFORVALUE = UNT.UNITTYPESEQ
         AND BLN.POSITIONSEQ = API.POSITIONSEQ
         AND UNT.REMOVEDATE = C_REMOVEDATE;*/
    INSERT INTO AIA_HELD_DEPOSIT_BALANCE
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       EARNINGGROUPID,
       VALUE,
       CREATE_DATE)
    ------Current Month Deposit Minus Payment
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             M.PARTICIPANTSEQ,
             M.POSITIONSEQ,
             M.EFFECTIVESTARTDATE,
             M.EFFECTIVEENDDATE,
             M.MANAGERSEQ,
             M.POSITIONNAME,
             M.POSITIONTITLE,
             M.EARNINGGROUPID,
             DEPOSITVALUE - NVL(PAYMENTVALUE, 0),
             SYSDATE
        FROM (SELECT API.PARTICIPANTSEQ,
                     API.POSITIONSEQ,
                     API.EFFECTIVESTARTDATE,
                     API.EFFECTIVEENDDATE,
                     API.MANAGERSEQ,
                     API.POSITIONNAME,
                     API.POSITIONTITLE,
                     SUBSTR(DEP.EARNINGGROUPID, 1, 3) EARNINGGROUPID,
                     NVL(SUM(DEP.VALUE), 0) DEPOSITVALUE
                FROM CS_DEPOSIT DEP, AIA_PAYEE_INFOR API
               WHERE DEP.PERIODSEQ = V_PERIODSEQ
                 AND DEP.POSITIONSEQ = API.POSITIONSEQ
               GROUP BY API.PARTICIPANTSEQ,
                        API.POSITIONSEQ,
                        API.EFFECTIVESTARTDATE,
                        API.EFFECTIVEENDDATE,
                        API.MANAGERSEQ,
                        API.POSITIONNAME,
                        API.POSITIONTITLE,
                        DEP.EARNINGGROUPID) M,
             (SELECT API.PARTICIPANTSEQ,
                     API.POSITIONSEQ,
                     API.EFFECTIVESTARTDATE,
                     API.EFFECTIVEENDDATE,
                     API.MANAGERSEQ,
                     API.POSITIONNAME,
                     API.POSITIONTITLE,
                     SUBSTR(PMT.EARNINGGROUPID, 1, 3) EARNINGGROUPID,
                     NVL(SUM(PMT.VALUE), 0) PAYMENTVALUE
                FROM CS_PAYMENT PMT, AIA_PAYEE_INFOR API
               WHERE PMT.PERIODSEQ = V_PERIODSEQ
                 AND PMT.POSITIONSEQ = API.POSITIONSEQ
               GROUP BY API.PARTICIPANTSEQ,
                        API.POSITIONSEQ,
                        API.EFFECTIVESTARTDATE,
                        API.EFFECTIVEENDDATE,
                        API.MANAGERSEQ,
                        API.POSITIONNAME,
                        API.POSITIONTITLE,
                        PMT.EARNINGGROUPID) N
       WHERE M.POSITIONSEQ = N.POSITIONSEQ(+);
    --------Add Prior value as Balance
    UPDATE AIA_HELD_DEPOSIT_BALANCE AHDB
       SET AHDB.VALUE       = AHDB.VALUE +
                              NVL((SELECT SUM(T.VALUE)
                                    FROM AIA_HELD_DEPOSIT_BALANCE T
                                   WHERE T.PERIODSEQ = V_PRIOR_PERIODSEQ
                                     AND T.POSITIONSEQ = AHDB.POSITIONSEQ),
                                  0),
           AHDB.UPDATE_DATE = SYSDATE
     WHERE AHDB.PERIODSEQ = V_PERIODSEQ;
    
    --------Added by zhubin for adding the agent who dont have deposit but have balance
    --------set their this month balance 0
    INSERT INTO AIA_HELD_DEPOSIT_BALANCE
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       EARNINGGROUPID,
       VALUE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             AHDB.EARNINGGROUPID,
             AHDB.VALUE,
             SYSDATE
        FROM AIA_HELD_DEPOSIT_BALANCE AHDB, AIA_PAYEE_INFOR API
       WHERE AHDB.POSITIONSEQ = API.POSITIONSEQ
         AND AHDB.PERIODSEQ = V_PRIOR_PERIODSEQ
         AND API.POSITIONSEQ NOT IN
             (SELECT T.POSITIONSEQ
                FROM AIA_HELD_DEPOSIT_BALANCE T
               WHERE T.PERIODSEQ = V_PERIODSEQ);
    --------Added by zhubin 20140810
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_INCOME_SUMMARY_PROC IS
  
  BEGIN
  
    DELETE FROM AIA_INCOME_SUMMARY AIS WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    ------All Agents with last version in current period
    INSERT INTO AIA_INCOME_SUMMARY
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       UNIT_CODE,
       AGENT_NAME,
       AGENCY,
       AGENT_STATUS_CODE,
       AGENT_CODE,
       TERMINATIONDATE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             API.GENERICATTRIBUTE2,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE3,
             API.GENERICATTRIBUTE1,
             API.PARTICIPANTID,
             API.TERMINATIONDATE,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.BUSINESSUNITNAME = 'SGPAGY'
         AND API.POSITIONTITLE NOT IN ('AGENCY', 'DISTRICT')
      /*AND EXISTS (SELECT 1
       FROM CS_DEPOSIT DEP
      WHERE DEP.PERIODSEQ = V_PERIODSEQ
        AND DEP.POSITIONSEQ = API.POSITIONSEQ
        AND DEP.VALUE != 0)*/
      ;
  
    ---------update earnings
    UPDATE AIA_INCOME_SUMMARY AIS
       SET (AIS.FYC_LIFE,
            AIS.SSC,
            AIS.SPI,
            AIS.PA_QUART_PRDCTION_INC,
            AIS.PL_YEAR_END_BONUS,
            AIS.DPI,
            AIS.PL_OVERRIDE,
            AIS.VITALITY_OVERRIDE,
            AIS.CLERICAL_ALLOWANCE,
            AIS.MONTHLY_ALLOWANCE,
            AIS.PRODUCTIVITY_ALLOWANCE,
            AIS.PERSISTENCY_INCENTIVE,
            AIS.PROMOTION_BENEFIT,
            AIS.ADM_SELF_OVERRIDE,
            AIS.NLPI,
            AIS.NADOR,
            AIS.PARIS,
            AIS.ADPI,
            AIS.ADDITIONAL_OVERRIDE,
            AIS.RYC_7_ONWARDS_LIFE) =
           (SELECT NVL(SUM(CASE
                             WHEN DEP.NAME IN ('D_FYC_Initial_LF_SGD_SG',
                                               'D_FYC_Non_Initial_LF_SGD_SG',
                                               'D_API_IFYC_SGD_SG') THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME IN
                                  ('D_SSC_Payable_SGD_SG', 'D_API_SSC_SGD_SG') THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_SPI_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_PA_Production_Bonus_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_PL_Year_End_Bonus' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_DPI_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_PLOR_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_VLOR_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_Clerical_Allowance_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_Monthly_Allowance_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_Productivity_Allowance_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME IN ('D_PI_FSAD_SG', 'D_PI_FSD_SG') THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME IN
                                  ('D_PBA_SG', 'D_PBU_Buyout_SG', 'D_PBU_Monthly_SG') THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_FSAD_Self_Override_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_NLPI_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_NADOR_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_PARIS_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_ADPI_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_AOR_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_APF_Payable_SGD_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_DEPOSIT DEP
             WHERE DEP.PERIODSEQ = AIS.PERIODSEQ
               AND DEP.POSITIONSEQ = AIS.POSITIONSEQ
               AND DEP.NAME IN ('D_FYC_Initial_LF_SGD_SG',
                                'D_FYC_Non_Initial_LF_SGD_SG',
                                'D_API_IFYC_SGD_SG',
                                'D_SSC_Payable_SGD_SG',
                                'D_APF_Payable_SGD_SG',
                                'D_SPI_SG',
                                'D_PA_Production_Bonus_SG',
                                'D_PL_Year_End_Bonus',
                                'D_DPI_SG',
                                'D_PLOR_SG',
                                'D_VLOR_SG',
                                'D_Clerical_Allowance_SG',
                                'D_Monthly_Allowance_SG',
                                'D_Productivity_Allowance_SG',
                                'D_PI_FSAD_SG',
                                'D_PI_FSD_SG',
                                'D_PBA_SG',
                                'D_PBU_Buyout_SG',
                                'D_PBU_Monthly_SG',
                                'D_FSAD_Self_Override_SG',
                                'D_NLPI_SG',
                                'D_NADOR_SG',
                                'D_PARIS_SG',
                                'D_ADPI_SG',
                                'D_AOR_SG',
                                'D_API_SSC_SGD_SG')),
           (AIS.OCMP_X_SELL_INCENTIVE, AIS.OCMP_CVF_INCENTIVE) =
           (SELECT NVL(SUM(CASE
                             WHEN INC.NAME IN
                                  ('I_OPI_Cross_Selling_First_Year_SG',
                                   'I_OPI_Cross_Selling_Renewal_SG') THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INC.NAME IN
                                  ('I_OPI_CVF_First_Year_SG', 'I_OPI_CVF_Renewal_SG') THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_INCENTIVE INC
             WHERE INC.PERIODSEQ = AIS.PERIODSEQ
               AND INC.POSITIONSEQ = AIS.POSITIONSEQ
               AND INC.NAME IN ('I_OPI_Cross_Selling_First_Year_SG',
                                'I_OPI_Cross_Selling_Renewal_SG',
                                'I_OPI_CVF_First_Year_SG',
                                'I_OPI_CVF_Renewal_SG')),
           AIS.UPDATE_DATE = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    UPDATE AIA_INCOME_SUMMARY AIS
       SET (AIS.FYC_PA,
            AIS.FYC_CS,
            AIS.FYC_PL,
            AIS.FYC_VL,
            AIS.RYC_2_6_LIFE,
            AIS.RYC_PA,
            AIS.RYC_CS,
            AIS.RYC_PL,
            AIS.RYC_VL,
            AIS.RYC_7_ONWARDS_LIFE) =
           (SELECT NVL(SUM(CASE
                             WHEN ADTI.PMEASUREMENTNAME = 'PM_FYC_PA' THEN
                              ADTI.PMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.PMEASUREMENTNAME = 'PM_FYC_CS' THEN
                              ADTI.PMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.PMEASUREMENTNAME IN
                                  ('PM_FYC_Non_Initial_PL', 'PM_FYC_Initial_PL') THEN
                              ADTI.PMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.PMEASUREMENTNAME = 'PM_FYC_VL' THEN
                              ADTI.PMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 IN ('LF', 'HS') AND
                                  ADTI.GENERICATTRIBUTE4 IN
                                  ('PAY2', 'PAY3', 'PAY4', 'PAY5', 'PAY6') THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 = 'PA' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 IN ('CS', 'CL') THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 = 'PL' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 = 'VL' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.RYC_7_ONWARDS_LIFE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 IN ('LF', 'HS') AND
                                  ADTI.GENERICATTRIBUTE4 = 'PAY7' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AIS.PERIODSEQ
               AND ADTI.POSITIONSEQ = AIS.POSITIONSEQ
               AND ADTI.DEPOSITNAME IN
                   ('D_FYC_Non_Initial_Excl_LF_SGD_SG',
                    'D_RYC_LF_SGD_SG',
                    'D_RYC_Excl_LF_SGD_SG')),
           UPDATE_DATE = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    /*--AIS.RYC_7_ONWARDS_LIFE */
    UPDATE AIA_INCOME_SUMMARY AIS
       SET AIS.RYC_7_ONWARDS_LIFE = NVL(AIS.RYC_7_ONWARDS_LIFE, 0) +
                                    NVL((SELECT SUM(MEA.VALUE)
                                          FROM CS_MEASUREMENT MEA
                                         WHERE MEA.PERIODSEQ = AIS.PERIODSEQ
                                           AND MEA.POSITIONSEQ = AIS.POSITIONSEQ
                                           AND MEA.NAME = 'PM_APF_Accrual'),
                                        0),
           UPDATE_DATE            = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    ------update Credit with Reason Code
    UPDATE AIA_INCOME_SUMMARY AIS
       SET (AIS.CAREER_BENEFIT, ------
            AIS.SPI,
            AIS.PA_QUART_PRDCTION_INC,
            AIS.PL_YEAR_END_BONUS,
            AIS.DPI,
            AIS.PL_OVERRIDE,
            AIS.VITALITY_OVERRIDE,
            AIS.CLERICAL_ALLOWANCE,
            AIS.MONTHLY_ALLOWANCE,
            AIS.PRODUCTIVITY_ALLOWANCE,
            AIS.PERSISTENCY_INCENTIVE,
            AIS.PROMOTION_BENEFIT,
            AIS.ADM_SELF_OVERRIDE,
            AIS.RENEWAL_INCENTIVE, ------
            AIS.NLPI,
            AIS.NADOR,
            AIS.OCMP_X_SELL_INCENTIVE,
            AIS.OCMP_CVF_INCENTIVE,
            AIS.PARIS,
            AIS.ADPI,
            AIS.PLRIS, ------
            AIS.ADDITIONAL_OVERRIDE,
            AIS.HEALTHSHIELD_1TIME_BONUS, ------
            AIS.HEALTHSHIELD_1TIME_BONUS_OR, ------
            AIS.TRAILER_FEES_AGT, ------
            AIS.TRAILER_FEES_LEADER, ------
            AIS.DISTRIBUTOR_FEES_AGT, ------
            AIS.DISTRIBUTOR_FEES_LEADER, ------
            AIS.INCOME_ADJUSTMENT ------
            ) =
           (SELECT NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 IN
                                  ( /*'20131', '20132'*/ '20127', '20128') THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.SPI, 0) + NVL(SUM(CASE
                                               WHEN ADTI.GENERICATTRIBUTE2 IN
                                                    ( /*'20111', '20112'*/ '20109', '20110') THEN
                                                ADTI.CREDITVALUE
                                               ELSE
                                                0
                                             END),
                                         0),
                   NVL(AIS.PA_QUART_PRDCTION_INC, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20118' --'20113' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.PL_YEAR_END_BONUS, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20132' --'20137'
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.DPI, 0) + NVL(SUM(CASE
                                               WHEN ADTI.GENERICATTRIBUTE2 = '20134' --'20119' 
                                                THEN
                                                ADTI.CREDITVALUE
                                               ELSE
                                                0
                                             END),
                                         0),
                   NVL(AIS.PL_OVERRIDE, 0) + NVL(SUM(CASE
                                                       WHEN ADTI.GENERICATTRIBUTE2 = '20117' --'20120' 
                                                        THEN
                                                        ADTI.CREDITVALUE
                                                       ELSE
                                                        0
                                                     END),
                                                 0),
                   NVL(AIS.VITALITY_OVERRIDE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20138' --'20142' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.CLERICAL_ALLOWANCE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 IN ('20123', '20133') --= '20127'
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.MONTHLY_ALLOWANCE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20121' --'20125' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.PRODUCTIVITY_ALLOWANCE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20122' --'20126'
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.PERSISTENCY_INCENTIVE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20129' --'20133' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.PROMOTION_BENEFIT, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 IN
                                  ( /*'20123', '20124'*/ '20119', '20120') THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.ADM_SELF_OVERRIDE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20130' --'20134' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20126' --'20130' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.NLPI, 0) + NVL(SUM(CASE
                                                WHEN ADTI.GENERICATTRIBUTE2 = '20115' --'20118' 
                                                 THEN
                                                 ADTI.CREDITVALUE
                                                ELSE
                                                 0
                                              END),
                                          0),
                   NVL(AIS.NADOR, 0) + NVL(SUM(CASE
                                                 WHEN ADTI.GENERICATTRIBUTE2 = '20107' --'20108' 
                                                  THEN
                                                  ADTI.CREDITVALUE
                                                 ELSE
                                                  0
                                               END),
                                           0),
                   ------reason code is null
                   --AIS.OCMP_X_SELL_INCENTIVE
                   NVL(AIS.OCMP_X_SELL_INCENTIVE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20124' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   ------reason code is null
                   --AIS.OCMP_CVF_INCENTIVE
                   NVL(AIS.OCMP_CVF_INCENTIVE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20125' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.PARIS, 0) + NVL(SUM(CASE
                                                 WHEN ADTI.GENERICATTRIBUTE2 = '20106' THEN
                                                  ADTI.CREDITVALUE
                                                 ELSE
                                                  0
                                               END),
                                           0),
                   NVL(AIS.ADPI, 0) + NVL(SUM(CASE
                                                WHEN ADTI.GENERICATTRIBUTE2 = '20131' --'20135' 
                                                 THEN
                                                 ADTI.CREDITVALUE
                                                ELSE
                                                 0
                                              END),
                                          0),
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20139' --'20136' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(AIS.ADDITIONAL_OVERRIDE, 0) +
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20108' --'20110' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20113' --'20116'
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20114' --'20117'
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20111' --'20114'
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20112' --'20115' 
                              THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20101' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   ------reason code is null
                   --AIS.DISTRIBUTOR_FEES_LEADER
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 = '20140' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.GENERICATTRIBUTE2 NOT IN
                                  ('20127',
                                   '20128',
                                   '20109',
                                   '20110',
                                   '20118',
                                   '20132',
                                   '20134',
                                   '20117',
                                   '20138',
                                   '20123',
                                   '20133',
                                   '20121',
                                   '20122',
                                   '20129',
                                   '20119',
                                   '20120',
                                   '20130',
                                   '20126',
                                   '20115',
                                   '20107',
                                   '20124',
                                   '20125',
                                   '20106',
                                   '20131',
                                   '20139',
                                   '20108',
                                   '20113',
                                   '20114',
                                   '20111',
                                   '20112',
                                   '20101',
                                   '20140'
                                   /*'20101',
                                   '20106',
                                   '20108',
                                   '20108',
                                   '20110',
                                   '20111',
                                   '20112',
                                   '20113',
                                   '20114',
                                   '20115',
                                   '20117',
                                   '20118',
                                   '20119',
                                   '20123',
                                   '20124',
                                   '20125',
                                   '20126',
                                   '20127',
                                   '20130',
                                   '20131',
                                   '20132',
                                   '20133',
                                   '20134',
                                   '20135',
                                   '20136',
                                   '20137',
                                   '20142',
                                   '20120'*/) THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AIS.PERIODSEQ
               AND ADTI.POSITIONSEQ = AIS.POSITIONSEQ
               AND ((ADTI.DEPOSITNAME = 'D_M_BEFORE_TAX_SG' AND
                   ADTI.CREDITNAME = 'C_M_BEFORE_TAX') OR
                   (ADTI.DEPOSITNAME = 'D_Daily_Ad_Hoc_Before_Tax' AND
                   ADTI.CREDITNAME = 'C_Daily_Ad_Hoc_Before_Tax'))),
           UPDATE_DATE = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
  
    ---------update total earnings
    UPDATE AIA_INCOME_SUMMARY AIS
       SET AIS.TOTAL_INCOME = NVL(AIS.FYC_LIFE, 0) + NVL(AIS.FYC_PA, 0) +
                              NVL(AIS.FYC_CS, 0) + NVL(AIS.FYC_PL, 0) +
                              NVL(AIS.FYC_VL, 0) + NVL(AIS.SSC, 0) +
                              NVL(AIS.RYC_2_6_LIFE, 0) + NVL(AIS.RYC_PA, 0) +
                              NVL(AIS.RYC_CS, 0) + NVL(AIS.RYC_PL, 0) +
                              NVL(AIS.RYC_VL, 0) +
                              NVL(AIS.RYC_7_ONWARDS_LIFE, 0) +
                              NVL(AIS.INCOME_ADJUSTMENT, 0) +
                              NVL(AIS.CAREER_BENEFIT, 0) + NVL(AIS.SPI, 0) +
                              NVL(AIS.PA_QUART_PRDCTION_INC, 0) +
                              NVL(AIS.PL_YEAR_END_BONUS, 0) + NVL(AIS.DPI, 0) +
                              NVL(AIS.PL_OVERRIDE, 0) +
                              NVL(AIS.VITALITY_OVERRIDE, 0) +
                              NVL(AIS.CLERICAL_ALLOWANCE, 0) +
                              NVL(AIS.MONTHLY_ALLOWANCE, 0) +
                              NVL(AIS.PRODUCTIVITY_ALLOWANCE, 0) +
                              NVL(AIS.PERSISTENCY_INCENTIVE, 0) +
                              NVL(AIS.PROMOTION_BENEFIT, 0) +
                              NVL(AIS.ADM_SELF_OVERRIDE, 0) +
                              NVL(AIS.RENEWAL_INCENTIVE, 0) + NVL(AIS.NLPI, 0) +
                              NVL(AIS.NADOR, 0) +
                              NVL(AIS.OCMP_X_SELL_INCENTIVE, 0) +
                              NVL(AIS.OCMP_CVF_INCENTIVE, 0) + NVL(AIS.PARIS, 0) +
                              NVL(AIS.ADPI, 0) + NVL(AIS.PLRIS, 0) +
                              NVL(AIS.ADDITIONAL_OVERRIDE, 0) +
                              NVL(AIS.HEALTHSHIELD_1TIME_BONUS, 0) +
                              NVL(AIS.HEALTHSHIELD_1TIME_BONUS_OR, 0) +
                              NVL(AIS.TRAILER_FEES_AGT, 0) +
                              NVL(AIS.TRAILER_FEES_LEADER, 0) +
                              NVL(AIS.DISTRIBUTOR_FEES_AGT, 0) +
                              NVL(AIS.DISTRIBUTOR_FEES_LEADER, 0),
           AIS.UPDATE_DATE  = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_INCOME_SUMMARY_BRUNEI_PROC IS
  
  BEGIN
  
    DELETE FROM AIA_INCOME_SUMMARY_BRUNEI AIS
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    ------All Agents with last version in current period
    INSERT INTO AIA_INCOME_SUMMARY_BRUNEI
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       UNIT_CODE,
       AGENT_NAME,
       AGENCY,
       AGENT_STATUS_CODE,
       AGENT_CODE,
       TERMINATIONDATE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             API.GENERICATTRIBUTE2,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE3,
             API.GENERICATTRIBUTE1,
             API.PARTICIPANTID,
             API.TERMINATIONDATE,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.BUSINESSUNITNAME = 'BRUAGY'
      /*AND EXISTS (SELECT 1
       FROM CS_DEPOSIT DEP
      WHERE DEP.PERIODSEQ = V_PERIODSEQ
        AND DEP.POSITIONSEQ = API.POSITIONSEQ
        AND DEP.VALUE != 0)*/
      ;
  
    ---------update earnings
    UPDATE AIA_INCOME_SUMMARY_BRUNEI AIS
       SET (AIS.FYC_LIFE,
            AIS.INDIRECT_OVERRIDE,
            AIS.CAREER_BENEFIT,
            AIS.NEW_AGENT_BONUS) =
           (SELECT NVL(SUM(CASE
                             WHEN DEP.NAME IN ('D_FYC_Initial_LF_BND_BN',
                                               'D_FYC_Non_Initial_LF_BND_BN',
                                               'D_APB_BN') THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_Indirect_Override_BN' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_Career_Benefit_BN' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_New_Agent_Bonus_BN' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_DEPOSIT DEP
             WHERE DEP.PERIODSEQ = AIS.PERIODSEQ
               AND DEP.POSITIONSEQ = AIS.POSITIONSEQ
               AND DEP.NAME IN ('D_FYC_Initial_LF_BND_BN',
                                'D_FYC_Non_Initial_LF_BND_BN',
                                'D_APB_BN',
                                'D_Indirect_Override_BN',
                                'D_Career_Benefit_BN',
                                'D_New_Agent_Bonus_BN')),
           
           (AIS.OCMP_X_SELL_INCENTIVE,
            AIS.OCMP_CVF_INCENTIVE,
            AIS.QTRLY_LIFE_BONUS,
            AIS.QTRLY_RIDER_BONUS) =
           (SELECT NVL(SUM(CASE
                             WHEN INC.NAME IN
                                  ('I_OPI_Cross_Selling_First_Year_BN',
                                   'I_OPI_Cross_Selling_Renewal_BN') THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INC.NAME IN
                                  ('I_OPI_CVF_First_Year_BN', 'I_OPI_CVF_Renewal_BN') THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INC.NAME = 'I_QPB_BN' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INC.NAME = 'I_QPB_Rider' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_INCENTIVE INC
             WHERE INC.PERIODSEQ = AIS.PERIODSEQ
               AND INC.POSITIONSEQ = AIS.POSITIONSEQ
               AND INC.NAME IN ('I_OPI_Cross_Selling_First_Year_BN',
                                'I_OPI_Cross_Selling_Renewal_BN',
                                'I_OPI_CVF_First_Year_BN',
                                'I_OPI_CVF_Renewal_BN',
                                'I_QPB_BN',
                                'I_QPB_Rider')),
           AIS.UPDATE_DATE = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    UPDATE AIA_INCOME_SUMMARY_BRUNEI AIS
       SET (AIS.FYC_PA,
            AIS.FYC_CS,
            AIS.RYC_2_6_LIFE,
            AIS.RYC_PA,
            AIS.RYC_CS,
            AIS.RYC_7_ONWARDS_LIFE) =
           (SELECT NVL(SUM(CASE
                             WHEN ADTI.PMEASUREMENTNAME = 'PM_FYC_PA' THEN
                              ADTI.PMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.PMEASUREMENTNAME = 'PM_FYC_CS' THEN
                              ADTI.PMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 IN ('LF', 'HS') AND
                                  ADTI.GENERICATTRIBUTE4 IN
                                  ('PAY2', 'PAY3', 'PAY4', 'PAY5', 'PAY6') THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 = 'PA' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 IN ('CS', 'CL') THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.CREDITTYPE = 'RYC' AND
                                  ADTI.GENERICATTRIBUTE3 IN ('LF', 'HS') AND
                                  ADTI.GENERICATTRIBUTE4 = 'PAY7' THEN
                              ADTI.CREDITVALUE
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AIS.PERIODSEQ
               AND ADTI.POSITIONSEQ = AIS.POSITIONSEQ
               AND ADTI.DEPOSITNAME IN
                   ('D_FYC_Non_Initial_Excl_LF_BND_BN',
                    'D_RYC_LF_BND_BN',
                    'D_RYC_Excl_LF_BND_BN')),
           UPDATE_DATE = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    ------Update Override
    UPDATE AIA_INCOME_SUMMARY_BRUNEI AIS
       SET (AIS.DIRECT_OVERRIDE,
            AIS.DIRECT_OVERRIDE_NEW_AGT,
            AIS.DIRECT_OVERRIDE_1250,
            AIS.RENEWAL_OVERRIDE_ON_CAREER,
            AIS.RENEWAL_OVERRIDE_ON_RYC,
            AIS.EVER_HELD,
            AIS.PROBATION_RELEASE_DATE,
            AIS.PROBATION_RO_CB_MONTHLY,
            AIS.PROBATION_RO_RYC_LF) =
           (SELECT NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Direct_Override_BN' AND
                                  ADTI.SMEASUREMENTNAME = 'SM_DO_Base_BN' THEN
                              ADTI.SMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Direct_Override_BN' AND
                                  ADTI.SMEASUREMENTNAME = 'SM_DO_New_Agent_BN' THEN
                              ADTI.SMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Direct_Override_BN' AND
                                  ADTI.PMEASUREMENTNAME = 'GENERICNUMBER6' THEN
                              ADTI.PMEASUREMENTVALUE * NVL(ADTI.GENERICNUMBER6, 0)
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Renewal_Override_BN' AND
                                  ADTI.SMEASUREMENTNAME =
                                  'SM_RO_CB_Monthly_DIRECT_TEAM_BN' THEN
                              ADTI.SMEASUREMENTVALUE * NVL(ADTI.GENERICNUMBER6, 0)
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Renewal_Override_BN' AND
                                  ADTI.SMEASUREMENTNAME = 'SM_RO_RYC_LF_DIRECT_TEAM_BN' THEN
                              ADTI.SMEASUREMENTVALUE * NVL(ADTI.GENERICNUMBER6, 0)
                             ELSE
                              0
                           END),
                       0),
                   MAX(CASE
                         WHEN ADTI.DEPOSITNAME = 'D_Renewal_Override_Probation_BN' THEN
                          ADTI.GENERICBOOLEAN1 --ever held
                         ELSE
                          NULL
                       END),
                   
                   MAX(CASE
                         WHEN ADTI.DEPOSITNAME = 'D_Renewal_Override_Probation_BN' THEN
                          ADTI.GENERICDATE3 --release date
                         ELSE
                          NULL
                       END),
                   
                   NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Renewal_Override_Probation_BN' AND
                                  ADTI.SMEASUREMENTNAME =
                                  'SM_RO_CB_Monthly_DIRECT_TEAM_BN' THEN
                              ADTI.SMEASUREMENTVALUE * NVL(ADTI.GENERICNUMBER6, 0)
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Renewal_Override_Probation_BN' AND
                                  ADTI.SMEASUREMENTNAME = 'SM_RO_RYC_LF_DIRECT_TEAM_BN' THEN
                              ADTI.SMEASUREMENTVALUE * NVL(ADTI.GENERICNUMBER6, 0)
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AIS.PERIODSEQ
               AND ADTI.POSITIONSEQ = AIS.POSITIONSEQ
               AND ADTI.DEPOSITNAME IN
                   ('D_Direct_Override_BN',
                    'D_Renewal_Override_BN',
                    'D_Renewal_Override_Probation_BN')
               AND ADTI.TRACELEVEL LIKE '%Measurement Level'),
           AIS.UPDATE_DATE = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    ------update Credit with Reason Code
    UPDATE AIA_INCOME_SUMMARY_BRUNEI AIS
       SET (AIS.DIRECT_OVERRIDE_ADJUSTMENT, --
            AIS.INDIRECT_OVERRIDE, --
            AIS.RENEWAL_OVERRIDE_ADJUSTMENT,
            AIS.QTRLY_BONUS_ADJUSTMENT,
            AIS.CAREER_BENEFIT,
            AIS.NEW_AGENT_BONUS,
            AIS.OCMP_X_SELL_INCENTIVE,
            AIS.OCMP_CVF_INCENTIVE,
            AIS.INCOME_ADJUSTMENT) =
           (SELECT --direct_override_adjustment 
             NVL(SUM(CASE
                       WHEN ADTI.GENERICATTRIBUTE2 = '40108' THEN
                        ADTI.CREDITVALUE
                       ELSE
                        0
                     END),
                 0),
             --income_adjustment  
             NVL(AIS.INDIRECT_OVERRIDE, 0) +
             NVL(SUM(CASE
                       WHEN ADTI.GENERICATTRIBUTE2 = '40110' THEN
                        ADTI.CREDITVALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN ADTI.GENERICATTRIBUTE2 = '40107' THEN
                        ADTI.CREDITVALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN ADTI.GENERICATTRIBUTE2 = '40109' THEN
                        ADTI.CREDITVALUE
                       ELSE
                        0
                     END),
                 0),
             
             NVL(AIS.CAREER_BENEFIT, 0) + NVL(SUM(CASE
                                                    WHEN ADTI.GENERICATTRIBUTE2 IN ('40102', '40103') THEN
                                                     ADTI.CREDITVALUE
                                                    ELSE
                                                     0
                                                  END),
                                              0),
             
             NVL(AIS.NEW_AGENT_BONUS, 0) + NVL(SUM(CASE
                                                     WHEN ADTI.GENERICATTRIBUTE2 = '40106' THEN
                                                      ADTI.CREDITVALUE
                                                     ELSE
                                                      0
                                                   END),
                                               0),
             --Ocmp_x_Sell_Incentive                 
             NVL(AIS.OCMP_X_SELL_INCENTIVE, 0) +
             NVL(SUM(CASE
                       WHEN ADTI.GENERICATTRIBUTE2 = '40111' THEN
                        ADTI.CREDITVALUE
                       ELSE
                        0
                     END),
                 0),
             --Ocmp_Cvf_Incentive                        
             NVL(AIS.OCMP_CVF_INCENTIVE, 0) +
             NVL(SUM(CASE
                       WHEN ADTI.GENERICATTRIBUTE2 = '40112' THEN
                        ADTI.CREDITVALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN ADTI.GENERICATTRIBUTE2 NOT IN
                            ('40108',
                             '40110',
                             '40102',
                             '40103',
                             '40106',
                             '40107',
                             '40109',
                             '40111',
                             '40112') THEN
                        ADTI.CREDITVALUE
                       ELSE
                        0
                     END),
                 0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AIS.PERIODSEQ
               AND ADTI.POSITIONSEQ = AIS.POSITIONSEQ
               AND ((ADTI.DEPOSITNAME = 'D_M_BEFORE_TAX_SG' AND
                   ADTI.CREDITNAME = 'C_M_BEFORE_TAX') OR
                   (ADTI.DEPOSITNAME = 'D_Daily_Ad_Hoc_Before_Tax' AND
                   ADTI.CREDITNAME = 'C_Daily_Ad_Hoc_Before_Tax'))),
           UPDATE_DATE = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
  
    ---------update total earnings
    UPDATE AIA_INCOME_SUMMARY_BRUNEI AIS
       SET AIS.TOTAL_INCOME = NVL(AIS.FYC_LIFE, 0) + NVL(AIS.FYC_PA, 0) +
                              NVL(AIS.FYC_CS, 0) + NVL(AIS.RYC_2_6_LIFE, 0) +
                              NVL(AIS.RYC_PA, 0) + NVL(AIS.RYC_CS, 0) +
                              NVL(AIS.RYC_7_ONWARDS_LIFE, 0) +
                              NVL(AIS.INCOME_ADJUSTMENT, 0) +
                              NVL(AIS.DIRECT_OVERRIDE, 0) +
                              NVL(AIS.DIRECT_OVERRIDE_NEW_AGT, 0) +
                              NVL(AIS.DIRECT_OVERRIDE_1250, 0) +
                              NVL(AIS.DIRECT_OVERRIDE_ADJUSTMENT, 0) +
                              NVL(AIS.INDIRECT_OVERRIDE, 0) +
                              NVL(AIS.RENEWAL_OVERRIDE_ON_CAREER, 0) +
                              NVL(AIS.RENEWAL_OVERRIDE_ON_RYC, 0) +
                              NVL(AIS.PROBATION_RO_RYC_LF, 0) +
                              NVL(AIS.RENEWAL_OVERRIDE_ADJUSTMENT, 0) +
                              NVL(AIS.QTRLY_LIFE_BONUS, 0) +
                              NVL(AIS.QTRLY_RIDER_BONUS, 0) +
                              NVL(AIS.QTRLY_BONUS_ADJUSTMENT, 0) +
                              NVL(AIS.CAREER_BENEFIT, 0) +
                              NVL(AIS.NEW_AGENT_BONUS, 0) +
                              NVL(AIS.OCMP_X_SELL_INCENTIVE, 0) +
                              NVL(AIS.OCMP_CVF_INCENTIVE, 0),
           AIS.UPDATE_DATE  = SYSDATE
     WHERE AIS.PERIODSEQ = V_PERIODSEQ;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_NLPI_PROC IS
  
  BEGIN
  
    DELETE FROM AIA_NLPI_LEADER ANL WHERE ANL.PERIODSEQ = V_PERIODSEQ;
    DELETE FROM AIA_NLPI_AGENT ANA WHERE ANA.PERIODSEQ = V_PERIODSEQ;
    ------All Leader Agents with last version in current period
    INSERT INTO AIA_NLPI_LEADER
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       UNIT_CODE,
       AGENCY,
       LEADER_NAME,
       LEADER_PROMOTION_DATE,
       LEADER_DEMOTION_DATE,
       EXCEPTION_START_DATE,
       EXCEPTION_END_DATE,
       LEADER_CODE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             API.GENERICATTRIBUTE2,
             API.GENERICATTRIBUTE3,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICDATE1,
             API.GENERICDATE2,
             DECODE(API.GENERICBOOLEAN1, 1, API.GENERICDATE3),
             DECODE(API.GENERICBOOLEAN1, 1, API.GENERICDATE4),
             API.PARTICIPANTID,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.POSITIONTITLE = 'FSM'
         AND API.BUSINESSUNITNAME = 'SGPAGY'
         AND EXISTS (SELECT 1
                FROM CS_DEPOSIT DEP
               WHERE DEP.PERIODSEQ = V_PERIODSEQ
                 AND DEP.POSITIONSEQ = API.POSITIONSEQ
                 AND DEP.NAME = 'D_NLPI_SG'
                 AND DEP.VALUE != 0);
    ------update NLPI_PAYMENTS_NUMBER data
    UPDATE AIA_NLPI_LEADER ANL
       SET ANL.NLPI_PAYMENTS_NUMBER =
           (SELECT MEA.VALUE
              FROM CS_MEASUREMENT MEA
             WHERE MEA.NAME = 'SM_NLPI_Paid_Mths'
               AND MEA.POSITIONSEQ = ANL.POSITIONSEQ
               AND MEA.PERIODSEQ = ANL.PERIODSEQ
               AND ROWNUM = 1),
           UPDATE_DATE              = SYSDATE
     WHERE ANL.PERIODSEQ = V_PERIODSEQ;
    COMMIT;
    ------Insert Contribute Agents' Records
    INSERT INTO AIA_NLPI_AGENT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       MANAGERSEQ,
       UNIT_CODE,
       AGENCY,
       LEADER_CODE,
       LEADER_NAME,
       LEADER_PROMOTION_DATE,
       LEADER_DEMOTION_DATE,
       NLPI_PAYMENTS_NUMBER,
       EXCEPTION_START_DATE,
       EXCEPTION_END_DATE,
       ------Contribute Agent
       CONTRIBUTING_AGENT_CODE,
       TRANSFERRED_ASSIGNED_DATE,
       TRANSFERRED_ASSIGNED_STAR_FSC,
       PIB_CURR_MTH,
       CALCULATED_NLPI_CURR_MTH,
       PAY_NLPI_YES_NO,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             ANL.POSITIONSEQ, --MANAGERSEQ
             ANL.UNIT_CODE,
             ANL.AGENCY,
             ANL.LEADER_CODE,
             ANL.LEADER_NAME,
             ANL.LEADER_PROMOTION_DATE,
             ANL.LEADER_DEMOTION_DATE,
             ANL.NLPI_PAYMENTS_NUMBER,
             ANL.EXCEPTION_START_DATE,
             ANL.EXCEPTION_END_DATE,
             ------Contribute Agent
             ADTI.GENERICATTRIBUTE1,
             MAX(CASE
                   WHEN ADTI.PMEASUREMENTNAME = 'PM_NLPI_PIB_Exclusion' THEN
                    CASE
                      WHEN ADTI.GENERICDATE1 IS NULL THEN
                       ADTI.GENERICDATE2
                      WHEN ADTI.GENERICDATE2 IS NULL THEN
                       ADTI.GENERICDATE1
                      ELSE
                       GREATEST(ADTI.GENERICDATE1, ADTI.GENERICDATE2)
                    END
                   ELSE
                    NULL
                 END),
             MAX(CASE
                   WHEN ADTI.PMEASUREMENTNAME = 'PM_NLPI_PIB_Exclusion' THEN
                    'YES'
                   ELSE
                    'NO'
                 END),
             SUM((CASE
                   WHEN ADTI.PMEASUREMENTNAME = 'PM_NLPI_PIB_Exclusion' THEN
                    0
                   ELSE
                    ADTI.CREDITVALUE
                 END)),
             SUM(CASE
                   WHEN ADTI.SMEASUREMENTNAME = 'SM_NLPI' THEN
                    (CASE
                      WHEN ADTI.PMEASUREMENTNAME = 'PM_NLPI_PIB_Exclusion' THEN
                       0
                      ELSE
                       ADTI.CREDITVALUE
                    END) * NVL(ADTI.GENERICNUMBER1, 0)
                   ELSE
                    0
                 END),
             MIN(CASE
                   WHEN ADTI.PMEASUREMENTNAME = 'PM_NLPI_PIB_Exclusion' THEN
                    'NO'
                   ELSE
                    'YES'
                 END),
             SYSDATE
        FROM AIA_NLPI_LEADER ANL, AIA_DEPOSIT_TRACE_INFOR ADTI
       WHERE ANL.POSITIONSEQ = ADTI.POSITIONSEQ
         AND ANL.PERIODSEQ = ADTI.PERIODSEQ
         AND ADTI.DEPOSITNAME = 'D_NLPI_SG'
         AND ADTI.TRACELEVEL = 'Credit Level'
         AND ANL.PERIODSEQ = V_PERIODSEQ
       GROUP BY ANL.POSITIONSEQ,
                ANL.UNIT_CODE,
                ANL.AGENCY,
                ANL.LEADER_CODE,
                ANL.LEADER_NAME,
                ANL.LEADER_PROMOTION_DATE,
                ANL.LEADER_DEMOTION_DATE,
                ANL.NLPI_PAYMENTS_NUMBER,
                ANL.EXCEPTION_START_DATE,
                ANL.EXCEPTION_END_DATE,
                ------Contribute Agent
                ADTI.GENERICATTRIBUTE1;
    ------Update contribute agent information
    UPDATE AIA_NLPI_AGENT ANA
       SET (ANA.PARTICIPANTSEQ,
            ANA.POSITIONSEQ,
            ANA.EFFECTIVESTARTDATE,
            ANA.EFFECTIVEENDDATE,
            ANA.POSITIONNAME,
            ANA.POSITIONTITLE,
            ANA.CONTRIBUTING_AGENT_NAME,
            ANA.CONTRACT_DATE,
            ANA.CLASS_CODE,
            ANA.RANK,
            ANA.TERMINATION_DATE,
            UPDATE_DATE) =
           (SELECT API.PARTICIPANTSEQ,
                   API.POSITIONSEQ,
                   API.EFFECTIVESTARTDATE,
                   API.EFFECTIVEENDDATE,
                   API.POSITIONNAME,
                   API.POSITIONTITLE,
                   API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                   API.HIREDATE,
                   API.GENERICATTRIBUTE8, --Class Code
                   API.POSITIONTITLE,
                   API.TERMINATIONDATE,
                   SYSDATE
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = ANA.CONTRIBUTING_AGENT_CODE
               AND API.EFFECTIVESTARTDATE < V_PERIODENDDATE
               AND API.EFFECTIVEENDDATE > V_PERIODSTARTDATE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND API.POSITIONNAME LIKE '%T%'
               AND ROWNUM = 1)
     WHERE ANA.PERIODSEQ = V_PERIODSEQ;
  
    COMMIT;
    ------Insert Last Period YTD records
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) > 0 THEN
      ------Update contribute agent YTD value
      UPDATE AIA_NLPI_AGENT ANA
         SET (ANA.PIB_YTD, ANA.CALCULATED_NLPI_YTD) =
             (SELECT NVL(SUM(T.PIB_YTD), 0) + ANA.PIB_CURR_MTH,
                     NVL(SUM(T.CALCULATED_NLPI_YTD), 0) +
                     ANA.CALCULATED_NLPI_CURR_MTH
                FROM AIA_NLPI_AGENT T
               WHERE T.PERIODSEQ = V_PRIOR_PERIODSEQ
                 AND T.UNIT_CODE = ANA.UNIT_CODE
                 AND T.CONTRIBUTING_AGENT_CODE = ANA.CONTRIBUTING_AGENT_CODE),
             UPDATE_DATE = SYSDATE
       WHERE ANA.PERIODSEQ = V_PERIODSEQ;
      INSERT INTO AIA_NLPI_AGENT
        (PERIODSEQ,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         PARTICIPANTSEQ,
         POSITIONSEQ,
         EFFECTIVESTARTDATE,
         EFFECTIVEENDDATE,
         MANAGERSEQ,
         POSITIONNAME,
         POSITIONTITLE,
         UNIT_CODE,
         AGENCY,
         LEADER_CODE,
         LEADER_NAME,
         LEADER_PROMOTION_DATE,
         LEADER_DEMOTION_DATE,
         NLPI_PAYMENTS_NUMBER,
         CONTRIBUTING_AGENT_CODE,
         CONTRIBUTING_AGENT_NAME,
         CONTRACT_DATE,
         TRANSFERRED_ASSIGNED_DATE,
         CLASS_CODE,
         RANK,
         TRANSFERRED_ASSIGNED_STAR_FSC,
         TERMINATION_DATE,
         PIB_CURR_MTH,
         PIB_YTD,
         CALCULATED_NLPI_CURR_MTH,
         CALCULATED_NLPI_YTD,
         PAY_NLPI_YES_NO,
         NLPI_PAYMENT_CURR_MTH,
         NLPI_PAYMENT_YTD,
         EXCEPTION_START_DATE,
         EXCEPTION_END_DATE,
         CREATE_DATE)
        SELECT V_PERIODSEQ,
               V_CALENDARNAME,
               V_PERIODNAME,
               V_PERIODSTARTDATE,
               V_PERIODENDDATE,
               T.PARTICIPANTSEQ,
               T.POSITIONSEQ,
               T.EFFECTIVESTARTDATE,
               T.EFFECTIVEENDDATE,
               T.MANAGERSEQ,
               T.POSITIONNAME,
               T.POSITIONTITLE,
               T.UNIT_CODE,
               T.AGENCY,
               T.LEADER_CODE,
               T.LEADER_NAME,
               T.LEADER_PROMOTION_DATE,
               T.LEADER_DEMOTION_DATE,
               T.NLPI_PAYMENTS_NUMBER,
               T.CONTRIBUTING_AGENT_CODE,
               T.CONTRIBUTING_AGENT_NAME,
               T.CONTRACT_DATE,
               T.TRANSFERRED_ASSIGNED_DATE,
               T.CLASS_CODE,
               T.RANK,
               T.TRANSFERRED_ASSIGNED_STAR_FSC,
               T.TERMINATION_DATE,
               0,
               T.PIB_YTD,
               0,
               T.CALCULATED_NLPI_YTD,
               T.PAY_NLPI_YES_NO,
               0,
               T.NLPI_PAYMENT_YTD,
               T.EXCEPTION_START_DATE,
               T.EXCEPTION_END_DATE,
               SYSDATE
          FROM AIA_NLPI_AGENT T
         WHERE T.PERIODSEQ = V_PRIOR_PERIODSEQ
           AND NOT EXISTS
         (SELECT 1
                  FROM AIA_NLPI_AGENT ANA
                 WHERE ANA.PERIODSEQ = V_PERIODSEQ
                   AND ANA.UNIT_CODE = T.UNIT_CODE
                   AND ANA.CONTRIBUTING_AGENT_CODE = T.CONTRIBUTING_AGENT_CODE);
    ELSE
      ------Update contribute agent YTD value
      UPDATE AIA_NLPI_AGENT ANA
         SET ANA.PIB_YTD             = ANA.PIB_CURR_MTH,
             ANA.CALCULATED_NLPI_YTD = ANA.CALCULATED_NLPI_CURR_MTH,
             UPDATE_DATE             = SYSDATE
       WHERE ANA.PERIODSEQ = V_PERIODSEQ;
    END IF;
    ------Update contribute agent NLPI value
    UPDATE AIA_NLPI_AGENT ANA
       SET ANA.NLPI_PAYMENT_CURR_MTH = DECODE(ANA.PAY_NLPI_YES_NO,
                                              'YES',
                                              ANA.CALCULATED_NLPI_CURR_MTH,
                                              0),
           ANA.NLPI_PAYMENT_YTD      = DECODE(ANA.PAY_NLPI_YES_NO,
                                              'YES',
                                              ANA.CALCULATED_NLPI_YTD,
                                              0),
           UPDATE_DATE               = SYSDATE
     WHERE ANA.PERIODSEQ = V_PERIODSEQ;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_SPI_PROC IS
  
  BEGIN
  
    DELETE FROM AIA_SPI_AGENT T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------All Agents with last version in current period
    INSERT INTO AIA_SPI_AGENT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       DISTRICT_CODE,
       DISTRICT_NAME,
       AGENCY_CODE,
       AGENCY_NAME,
       AGENT_NAME,
       ROLE,
       CLASS,
       AGENT_CODE,
       CONTRACT_DATE,
       AGENT_STATUS_CODE,
       TERMINATION_DATE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             API.GENERICATTRIBUTE6,
             API.GENERICATTRIBUTE7,
             API.GENERICATTRIBUTE2,
             API.GENERICATTRIBUTE3,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.POSITIONTITLE,
             API.GENERICATTRIBUTE8,
             API.PARTICIPANTID,
             API.HIREDATE,
             API.GENERICATTRIBUTE1,
             API.TERMINATIONDATE,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.BUSINESSUNITNAME = 'SGPAGY'
         AND EXISTS (SELECT 1
                FROM CS_MEASUREMENT MEA
               WHERE MEA.PERIODSEQ = V_PERIODSEQ
                 AND MEA.POSITIONSEQ = API.POSITIONSEQ
                 AND MEA.NAME IN ('SM_PIB_YTD_SG', 'SM_FYC_PL_YTD')
                 AND MEA.VALUE != 0);
    ------update YTD and SPI data
    UPDATE AIA_SPI_AGENT ASA
       SET (ASA.YTD_PERSONAL_PIB, ASA.PL_YTD_FYC) =
           (SELECT NVL(SUM(CASE
                             WHEN SMEA.NAME = 'SM_PIB_YTD_SG' THEN
                              SMEA.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN SMEA.NAME = 'SM_FYC_PL_YTD' THEN
                              SMEA.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_MEASUREMENT SMEA
             WHERE SMEA.PERIODSEQ = ASA.PERIODSEQ
               AND SMEA.POSITIONSEQ = ASA.POSITIONSEQ
               AND SMEA.NAME IN ('SM_PIB_YTD_SG', 'SM_FYC_PL_YTD')),
           (ASA.SPI_RATE, ASA.YTD_SPI) =
           ------Begin Modified by Chao 20140812
           /*(SELECT NVL(MAX(ADTI.GENERICNUMBER2), 0), NVL(SUM(ADTI.INCENTIVEVALUE), 0)
            FROM AIA_DEPOSIT_TRACE_INFOR ADTI
           WHERE ADTI.PERIODSEQ = ASA.PERIODSEQ
             AND ADTI.POSITIONSEQ = ASA.POSITIONSEQ
             AND ADTI.DEPOSITNAME = 'D_SPI_SG'
             AND ADTI.INCENTIVENAME = 'I_SPI_YTD_SG'),*/(SELECT NVL(MAX(INC.GENERICNUMBER1),
                                                                    0),
                                                                NVL(SUM(INC.VALUE),
                                                                    0)
                                                           FROM CS_INCENTIVE INC
                                                          WHERE INC.PERIODSEQ =
                                                                V_PERIODSEQ
                                                            AND INC.POSITIONSEQ =
                                                                ASA.POSITIONSEQ
                                                            AND INC.NAME =
                                                                'I_SPI_YTD_SG'),
           ------End Modified by Chao 20140812
           ASA.YTD_SPI_PQTR =
           (SELECT NVL(SUM(INC.VALUE), 0)
              FROM CS_INCENTIVE INC, CS_PERIOD PER
             WHERE INC.PERIODSEQ = PER.PERIODSEQ
               AND PER.REMOVEDATE = C_REMOVEDATE
               AND INC.POSITIONSEQ = ASA.POSITIONSEQ
               AND PER.CALENDARSEQ = V_CALENDARSEQ
               AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
               AND PER.STARTDATE = CASE
                     WHEN MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) < 3 THEN
                      NULL
                     ELSE
                      ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'Q'), -2)
                   END
               AND INC.NAME = 'I_SPI_YTD_SG'),
           (ASA.CURRENT_QTR_SPI, ASA.PL_YEAR_END_BONUS) =
           (SELECT NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_SPI_SG' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEP.NAME = 'D_PL_Year_End_Bonus' THEN
                              DEP.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_DEPOSIT DEP
             WHERE DEP.PERIODSEQ = ASA.PERIODSEQ
               AND DEP.POSITIONSEQ = ASA.POSITIONSEQ
               AND DEP.NAME IN ('D_SPI_SG', 'D_PL_Year_End_Bonus')),
           UPDATE_DATE = SYSDATE
     WHERE ASA.PERIODSEQ = V_PERIODSEQ;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_RENEWAL_COMMISSION_PROC IS
  BEGIN
  
    DELETE FROM AIA_RENEWAL_COMMISSION T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------All Agents with last version in current period
    INSERT INTO AIA_RENEWAL_COMMISSION
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       BUSINESSUNITNAME,
       DISTRICT_CODE,
       DISTRICT_NAME,
       AGENCY_CODE,
       AGENCY_NAME,
       AGENT_NAME,
       ROLE,
       CLASS,
       AGENT_CODE,
       CONTRACT_DATE,
       AGENT_STATUS_CODE,
       TERMINATION_DATE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             API.BUSINESSUNITNAME,
             API.GENERICATTRIBUTE6,
             API.GENERICATTRIBUTE7,
             API.GENERICATTRIBUTE2,
             API.GENERICATTRIBUTE3,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.POSITIONTITLE,
             API.GENERICATTRIBUTE8,
             API.PARTICIPANTID,
             API.HIREDATE,
             API.GENERICATTRIBUTE1,
             API.TERMINATIONDATE,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.BUSINESSUNITNAME IN ('SGPAGY', 'BRUAGY')
         AND API.POSITIONTITLE NOT IN ('DISTRICT', 'AGENCY')
         AND EXISTS (SELECT 1
                FROM CS_CREDIT CRD
               WHERE CRD.PERIODSEQ = V_PERIODSEQ
                 AND CRD.POSITIONSEQ = API.POSITIONSEQ
                 AND CRD.VALUE != 0);
    ------update credit data
    UPDATE AIA_RENEWAL_COMMISSION ARC
       SET (ARC.LIFE_2ND_YR_NORMAL_RC_CM,
            ARC.LIFE_3RD_YR_RC_CM,
            ARC.LIFE_4TH_YR_RC_CM,
            ARC.LIFE_5TH_YR_RC_CM,
            ARC.LIFE_6TH_YR_RC_CM,
            ARC.PA_RC_CM,
            ARC.CS_RC_CM,
            ARC.ASSIGNED_LIFE_RC_CM,
            ARC.VL_RC_CM,
            ARC.PL_RC_CM,
            ARC.TOTAL_7TH_YEAR_CM, ------
            ARC.NON_CAREER_LIFE_RC_CM) =
           (SELECT NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 IN ('LF', 'HS') AND
                                  CRD.GENERICATTRIBUTE4 = 'PAY2' AND
                                  CRD.GENERICATTRIBUTE16 = 'O' AND
                                  CRD.GENERICBOOLEAN5 = 0 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 IN ('LF', 'HS') AND
                                  CRD.GENERICATTRIBUTE4 = 'PAY3' AND
                                  CRD.GENERICATTRIBUTE16 = 'O' AND
                                  CRD.GENERICBOOLEAN5 = 0 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 IN ('LF', 'HS') AND
                                  CRD.GENERICATTRIBUTE4 = 'PAY4' AND
                                  CRD.GENERICATTRIBUTE16 = 'O' AND
                                  CRD.GENERICBOOLEAN5 = 0 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 IN ('LF', 'HS') AND
                                  CRD.GENERICATTRIBUTE4 = 'PAY5' AND
                                  CRD.GENERICATTRIBUTE16 = 'O' AND
                                  CRD.GENERICBOOLEAN5 = 0 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 IN ('LF', 'HS') AND
                                  CRD.GENERICATTRIBUTE4 = 'PAY6' AND
                                  CRD.GENERICATTRIBUTE16 = 'O' AND
                                  CRD.GENERICBOOLEAN5 = 0 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 = 'PA' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 IN ('CS', 'CL') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE16 IN ('RO', 'RNO') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 = 'VL' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE2 = 'PL' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICATTRIBUTE4 = 'PAY7' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.GENERICBOOLEAN5 = 1 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_CREDIT CRD, CS_CREDITTYPE CRDT
             WHERE CRD.PERIODSEQ = ARC.PERIODSEQ
               AND CRD.POSITIONSEQ = ARC.POSITIONSEQ
               AND CRD.CREDITTYPESEQ = CRDT.DATATYPESEQ
               AND CRDT.REMOVEDATE = C_REMOVEDATE
               AND CRDT.CREDITTYPEID = 'RYC'),
           UPDATE_DATE = SYSDATE
     WHERE ARC.PERIODSEQ = V_PERIODSEQ;
    ------update total field
    UPDATE AIA_RENEWAL_COMMISSION ARC
       SET ARC.TOTAL_2ND_TO_6TH_OWN_RC_CM =
           (ARC.LIFE_2ND_YR_NORMAL_RC_CM + ARC.LIFE_3RD_YR_RC_CM +
           ARC.LIFE_4TH_YR_RC_CM + ARC.LIFE_5TH_YR_RC_CM +
           ARC.LIFE_6TH_YR_RC_CM),
           ARC.LIFE_2ND_SPECIAL_COMM_CM  =
           (SELECT NVL(SUM(CRD.VALUE), 0)
              FROM CS_CREDIT CRD, CS_CREDITTYPE CRDT
             WHERE CRD.PERIODSEQ = ARC.PERIODSEQ
               AND CRD.POSITIONSEQ = ARC.POSITIONSEQ
               AND CRD.CREDITTYPESEQ = CRDT.DATATYPESEQ
               AND CRDT.REMOVEDATE = C_REMOVEDATE
               AND CRDT.CREDITTYPEID = 'SSCP'),
           ARC.TOTAL_OTHERS_SPCA_CM      =
           ((SELECT NVL(SUM(CRD.VALUE), 0)
               FROM CS_CREDIT CRD, CS_CREDITTYPE CRDT
              WHERE CRD.PERIODSEQ = ARC.PERIODSEQ
                AND CRD.POSITIONSEQ = ARC.POSITIONSEQ
                AND CRD.CREDITTYPESEQ = CRDT.DATATYPESEQ
                AND CRDT.REMOVEDATE = C_REMOVEDATE
                AND CRDT.CREDITTYPEID = 'SSCP') + ARC.PA_RC_CM + ARC.CS_RC_CM +
           ARC.ASSIGNED_LIFE_RC_CM + ARC.NON_CAREER_LIFE_RC_CM),
           ARC.TOTAL_7TH_YEAR_CM          = ARC.TOTAL_7TH_YEAR_CM +
                                            (SELECT NVL(SUM(CRD.VALUE), 0)
                                               FROM CS_CREDIT CRD
                                              WHERE CRD.PERIODSEQ = ARC.PERIODSEQ
                                                AND CRD.POSITIONSEQ =
                                                    ARC.POSITIONSEQ
                                                AND CRD.NAME IN
                                                    ('C_APF_Payable',
                                                     'C_APF_ACCRUAL')),
           UPDATE_DATE                    = SYSDATE
     WHERE ARC.PERIODSEQ = V_PERIODSEQ;
    ------update YTD data
    IF TO_CHAR(V_PERIODSTARTDATE, 'MM') = '12' THEN
      UPDATE AIA_RENEWAL_COMMISSION ARC
         SET ARC.LIFE_2ND_YR_NORMAL_RC_YTD   = ARC.LIFE_2ND_YR_NORMAL_RC_CM,
             ARC.LIFE_3RD_YR_RC_YTD          = ARC.LIFE_3RD_YR_RC_CM,
             ARC.LIFE_4TH_YR_RC_YTD          = ARC.LIFE_4TH_YR_RC_CM,
             ARC.LIFE_5TH_YR_RC_YTD          = ARC.LIFE_5TH_YR_RC_CM,
             ARC.LIFE_6TH_YR_RC_YTD          = ARC.LIFE_6TH_YR_RC_CM,
             ARC.TOTAL_2ND_TO_6TH_OWN_RC_YTD = ARC.TOTAL_2ND_TO_6TH_OWN_RC_CM,
             ARC.LIFE_2ND_SPECIAL_COMM_YTD   = ARC.LIFE_2ND_SPECIAL_COMM_CM,
             ARC.CS_RC_YTD                   = ARC.CS_RC_CM,
             ARC.PA_RC_YTD                   = ARC.PA_RC_CM,
             ARC.ASSIGNED_LIFE_RC_YTD        = ARC.ASSIGNED_LIFE_RC_CM,
             ARC.TOTAL_OTHERS_SPCA_YTD       = ARC.TOTAL_OTHERS_SPCA_CM,
             ARC.VL_RC_YTD                   = ARC.VL_RC_CM,
             ARC.PL_RC_YTD                   = ARC.PL_RC_CM,
             ARC.TOTAL_7TH_YEAR_YTD          = ARC.TOTAL_7TH_YEAR_CM,
             ARC.NON_CAREER_LIFE_RC_YTD      = ARC.NON_CAREER_LIFE_RC_CM,
             UPDATE_DATE                     = SYSDATE
       WHERE ARC.PERIODSEQ = V_PERIODSEQ;
    ELSE
      UPDATE AIA_RENEWAL_COMMISSION ARC
         SET (ARC.LIFE_2ND_YR_NORMAL_RC_YTD,
              ARC.LIFE_3RD_YR_RC_YTD,
              ARC.LIFE_4TH_YR_RC_YTD,
              ARC.LIFE_5TH_YR_RC_YTD,
              ARC.LIFE_6TH_YR_RC_YTD,
              ARC.TOTAL_2ND_TO_6TH_OWN_RC_YTD,
              ARC.LIFE_2ND_SPECIAL_COMM_YTD,
              ARC.CS_RC_YTD,
              ARC.PA_RC_YTD,
              ARC.ASSIGNED_LIFE_RC_YTD,
              ARC.TOTAL_OTHERS_SPCA_YTD,
              ARC.VL_RC_YTD,
              ARC.PL_RC_YTD,
              ARC.TOTAL_7TH_YEAR_YTD,
              ARC.NON_CAREER_LIFE_RC_YTD) =
             (SELECT NVL(SUM(T.LIFE_2ND_YR_NORMAL_RC_YTD), 0) +
                     ARC.LIFE_2ND_YR_NORMAL_RC_CM,
                     NVL(SUM(T.LIFE_3RD_YR_RC_YTD), 0) + ARC.LIFE_3RD_YR_RC_CM,
                     NVL(SUM(T.LIFE_4TH_YR_RC_YTD), 0) + ARC.LIFE_4TH_YR_RC_CM,
                     NVL(SUM(T.LIFE_5TH_YR_RC_YTD), 0) + ARC.LIFE_5TH_YR_RC_CM,
                     NVL(SUM(T.LIFE_6TH_YR_RC_YTD), 0) + ARC.LIFE_6TH_YR_RC_CM,
                     NVL(SUM(T.TOTAL_2ND_TO_6TH_OWN_RC_YTD), 0) +
                     ARC.TOTAL_2ND_TO_6TH_OWN_RC_CM,
                     NVL(SUM(T.LIFE_2ND_SPECIAL_COMM_YTD), 0) +
                     ARC.LIFE_2ND_SPECIAL_COMM_CM,
                     NVL(SUM(T.CS_RC_YTD), 0) + ARC.CS_RC_CM,
                     NVL(SUM(T.PA_RC_YTD), 0) + ARC.PA_RC_CM,
                     NVL(SUM(T.ASSIGNED_LIFE_RC_YTD), 0) +
                     ARC.ASSIGNED_LIFE_RC_CM,
                     NVL(SUM(T.TOTAL_OTHERS_SPCA_YTD), 0) +
                     ARC.TOTAL_OTHERS_SPCA_CM,
                     NVL(SUM(T.VL_RC_YTD), 0) + ARC.VL_RC_CM,
                     NVL(SUM(T.PL_RC_YTD), 0) + ARC.PL_RC_CM,
                     NVL(SUM(T.TOTAL_7TH_YEAR_YTD), 0) + ARC.TOTAL_7TH_YEAR_CM,
                     NVL(SUM(T.NON_CAREER_LIFE_RC_YTD), 0) +
                     ARC.NON_CAREER_LIFE_RC_CM
                FROM AIA_RENEWAL_COMMISSION T
               WHERE T.PERIODSEQ = V_PRIOR_PERIODSEQ
                 AND T.POSITIONSEQ = ARC.POSITIONSEQ
                 AND ROWNUM = 1),
             UPDATE_DATE = SYSDATE
       WHERE ARC.PERIODSEQ = V_PERIODSEQ;
    END IF;
    COMMIT;
    ------Insert YTD records
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) > 0 THEN
      INSERT INTO AIA_RENEWAL_COMMISSION
        (PERIODSEQ,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         PARTICIPANTSEQ,
         POSITIONSEQ,
         EFFECTIVESTARTDATE,
         EFFECTIVEENDDATE,
         MANAGERSEQ,
         POSITIONNAME,
         POSITIONTITLE,
         DISTRICT_CODE,
         DISTRICT_NAME,
         AGENCY_CODE,
         AGENCY_NAME,
         AGENT_CODE,
         AGENT_NAME,
         ROLE,
         CLASS,
         CONTRACT_DATE,
         AGENT_STATUS_CODE,
         TERMINATION_DATE,
         LIFE_2ND_YR_NORMAL_RC_CM,
         LIFE_2ND_YR_NORMAL_RC_YTD,
         LIFE_3RD_YR_RC_CM,
         LIFE_3RD_YR_RC_YTD,
         LIFE_4TH_YR_RC_CM,
         LIFE_4TH_YR_RC_YTD,
         LIFE_5TH_YR_RC_CM,
         LIFE_5TH_YR_RC_YTD,
         LIFE_6TH_YR_RC_CM,
         LIFE_6TH_YR_RC_YTD,
         TOTAL_2ND_TO_6TH_OWN_RC_CM,
         TOTAL_2ND_TO_6TH_OWN_RC_YTD,
         LIFE_2ND_SPECIAL_COMM_CM,
         LIFE_2ND_SPECIAL_COMM_YTD,
         PA_RC_CM,
         PA_RC_YTD,
         CS_RC_CM,
         CS_RC_YTD,
         ASSIGNED_LIFE_RC_CM,
         ASSIGNED_LIFE_RC_YTD,
         TOTAL_OTHERS_SPCA_CM,
         TOTAL_OTHERS_SPCA_YTD,
         VL_RC_CM,
         VL_RC_YTD,
         PL_RC_CM,
         PL_RC_YTD,
         TOTAL_7TH_YEAR_CM,
         TOTAL_7TH_YEAR_YTD,
         NON_CAREER_LIFE_RC_CM,
         NON_CAREER_LIFE_RC_YTD,
         CREATE_DATE)
        SELECT V_PERIODSEQ,
               V_CALENDARNAME,
               V_PERIODNAME,
               V_PERIODSTARTDATE,
               V_PERIODENDDATE,
               T.PARTICIPANTSEQ,
               T.POSITIONSEQ,
               T.EFFECTIVESTARTDATE,
               T.EFFECTIVEENDDATE,
               T.MANAGERSEQ,
               T.POSITIONNAME,
               T.POSITIONTITLE,
               T.DISTRICT_CODE,
               T.DISTRICT_NAME,
               T.AGENCY_CODE,
               T.AGENCY_NAME,
               T.AGENT_CODE,
               T.AGENT_NAME,
               T.ROLE,
               T.CLASS,
               T.CONTRACT_DATE,
               T.AGENT_STATUS_CODE,
               T.TERMINATION_DATE,
               0,
               T.LIFE_2ND_YR_NORMAL_RC_YTD,
               0,
               T.LIFE_3RD_YR_RC_YTD,
               0,
               T.LIFE_4TH_YR_RC_YTD,
               0,
               T.LIFE_5TH_YR_RC_YTD,
               0,
               T.LIFE_6TH_YR_RC_YTD,
               0,
               T.TOTAL_2ND_TO_6TH_OWN_RC_YTD,
               0,
               T.LIFE_2ND_SPECIAL_COMM_YTD,
               0,
               T.PA_RC_YTD,
               0,
               T.CS_RC_YTD,
               0,
               T.ASSIGNED_LIFE_RC_YTD,
               0,
               T.TOTAL_OTHERS_SPCA_YTD,
               0,
               T.VL_RC_YTD,
               0,
               T.PL_RC_YTD,
               0,
               T.TOTAL_7TH_YEAR_YTD,
               0,
               T.NON_CAREER_LIFE_RC_YTD,
               SYSDATE
          FROM AIA_RENEWAL_COMMISSION T
         WHERE T.PERIODSEQ = V_PRIOR_PERIODSEQ
           AND NOT EXISTS (SELECT *
                  FROM AIA_RENEWAL_COMMISSION ANC
                 WHERE ANC.PERIODSEQ = V_PERIODSEQ
                   AND ANC.DISTRICT_CODE = T.DISTRICT_CODE
                   AND ANC.AGENCY_CODE = T.AGENCY_CODE
                   AND ANC.AGENT_CODE = T.AGENT_CODE);
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_DIRECT_OVERRIDE_PROC IS
  BEGIN
  
    DELETE FROM AIA_DIRECT_OVERRIDE_LEADER T WHERE T.PERIODSEQ = V_PERIODSEQ;
    DELETE FROM AIA_DIRECT_OVERRIDE_AGENT T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------All Leader Agents with last version in current period
    INSERT INTO AIA_DIRECT_OVERRIDE_LEADER
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       LAST_DATE,
       LDR_UNIT,
       LDR_CODE,
       LDR_NAME,
       AGENCY_NAME,
       LDR_CLASS,
       DISSOLVED_AGENCY_DATE,
       UNIT,
       AGENT_CODE,
       AGENT_NAME,
       AGENT_STATUS_CODE,
       TERMINATION_DATE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             V_PERIODENDDATE - 1,
             API.GENERICATTRIBUTE2, --LDR_UNIT
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE3, --AGENCY_NAME
             API.GENERICATTRIBUTE8, --LDR_CLASS
             API.TERMINATIONDATE,
             API.GENERICATTRIBUTE2,
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE1,
             API.TERMINATIONDATE,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.BUSINESSUNITNAME = 'BRUAGY'
         AND EXISTS (SELECT 1
                FROM CS_DEPOSIT DEP
               WHERE DEP.PERIODSEQ = V_PERIODSEQ
                 AND DEP.POSITIONSEQ = API.POSITIONSEQ
                 AND DEP.NAME = 'D_Direct_Override_BN'
                 AND DEP.VALUE != 0);
    ------Update DO rate
    UPDATE AIA_DIRECT_OVERRIDE_LEADER ADOL
       SET ADOL.DO_RATE =
           (SELECT NVL(MAX(MEA.GENERICNUMBER1), 0)
              FROM CS_MEASUREMENT MEA
             WHERE MEA.PERIODSEQ = ADOL.PERIODSEQ
               AND MEA.POSITIONSEQ = ADOL.POSITIONSEQ
               AND MEA.NAME = 'SM_DO_Base_BN')
     WHERE ADOL.PERIODSEQ = V_PERIODSEQ;
    ------Insert Contribute Agents' Records
    INSERT INTO AIA_DIRECT_OVERRIDE_AGENT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       MANAGERSEQ,
       LAST_DATE,
       LDR_UNIT,
       LDR_CODE,
       LDR_NAME,
       AGENCY_NAME,
       LDR_CLASS,
       DISSOLVED_AGENCY_DATE,
       ------Contribute Agent
       AGENT_CODE,
       --added by zhubin replace unit with credit.GA13 20140808
       UNIT,
       --added by zhubin
       MTD_LIFE_FYC,
       MTD_AH_FYC,
       MTD_GRP_FYC,
       MTD_TTL_FYC,
       DO_RATE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             ADOL.POSITIONSEQ, --MANAGERSEQ
             ADOL.LAST_DATE,
             ADOL.LDR_UNIT,
             ADOL.LDR_CODE,
             ADOL.LDR_NAME,
             ADOL.AGENCY_NAME,
             ADOL.LDR_CLASS,
             ADOL.DISSOLVED_AGENCY_DATE,
             ------Contribute Agent
             CRD.GENERICATTRIBUTE12,
             ----added by zhubin replace unit with credit.GA13 20140808
             ------Unit Code
             CRD.GENERICATTRIBUTE13,
             --added by zhubin
             SUM((CASE
                   WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB', 'PIB_Sub_Manager') AND
                        CRD.GENERICATTRIBUTE2 = 'LF' THEN
                    CRD.VALUE
                   ELSE
                    0
                 END)),
             SUM((CASE
                   WHEN CRDT.CREDITTYPEID IN ('FYC', 'PIB_Sub_Manager') AND
                        CRD.GENERICATTRIBUTE2 = 'PA' THEN
                    CRD.VALUE
                   ELSE
                    0
                 END)),
             SUM((CASE
                   WHEN CRDT.CREDITTYPEID IN ('FYC', 'PIB_Sub_Manager') AND
                        CRD.GENERICATTRIBUTE2 IN ('CS', 'CL') THEN
                    CRD.VALUE
                   ELSE
                    0
                 END)),
             SUM((CASE
                   WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB', 'PIB_Sub_Manager') AND
                        CRD.GENERICATTRIBUTE2 IN ('LF', 'PA', 'CS', 'CL') THEN
                    CRD.VALUE
                   ELSE
                    0
                 END)),
             ADOL.DO_RATE,
             SYSDATE
        FROM AIA_DIRECT_OVERRIDE_LEADER ADOL,
             CS_CREDIT                  CRD,
             CS_CREDITTYPE              CRDT,
             AIA_PAYEE_INFOR            API
       WHERE ADOL.LDR_UNIT = API.PARTICIPANTID
         AND API.POSITIONSEQ = CRD.POSITIONSEQ
         AND ADOL.PERIODSEQ = CRD.PERIODSEQ
         AND CRD.CREDITTYPESEQ = CRDT.DATATYPESEQ
         AND CRDT.REMOVEDATE = C_REMOVEDATE
         AND ADOL.PERIODSEQ = V_PERIODSEQ
         AND CRD.GENERICATTRIBUTE12 IS NOT NULL
       GROUP BY ADOL.POSITIONSEQ,
                ADOL.LAST_DATE,
                ADOL.LDR_UNIT,
                ADOL.LDR_CODE,
                ADOL.LDR_NAME,
                ADOL.AGENCY_NAME,
                ADOL.LDR_CLASS,
                ADOL.DISSOLVED_AGENCY_DATE,
                ------Contribute Agent
                CRD.GENERICATTRIBUTE12,
                --added by zhubin replace unit with credit.GA13 20140808
                ------unit_code
                CRD.GENERICATTRIBUTE13,
                --added by zhubin
                ADOL.DO_RATE;
    ------Update contribute agent information
    UPDATE AIA_DIRECT_OVERRIDE_AGENT ADOA
       SET (ADOA.PARTICIPANTSEQ,
            ADOA.POSITIONSEQ,
            ADOA.EFFECTIVESTARTDATE,
            ADOA.EFFECTIVEENDDATE,
            ADOA.POSITIONNAME,
            ADOA.POSITIONTITLE,
            --ADOA.UNIT,
            ADOA.AGENT_NAME,
            ADOA.CONTRACT_DATE,
            ADOA.CLASS,
            ADOA.AGENT_STATUS_CODE,
            ADOA.TERMINATION_DATE,
            UPDATE_DATE) =
           (SELECT API.PARTICIPANTSEQ,
                   API.POSITIONSEQ,
                   API.EFFECTIVESTARTDATE,
                   API.EFFECTIVEENDDATE,
                   API.POSITIONNAME,
                   API.POSITIONTITLE,
                   --API.GENERICATTRIBUTE2, --Unit Code
                   API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                   API.HIREDATE,
                   API.GENERICATTRIBUTE8, --Class Code
                   API.GENERICATTRIBUTE1,
                   API.TERMINATIONDATE,
                   SYSDATE
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = ADOA.AGENT_CODE
               AND API.BUSINESSUNITNAME = 'BRUAGY'
               AND API.EFFECTIVESTARTDATE < V_PERIODENDDATE
               AND API.EFFECTIVEENDDATE > V_PERIODSTARTDATE
               AND API.POSITIONNAME LIKE '%T%'
               AND ROWNUM = 1)
     WHERE ADOA.PERIODSEQ = V_PERIODSEQ;
    ------Update Contract Months
    UPDATE AIA_DIRECT_OVERRIDE_AGENT ADOA
       SET ADOA.CONTRACT_MONTHS =
           (SELECT NVL(SUM(MEA.VALUE), 0)
              FROM CS_MEASUREMENT MEA
             WHERE MEA.PERIODSEQ = ADOA.PERIODSEQ
               AND MEA.POSITIONSEQ = ADOA.POSITIONSEQ
               AND MEA.NAME = 'SM_Contract_Month'),
           UPDATE_DATE          = SYSDATE
     WHERE ADOA.PERIODSEQ = V_PERIODSEQ;
    ------Update MTH DO(BASE)/MTH DO(NEW AGENT)/DO(QTR) QTD FYC > 1,250
    UPDATE AIA_DIRECT_OVERRIDE_AGENT ADOA
       SET (ADOA.MTH_DO_BASE, ADOA.MTH_DO_NEW_AGENT) =
           (SELECT NVL(SUM(CASE
                             WHEN ADTI.SMEASUREMENTNAME = 'SM_DO_Base_BN' THEN
                              ADTI.CREDITVALUE * NVL(ADTI.GENERICNUMBER3, 0)
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.SMEASUREMENTNAME = 'SM_DO_New_Agent_BN' THEN
                              ADTI.CREDITVALUE * NVL(ADTI.GENERICNUMBER4, 0)
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.POSITIONSEQ = ADOA.MANAGERSEQ
               AND ADTI.PERIODSEQ = ADOA.PERIODSEQ
               AND ADTI.DEPOSITNAME = 'D_Direct_Override_BN'
               AND ADTI.GENERICATTRIBUTE1 = ADOA.AGENT_CODE
               AND ADTI.TRACELEVEL = 'Credit Level'),
           UPDATE_DATE = SYSDATE
     WHERE ADOA.PERIODSEQ = V_PERIODSEQ;
  
    ------QTD data
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 3) > 0 THEN
      ------Update QTD data    
      UPDATE AIA_DIRECT_OVERRIDE_AGENT ADOA
         SET (ADOA.QUARTER_LIFE_FYC,
              ADOA.QUARTER_AH_FYC,
              ADOA.QUARTER_GRP_FYC,
              ADOA.QUARTER_TTL_FYC) =
             (SELECT NVL(SUM(T.QUARTER_LIFE_FYC), 0) + ADOA.MTD_LIFE_FYC,
                     NVL(SUM(T.QUARTER_AH_FYC), 0) + ADOA.MTD_AH_FYC,
                     NVL(SUM(T.QUARTER_GRP_FYC), 0) + ADOA.MTD_GRP_FYC,
                     NVL(SUM(T.QUARTER_LIFE_FYC), 0) + ADOA.MTD_LIFE_FYC +
                     NVL(SUM(T.QUARTER_AH_FYC), 0) + ADOA.MTD_AH_FYC +
                     NVL(SUM(T.QUARTER_GRP_FYC), 0) + ADOA.MTD_GRP_FYC
                FROM AIA_DIRECT_OVERRIDE_AGENT T
               WHERE T.PERIODSEQ = V_PRIOR_PERIODSEQ
                 AND T.POSITIONSEQ = ADOA.POSITIONSEQ),
             UPDATE_DATE = SYSDATE
       WHERE ADOA.PERIODSEQ = V_PERIODSEQ;
      IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 3) = 2 THEN
        UPDATE AIA_DIRECT_OVERRIDE_AGENT ADOA
           SET ADOA.DO_QTR_QTD_FYC = NVL((SELECT SUM(CRD.VALUE)
                                           FROM CS_CREDIT       CRD,
                                                CS_PERIOD       PER,
                                                AIA_PAYEE_INFOR API
                                          WHERE CRD.NAME = 'C_DO_QTR_BN'
                                            AND CRD.GENERICBOOLEAN3 = 1
                                            AND CRD.PERIODSEQ = PER.PERIODSEQ
                                            AND CRD.GENERICATTRIBUTE12 =
                                                ADOA.AGENT_CODE
                                            AND ADOA.LDR_UNIT =
                                                API.PARTICIPANTID
                                            AND CRD.POSITIONSEQ =
                                                API.POSITIONSEQ
                                            AND (UPPER(API.POSITIONTITLE) LIKE
                                                '%AGENCY' OR UPPER(API.POSITIONTITLE) LIKE
                                                '%DISTRICT')
                                            AND API.BUSINESSUNITNAME = 'BRUAGY'
                                            AND PER.STARTDATE >=
                                                ADD_MONTHS(ADOA.PERIODSTARTDATE,
                                                           -2)
                                            AND PER.STARTDATE <=
                                                ADOA.PERIODSTARTDATE
                                            AND PER.CALENDARSEQ = V_CALENDARSEQ
                                            AND PER.PERIODTYPESEQ =
                                                V_PERIODTYPESEQ
                                            AND PER.REMOVEDATE = C_REMOVEDATE),
                                         0) *
                                     NVL((SELECT MAX(INC.GENERICNUMBER1)
                                           FROM CS_INCENTIVE INC
                                          WHERE INC.NAME =
                                                'I_Direct_Override_BN'
                                            AND INC.POSITIONSEQ =
                                                ADOA.MANAGERSEQ
                                            AND INC.PERIODSEQ = ADOA.PERIODSEQ),
                                         0),
               UPDATE_DATE         = SYSDATE
         WHERE ADOA.PERIODSEQ = V_PERIODSEQ;
      END IF;
      ------Insert QTD data
      INSERT INTO AIA_DIRECT_OVERRIDE_AGENT
        (PERIODSEQ,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         PARTICIPANTSEQ,
         POSITIONSEQ,
         EFFECTIVESTARTDATE,
         EFFECTIVEENDDATE,
         MANAGERSEQ,
         POSITIONNAME,
         POSITIONTITLE,
         LAST_DATE,
         LDR_UNIT,
         LDR_CODE,
         LDR_NAME,
         AGENCY_NAME,
         LDR_CLASS,
         DISSOLVED_AGENCY_DATE,
         UNIT,
         AGENT_CODE,
         AGENT_NAME,
         CONTRACT_DATE,
         CONTRACT_MONTHS,
         CLASS,
         AGENT_STATUS_CODE,
         TERMINATION_DATE,
         MTD_LIFE_FYC,
         MTD_AH_FYC,
         MTD_GRP_FYC,
         MTD_TTL_FYC,
         DO_RATE,
         QUARTER_LIFE_FYC,
         QUARTER_AH_FYC,
         QUARTER_GRP_FYC,
         QUARTER_TTL_FYC,
         MTH_DO_BASE,
         MTH_DO_NEW_AGENT,
         DO_QTR_QTD_FYC,
         CREATE_DATE)
        SELECT V_PERIODSEQ,
               V_CALENDARNAME,
               V_PERIODNAME,
               V_PERIODSTARTDATE,
               V_PERIODENDDATE,
               ADOA.PARTICIPANTSEQ,
               ADOA.POSITIONSEQ,
               ADOA.EFFECTIVESTARTDATE,
               ADOA.EFFECTIVEENDDATE,
               ADOA.MANAGERSEQ,
               ADOA.POSITIONNAME,
               ADOA.POSITIONTITLE,
               ADOA.LAST_DATE,
               ADOA.LDR_UNIT,
               ADOA.LDR_CODE,
               ADOA.LDR_NAME,
               ADOA.AGENCY_NAME,
               ADOA.LDR_CLASS,
               ADOA.DISSOLVED_AGENCY_DATE,
               ADOA.UNIT,
               ADOA.AGENT_CODE,
               ADOA.AGENT_NAME,
               ADOA.CONTRACT_DATE,
               0,
               ADOA.CLASS,
               ADOA.AGENT_STATUS_CODE,
               ADOA.TERMINATION_DATE,
               0,
               0,
               0,
               0,
               0,
               ADOA.QUARTER_LIFE_FYC,
               ADOA.QUARTER_AH_FYC,
               ADOA.QUARTER_GRP_FYC,
               ADOA.QUARTER_TTL_FYC,
               0,
               0,
               0,
               SYSDATE
          FROM AIA_DIRECT_OVERRIDE_AGENT ADOA
         WHERE ADOA.PERIODSEQ = V_PRIOR_PERIODSEQ
           AND NOT EXISTS (SELECT 1
                  FROM AIA_DIRECT_OVERRIDE_AGENT T
                 WHERE T.PERIODSEQ = V_PERIODSEQ
                   AND T.LDR_CODE = ADOA.LDR_CODE
                   AND T.AGENT_CODE = ADOA.AGENT_CODE);
    ELSE
      ------Update QTD data    
      UPDATE AIA_DIRECT_OVERRIDE_AGENT ADOA
         SET ADOA.QUARTER_LIFE_FYC = ADOA.MTD_LIFE_FYC,
             ADOA.QUARTER_AH_FYC   = ADOA.MTD_AH_FYC,
             ADOA.QUARTER_GRP_FYC  = ADOA.MTD_GRP_FYC,
             ADOA.QUARTER_TTL_FYC  = ADOA.MTD_LIFE_FYC + ADOA.MTD_AH_FYC +
                                     ADOA.MTD_GRP_FYC,
             UPDATE_DATE           = SYSDATE
       WHERE ADOA.PERIODSEQ = V_PERIODSEQ;
    END IF;
    ------Update Leader data
    UPDATE AIA_DIRECT_OVERRIDE_LEADER ADOL
       SET (ADOL.MTD_LIFE_FYC,
            ADOL.MTD_AH_FYC,
            ADOL.MTD_GRP_FYC,
            ADOL.MTD_TTL_FYC,
            ADOL.QUARTER_LIFE_FYC,
            ADOL.QUARTER_AH_FYC,
            ADOL.QUARTER_GRP_FYC,
            ADOL.QUARTER_TTL_FYC) =
           (SELECT NVL(SUM(ADOA.MTD_LIFE_FYC), 0),
                   NVL(SUM(ADOA.MTD_AH_FYC), 0),
                   NVL(SUM(ADOA.MTD_GRP_FYC), 0),
                   NVL(SUM(ADOA.MTD_TTL_FYC), 0),
                   NVL(SUM(ADOA.QUARTER_LIFE_FYC), 0),
                   NVL(SUM(ADOA.QUARTER_AH_FYC), 0),
                   NVL(SUM(ADOA.QUARTER_GRP_FYC), 0),
                   NVL(SUM(ADOA.QUARTER_TTL_FYC), 0)
              FROM AIA_DIRECT_OVERRIDE_AGENT ADOA
             WHERE ADOA.PERIODSEQ = ADOL.PERIODSEQ
               AND ADOA.LDR_CODE = ADOL.LDR_CODE),
           (ADOL.MTH_DO_BASE, ADOL.MTH_DO_NEW_AGENT, ADOL.DO_QTR_QTD_FYC) =
           (SELECT NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Direct_Override_BN' AND
                                  ADTI.SMEASUREMENTNAME = 'SM_DO_Base_BN' THEN
                              ADTI.SMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Direct_Override_BN' AND
                                  ADTI.SMEASUREMENTNAME = 'SM_DO_New_Agent_BN' THEN
                              ADTI.SMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.DEPOSITNAME = 'D_Direct_Override_BN' AND
                                  ADTI.PMEASUREMENTNAME = 'PM_DO_QTR_BN' THEN
                              ADTI.PMEASUREMENTVALUE * NVL(ADTI.GENERICNUMBER6, 0)
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = ADOL.PERIODSEQ
               AND ADTI.POSITIONSEQ = ADOL.POSITIONSEQ
               AND ADTI.DEPOSITNAME = 'D_Direct_Override_BN'
               AND ADTI.TRACELEVEL LIKE '%Measurement Level'),
           UPDATE_DATE = SYSDATE
     WHERE ADOL.PERIODSEQ = V_PERIODSEQ;
    ------Insert Last Period Leader QTD data
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 3) > 0 THEN
      INSERT INTO AIA_DIRECT_OVERRIDE_LEADER
        (PERIODSEQ,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         PARTICIPANTSEQ,
         POSITIONSEQ,
         EFFECTIVESTARTDATE,
         EFFECTIVEENDDATE,
         MANAGERSEQ,
         POSITIONNAME,
         POSITIONTITLE,
         LAST_DATE,
         LDR_UNIT,
         LDR_CODE,
         LDR_NAME,
         AGENCY_NAME,
         LDR_CLASS,
         DISSOLVED_AGENCY_DATE,
         UNIT,
         AGENT_CODE,
         AGENT_NAME,
         CONTRACT_DATE,
         CONTRACT_MONTHS,
         CLASS,
         AGENT_STATUS_CODE,
         TERMINATION_DATE,
         MTD_LIFE_FYC,
         MTD_AH_FYC,
         MTD_GRP_FYC,
         MTD_TTL_FYC,
         DO_RATE,
         QUARTER_LIFE_FYC,
         QUARTER_AH_FYC,
         QUARTER_GRP_FYC,
         QUARTER_TTL_FYC,
         MTH_DO_BASE,
         MTH_DO_NEW_AGENT,
         DO_QTR_QTD_FYC,
         CREATE_DATE)
        SELECT V_PERIODSEQ,
               V_CALENDARNAME,
               V_PERIODNAME,
               V_PERIODSTARTDATE,
               V_PERIODENDDATE,
               ADOL.PARTICIPANTSEQ,
               ADOL.POSITIONSEQ,
               ADOL.EFFECTIVESTARTDATE,
               ADOL.EFFECTIVEENDDATE,
               ADOL.MANAGERSEQ,
               ADOL.POSITIONNAME,
               ADOL.POSITIONTITLE,
               ADOL.LAST_DATE,
               ADOL.LDR_UNIT,
               ADOL.LDR_CODE,
               ADOL.LDR_NAME,
               ADOL.AGENCY_NAME,
               ADOL.LDR_CLASS,
               ADOL.DISSOLVED_AGENCY_DATE,
               ADOL.UNIT,
               ADOL.AGENT_CODE,
               ADOL.AGENT_NAME,
               ADOL.CONTRACT_DATE,
               0,
               ADOL.CLASS,
               ADOL.AGENT_STATUS_CODE,
               ADOL.TERMINATION_DATE,
               0,
               0,
               0,
               0,
               0,
               ADOL.QUARTER_LIFE_FYC,
               ADOL.QUARTER_AH_FYC,
               ADOL.QUARTER_GRP_FYC,
               ADOL.QUARTER_TTL_FYC,
               0,
               0,
               0,
               SYSDATE
          FROM AIA_DIRECT_OVERRIDE_LEADER ADOL
         WHERE ADOL.PERIODSEQ = V_PRIOR_PERIODSEQ
           AND NOT EXISTS (SELECT 1
                  FROM AIA_DIRECT_OVERRIDE_LEADER T
                 WHERE T.PERIODSEQ = V_PERIODSEQ
                   AND T.LDR_CODE = ADOL.LDR_CODE
                   AND T.AGENT_CODE = ADOL.AGENT_CODE);
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_RENEWAL_OVERRIDE_PROC IS
  BEGIN
  
    DELETE FROM AIA_RENEWAL_OVERRIDE_LEADER T WHERE T.PERIODSEQ = V_PERIODSEQ;
    DELETE FROM AIA_RENEWAL_OVERRIDE_AGENT T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------All Leader Agents with last version in current period
    INSERT INTO AIA_RENEWAL_OVERRIDE_LEADER
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       LAST_DATE,
       LDR_UNIT,
       LDR_CODE,
       LDR_NAME,
       LDR_CLASS,
       SUSPEND_DATE,
       RELEASE_DATE,
       UNIT,
       AGENT_CODE,
       AGENT_NAME,
       AGENT_STATUS_CODE,
       TERMINATION_DATE,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             V_PERIODENDDATE - 1,
             API.GENERICATTRIBUTE2,
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE8,
             API.GENERICDATE5,
             API.GENERICDATE6,
             API.GENERICATTRIBUTE2,
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE1,
             API.TERMINATIONDATE,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.BUSINESSUNITNAME = 'BRUAGY'
         AND EXISTS
       (SELECT 1
                FROM CS_DEPOSIT DEP
               WHERE DEP.PERIODSEQ = V_PERIODSEQ
                 AND DEP.POSITIONSEQ = API.POSITIONSEQ
                 AND DEP.NAME IN
                     ('D_Renewal_Override_BN', 'D_Renewal_Override_Probation_BN')
                 AND DEP.VALUE != 0);
    ------Insert Contribute Agents' Records
    INSERT INTO AIA_RENEWAL_OVERRIDE_AGENT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       MANAGERSEQ,
       LAST_DATE,
       LDR_UNIT,
       LDR_CODE,
       LDR_NAME,
       LDR_CLASS,
       SUSPEND_DATE,
       RELEASE_DATE,
       ------Contribute Agent
       ------Begin Modified by Chao 20140814
       UNIT,
       AGENT_CODE,
       CLASS,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             AROL.POSITIONSEQ, --MANAGERSEQ
             AROL.LAST_DATE,
             AROL.LDR_UNIT,
             AROL.LDR_CODE,
             AROL.LDR_NAME,
             AROL.LDR_CLASS,
             AROL.SUSPEND_DATE,
             AROL.RELEASE_DATE,
             ------Contribute Agent
             ADTI.GENERICATTRIBUTE5, --Contribute UNit
             ADTI.GENERICATTRIBUTE1, --Contribute Agent
             ADTI.GENERICATTRIBUTE6, --Contribute Class             
             ------End Modified by Chao 20140814
             SYSDATE
        FROM AIA_RENEWAL_OVERRIDE_LEADER AROL, AIA_DEPOSIT_TRACE_INFOR ADTI
       WHERE AROL.POSITIONSEQ = ADTI.POSITIONSEQ
         AND AROL.PERIODSEQ = ADTI.PERIODSEQ
         AND ADTI.DEPOSITNAME IN
             ('D_Renewal_Override_BN', 'D_Renewal_Override_Probation_BN')
         AND ADTI.TRACELEVEL IN
             ('Credit Level', 'Secondary2 Measurement Level')
         AND AROL.PERIODSEQ = V_PERIODSEQ
       GROUP BY AROL.POSITIONSEQ,
                AROL.LAST_DATE,
                AROL.LDR_UNIT,
                AROL.LDR_CODE,
                AROL.LDR_NAME,
                AROL.LDR_CLASS,
                AROL.SUSPEND_DATE,
                AROL.RELEASE_DATE,
                ------Contribute Agent
                --ADTI.GENERICATTRIBUTE1
                ADTI.GENERICATTRIBUTE5, --Contribute UNit
                ADTI.GENERICATTRIBUTE1, --Contribute Agent
                ADTI.GENERICATTRIBUTE6; --Contribute Class
    ------Update contribute agent information
    UPDATE AIA_RENEWAL_OVERRIDE_AGENT AROA
       SET (AROA.PARTICIPANTSEQ,
            AROA.POSITIONSEQ,
            AROA.EFFECTIVESTARTDATE,
            AROA.EFFECTIVEENDDATE,
            AROA.POSITIONNAME,
            AROA.POSITIONTITLE,
            --AROA.UNIT,
            AROA.AGENT_NAME,
            AROA.CONTRACT_DATE,
            --AROA.CLASS,
            AROA.AGENT_STATUS_CODE,
            AROA.TERMINATION_DATE,
            UPDATE_DATE) =
           (SELECT API.PARTICIPANTSEQ,
                   API.POSITIONSEQ,
                   API.EFFECTIVESTARTDATE,
                   API.EFFECTIVEENDDATE,
                   API.POSITIONNAME,
                   API.POSITIONTITLE,
                   --API.GENERICATTRIBUTE2, --Unit Code
                   API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                   API.HIREDATE,
                   --API.GENERICATTRIBUTE8, --Class Code
                   API.GENERICATTRIBUTE1,
                   API.TERMINATIONDATE,
                   SYSDATE
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AROA.AGENT_CODE
               AND API.EFFECTIVESTARTDATE < V_PERIODENDDATE
               AND API.EFFECTIVEENDDATE > V_PERIODSTARTDATE
               AND API.BUSINESSUNITNAME = 'BRUAGY'
               AND API.POSITIONNAME LIKE '%T%'
               AND ROWNUM = 1)
     WHERE AROA.PERIODSEQ = V_PERIODSEQ;
    ------Update Agent data
    UPDATE AIA_RENEWAL_OVERRIDE_AGENT AROA
       SET (AROA.CAREER_BENEFIT, AROA.RATE_OF_CB) =
           (SELECT NVL(SUM(ADTI.SMEASUREMENTVALUE), 0),
                   NVL(MAX(ADTI.GENERICNUMBER6), 0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AROA.PERIODSEQ
               AND ADTI.POSITIONSEQ = AROA.MANAGERSEQ
               AND ADTI.GENERICATTRIBUTE1 = AROA.AGENT_CODE
               AND ADTI.DEPOSITNAME IN
                   ('D_Renewal_Override_BN', 'D_Renewal_Override_Probation_BN')
               AND ADTI.TRACELEVEL = 'Secondary2 Measurement Level'),
           (AROA.LIFE_2_6_YR_RYC, AROA.RATE_OF_RYC) =
           (SELECT NVL(SUM(ADTI.CREDITVALUE), 0),
                   NVL(MAX(ADTI.GENERICNUMBER6), 0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AROA.PERIODSEQ
               AND ADTI.POSITIONSEQ = AROA.MANAGERSEQ
               AND ADTI.GENERICATTRIBUTE1 = AROA.AGENT_CODE
               AND ADTI.DEPOSITNAME IN
                   ('D_Renewal_Override_BN', 'D_Renewal_Override_Probation_BN')
               AND ADTI.TRACELEVEL = 'Credit Level'),
           UPDATE_DATE = SYSDATE
     WHERE AROA.PERIODSEQ = V_PERIODSEQ;
    ------Update RO_CB/RO_RYC/RO_TOTAL  
    UPDATE AIA_RENEWAL_OVERRIDE_AGENT AROA
       SET AROA.RO_CB    = AROA.CAREER_BENEFIT * AROA.RATE_OF_CB,
           AROA.RO_RYC   = AROA.LIFE_2_6_YR_RYC * AROA.RATE_OF_RYC,
           AROA.RO_TOTAL = AROA.CAREER_BENEFIT * AROA.RATE_OF_CB +
                           AROA.LIFE_2_6_YR_RYC * AROA.RATE_OF_RYC,
           UPDATE_DATE   = SYSDATE
     WHERE AROA.PERIODSEQ = V_PERIODSEQ;
    ------Update Leader data
    UPDATE AIA_RENEWAL_OVERRIDE_LEADER AROL
       SET (AROL.CAREER_BENEFIT,
            AROL.LIFE_2_6_YR_RYC,
            AROL.RATE_OF_CB,
            AROL.RATE_OF_RYC) =
           (SELECT NVL(SUM(CASE
                             WHEN ADTI.SMEASUREMENTNAME =
                                  'SM_RO_CB_Monthly_DIRECT_TEAM_BN' THEN
                              ADTI.SMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.SMEASUREMENTNAME = 'SM_RO_RYC_LF_DIRECT_TEAM_BN' THEN
                              ADTI.SMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(MAX(ADTI.GENERICNUMBER6), 0),
                   NVL(MAX(ADTI.GENERICNUMBER6), 0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AROL.PERIODSEQ
               AND ADTI.POSITIONSEQ = AROL.POSITIONSEQ
               AND ADTI.DEPOSITNAME IN
                   ('D_Renewal_Override_BN', 'D_Renewal_Override_Probation_BN')
               AND ADTI.TRACELEVEL = 'Secondary Measurement Level'),
           AROL.WITHHELD_PAYMENT =
           (SELECT CASE
                     WHEN COUNT(1) = 0 THEN
                      'No'
                     ELSE
                      'Yes'
                   END
              FROM CS_DEPOSIT DEP
             WHERE DEP.PERIODSEQ = AROL.PERIODSEQ
               AND DEP.POSITIONSEQ = AROL.POSITIONSEQ
               AND DEP.NAME = 'D_Renewal_Override_Probation_BN'
               AND DEP.VALUE <> 0
               AND DEP.ISHELD = 1
               AND DEP.RELEASEDATE IS NULL),
           UPDATE_DATE = SYSDATE
     WHERE AROL.PERIODSEQ = V_PERIODSEQ;
    ------Update Leader's RO_CB/RO_RYC/RO_TOTAL  
    UPDATE AIA_RENEWAL_OVERRIDE_LEADER AROL
       SET AROL.RO_CB    = AROL.CAREER_BENEFIT * AROL.RATE_OF_CB,
           AROL.RO_RYC   = AROL.LIFE_2_6_YR_RYC * AROL.RATE_OF_RYC,
           AROL.RO_TOTAL = AROL.CAREER_BENEFIT * AROL.RATE_OF_CB +
                           AROL.LIFE_2_6_YR_RYC * AROL.RATE_OF_RYC,
           UPDATE_DATE   = SYSDATE
     WHERE AROL.PERIODSEQ = V_PERIODSEQ;
  
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_CAREER_BENEFIT_PROC IS
    V_PRIOR_NOVEMBER_SEQ  NUMBER(38);
    V_PRIOR_NOVEMBER_DATE DATE;
  BEGIN
    DELETE FROM AIA_CAREER_BENEFIT_AGENT T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------Get last year november Seq and Date
    SELECT TO_DATE(EXTRACT(YEAR FROM ADD_MONTHS(V_PERIODSTARTDATE, 1)) - 1 ||
                   '-11-1',
                   'YYYY-MM-DD')
      INTO V_PRIOR_NOVEMBER_DATE
      FROM DUAL;
    SELECT PER.PERIODSEQ
      INTO V_PRIOR_NOVEMBER_SEQ
      FROM CS_PERIOD PER
     WHERE PER.CALENDARSEQ = V_CALENDARSEQ
       AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
       AND PER.STARTDATE = V_PRIOR_NOVEMBER_DATE
       AND PER.REMOVEDATE = C_REMOVEDATE;
    ------Insert FSC data
    INSERT INTO AIA_CAREER_BENEFIT_AGENT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       DISTRICT_CODE,
       UNIT_CODE,
       LEADER_FSC_CODE,
       AGENCY_NAME,
       LEADER_NAME,
       FSC_CODE,
       FSC_NAME,
       FSC_CLASS,
       AGENT_STATUS_CODE,
       CONTRACT_DATE,
       FSC_TERM_DATE,
       NEW_FSC,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             API.GENERICATTRIBUTE6,
             API.GENERICATTRIBUTE2,
             API.GENERICATTRIBUTE4,
             API.GENERICATTRIBUTE3,
             API.GENERICATTRIBUTE5,
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE8,
             API.GENERICATTRIBUTE1,
             API.HIREDATE,
             API.TERMINATIONDATE,
             CASE
               WHEN TRUNC(ADD_MONTHS(API.HIREDATE, 1), 'year') =
                    TRUNC(ADD_MONTHS(V_PRIOR_NOVEMBER_DATE, 1), 'year') THEN
                'YES'
               ELSE
                'NO'
             END NEW_FSC,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.BUSINESSUNITNAME = 'BRUAGY'
         AND EXISTS
       (SELECT 1
                FROM CS_MEASUREMENT MEA, CS_PERIOD PER
               WHERE MEA.PERIODSEQ = PER.PERIODSEQ
                 AND PER.CALENDARSEQ = V_CALENDARSEQ
                 AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
                 AND PER.REMOVEDATE = C_REMOVEDATE
                 AND PER.STARTDATE BETWEEN
                     ADD_MONTHS(V_PRIOR_NOVEMBER_DATE, -11) AND
                     V_PRIOR_NOVEMBER_DATE
                 AND MEA.POSITIONSEQ = API.POSITIONSEQ
                 AND MEA.NAME IN ('PM_FYC_LF_RP',
                                  'PM_RYC_LF_Y2-6',
                                  'PM_RYC_Y2-6_LF_Assigned')
                 AND MEA.VALUE <> 0);
    ------Update ACT_MTH to MONTHLY_CB_PAYMENTS  
    UPDATE AIA_CAREER_BENEFIT_AGENT ACBA
       SET (ACBA.ACT_MTH,
            ACBA.MTH19_PERSISTENCY,
            --ACBA.TOTAL_FYC,
            ACBA.MEET_REQUIREMENT,
            --ACBA.TOTAL_RYC,
            ACBA.RATE,
            ACBA.CB_FOR_THE_YEAR,
            ACBA.MONTHLY_CB_PAYMENTS) =
           (SELECT NVL(SUM(CASE
                             WHEN MEA.NAME = 'SM_CB_Active_Month_BN' THEN
                              MEA.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN MEA.NAME = 'PM_LIMRA19_YTD' THEN
                              MEA.VALUE
                             ELSE
                              0
                           END),
                       0),
                   /*NVL(SUM(CASE
                         WHEN MEA.NAME = 'PM_FYC_LF_RP' THEN
                          MEA.VALUE
                         ELSE
                          0
                       END),
                   0),*/
                   NVL(MAX(CASE
                             WHEN MEA.NAME = 'SM_CB_Annually_BN' AND MEA.VALUE <> 0 THEN
                              'YES'
                             ELSE
                              'NO'
                           END),
                       'NO'),
                   /*NVL(SUM(CASE
                         WHEN MEA.NAME = 'PM_RYC_LF_Y2-6' THEN
                          MEA.VALUE
                         ELSE
                          0
                       END),
                   0) - NVL(SUM(CASE
                                  WHEN MEA.NAME = 'PM_RYC_Y2-6_LF_Assigned' THEN
                                   MEA.VALUE
                                  ELSE
                                   0
                                END),
                            0),*/
                   NVL(MAX(CASE
                             WHEN MEA.NAME = 'SM_CB_Annually_BN' THEN
                              NVL(MEA.GENERICNUMBER1, 0)
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN MEA.NAME = 'SM_CB_Annually_BN' THEN
                              MEA.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN MEA.NAME = 'SM_CB_Monthly_BN' THEN
                              MEA.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_MEASUREMENT MEA
             WHERE MEA.NAME IN ('SM_CB_Active_Month_BN',
                                'SM_CB_Annually_BN',
                                'SM_CB_Monthly_BN',
                                'PM_LIMRA19_YTD')
               AND MEA.PERIODSEQ = V_PRIOR_NOVEMBER_SEQ
               AND MEA.POSITIONSEQ = ACBA.POSITIONSEQ),
           (ACBA.TOTAL_FYC, ACBA.TOTAL_RYC) =
           (SELECT NVL(SUM(CASE
                             WHEN MEA.NAME = 'PM_FYC_LF_RP' THEN
                              MEA.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN MEA.NAME = 'PM_RYC_LF_Y2-6' THEN
                              MEA.VALUE
                             ELSE
                              0
                           END),
                       0) - NVL(SUM(CASE
                                      WHEN MEA.NAME = 'PM_RYC_Y2-6_LF_Assigned' THEN
                                       MEA.VALUE
                                      ELSE
                                       0
                                    END),
                                0)
              FROM CS_MEASUREMENT MEA, CS_PERIOD PER
             WHERE MEA.PERIODSEQ = PER.PERIODSEQ
               AND PER.CALENDARSEQ = V_CALENDARSEQ
               AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
               AND PER.REMOVEDATE = C_REMOVEDATE
               AND PER.STARTDATE BETWEEN ADD_MONTHS(V_PRIOR_NOVEMBER_DATE, -11) AND
                   V_PRIOR_NOVEMBER_DATE
               AND MEA.POSITIONSEQ = ACBA.POSITIONSEQ
               AND MEA.NAME IN
                   ('PM_FYC_LF_RP', 'PM_RYC_LF_Y2-6', 'PM_RYC_Y2-6_LF_Assigned')),
           ACBA.UPDATE_DATE = SYSDATE
     WHERE ACBA.PERIODSEQ = V_PERIODSEQ;
    ------Update Dec to November
    UPDATE AIA_CAREER_BENEFIT_AGENT ACBA
       SET (ACBA.DEC,
            ACBA.JAN,
            ACBA.FEB,
            ACBA.MAR,
            ACBA.APR,
            ACBA.MAY,
            ACBA.JUN,
            ACBA.JUL,
            ACBA.AUG,
            ACBA.SEP,
            ACBA.OCT,
            ACBA.NOV,
            ACBA.YEAR_TO_DATE) =
           (SELECT NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Dec' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Jan' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Feb' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Mar' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Apr' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'May' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Jun' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Jul' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Aug' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Sep' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Oct' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PER.SHORTNAME = 'Nov' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(INC.VALUE), 0)
              FROM CS_INCENTIVE INC, CS_PERIOD PER
             WHERE INC.NAME = 'I_Career_Benefit_BN'
               AND INC.PERIODSEQ = PER.PERIODSEQ
               AND INC.POSITIONSEQ = ACBA.POSITIONSEQ
               AND PER.CALENDARSEQ = V_CALENDARSEQ
               AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
               AND PER.REMOVEDATE = C_REMOVEDATE
               AND PER.STARTDATE BETWEEN ADD_MONTHS(V_PRIOR_NOVEMBER_DATE, 1) AND
                   V_PERIODSTARTDATE),
           ACBA.UPDATE_DATE = SYSDATE
     WHERE ACBA.PERIODSEQ = V_PERIODSEQ;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_AGEING_DETAIL_PROC IS
  BEGIN
    DELETE FROM AIA_AGEING_DETAIL T WHERE T.PERIODSEQ = V_PERIODSEQ;

    INSERT INTO AIA_AGEING_DETAIL
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       AGENCY_CODE,
       AGENT_NO,
       AGENT_NAME,
       AGENT_STATUS_CODE,
       BUSINESSUNITNAME,
       CHANNEL,
       CHANNELSORTSEQ,
       STATUS,
       STATUS2,
       STATUSSORTSEQ,
       STATUS2SORTSEQ,
       CURRENCY,
       CURRENCYSORTSEQ,
       CREATE_DATE)
      SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      API.PARTICIPANTSEQ,
                      API.POSITIONSEQ,
                      API.EFFECTIVESTARTDATE,
                      API.EFFECTIVEENDDATE,
                      API.MANAGERSEQ,
                      API.POSITIONNAME,
                      API.POSITIONTITLE,
                      API.GENERICATTRIBUTE2,
                      API.PARTICIPANTID,
                      API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                      API.GENERICATTRIBUTE9,
                      API.BUSINESSUNITNAME,
                      CASE
                        WHEN API.BUSINESSUNITNAME IN ('SGPAGY', 'BRUAGY') THEN
                         'Agency'
                        WHEN API.BUSINESSUNITNAME IN ('SGPPD', 'BRUPD') THEN
                         'Partnership'
                        ELSE
                         API.POSITIONTITLE
                      END, --Channel
                      CASE
                        WHEN API.BUSINESSUNITNAME IN ('SGPAGY', 'BRUAGY') THEN
                         '1'
                        WHEN API.BUSINESSUNITNAME IN ('SGPPD', 'BRUPD') THEN
                         'ZZZ'
                        ELSE
                         API.POSITIONTITLE
                      END, --Channel Sort Seq
                      CASE
                        WHEN API.BUSINESSUNITNAME IN ('SGPAGY', 'BRUAGY') THEN
                         CASE
                           WHEN API.GENERICATTRIBUTE9 = '00' THEN
                            'Active'
                           WHEN API.GENERICATTRIBUTE9 = '13' THEN
                            'Retired'
                           WHEN API.GENERICATTRIBUTE9 IN
                                ('50', '51', '52', '55', '56') THEN
                            'Terminated'
                           WHEN API.GENERICATTRIBUTE9 IN ('60', '61') THEN
                            'Vested'
                           WHEN API.GENERICATTRIBUTE9 = '70' THEN
                            'Deceased'
                           ELSE
                            ''
                         END
                        WHEN API.BUSINESSUNITNAME IN ('SGPPD', 'BRUPD') THEN
                         API.POSITIONTITLE
                        ELSE
                         ''
                      END, --Status
                      CASE
                        WHEN API.BUSINESSUNITNAME IN ('SGPAGY', 'BRUAGY') THEN
                         CASE
                           WHEN API.GENERICATTRIBUTE9 = '00' THEN
                            'Active'
                           WHEN API.GENERICATTRIBUTE9 = '13' THEN
                            'Retired'
                           WHEN API.GENERICATTRIBUTE9 IN
                                ('50', '51', '52', '55', '56') THEN
                            'Terminated'
                           WHEN API.GENERICATTRIBUTE9 IN ('60', '61') THEN
                            'Vested'
                           WHEN API.GENERICATTRIBUTE9 = '70' THEN
                            'Deceased'
                           ELSE
                            ''
                         END
                        ELSE
                         API.POSITIONTITLE
                      END, --Status2
                      CASE
                        WHEN API.BUSINESSUNITNAME IN ('SGPAGY', 'BRUAGY') THEN
                         CASE
                           WHEN API.GENERICATTRIBUTE9 = '00' THEN
                            '1'
                           WHEN API.GENERICATTRIBUTE9 = '13' THEN
                            '2'
                           WHEN API.GENERICATTRIBUTE9 IN
                                ('50', '51', '52', '55', '56') THEN
                            '3'
                           WHEN API.GENERICATTRIBUTE9 IN ('60', '61') THEN
                            '4'
                           WHEN API.GENERICATTRIBUTE9 = '70' THEN
                            '5'
                           ELSE
                            'ZZZ'
                         END
                        WHEN API.BUSINESSUNITNAME IN ('SGPPD', 'BRUPD') THEN
                         API.POSITIONTITLE
                        ELSE
                         'ZZZ'
                      END, --Status Sort Seq
                      CASE
                        WHEN API.BUSINESSUNITNAME IN ('SGPAGY', 'BRUAGY') THEN
                         CASE
                           WHEN API.GENERICATTRIBUTE9 = '00' THEN
                            '1'
                           WHEN API.GENERICATTRIBUTE9 = '13' THEN
                            '2'
                           WHEN API.GENERICATTRIBUTE9 IN
                                ('50', '51', '52', '55', '56') THEN
                            '3'
                           WHEN API.GENERICATTRIBUTE9 IN ('60', '61') THEN
                            '4'
                           WHEN API.GENERICATTRIBUTE9 = '70' THEN
                            '5'
                           ELSE
                            'ZZZ'
                         END
                        ELSE
                         API.POSITIONTITLE
                      END, --Status2 Sort Seq
                      AHDB.EARNINGGROUPID, --Currency
                      DECODE(AHDB.EARNINGGROUPID,
                             'SGD',
                             1,
                             ASCII(SUBSTR(AHDB.EARNINGGROUPID, 0, 1))), --Currency Sort Seq
                      SYSDATE
        FROM AIA_HELD_DEPOSIT_BALANCE AHDB, AIA_PAYEE_INFOR API
       WHERE AHDB.POSITIONSEQ = API.POSITIONSEQ
         AND AHDB.PERIODSEQ = V_PERIODSEQ;
    ------Update Months Pay Earning
    UPDATE AIA_AGEING_DETAIL AAD
       SET (AAD.MONTH_CURRENT,
            AAD.MONTHS_1_3,
            AAD.MONTHS_4_6,
            AAD.MONTHS_7_12,
            AAD.MONTHS_12,
            AAD.TOTAL) =
           (SELECT NVL(SUM(CASE
                             WHEN AHDB.PERIODSTARTDATE = V_PERIODSTARTDATE THEN
                              AHDB.VALUE
                             ELSE
                              0
                           END),
                       0) - NVL(SUM(CASE
                                      WHEN AHDB.PERIODSTARTDATE =
                                           ADD_MONTHS(V_PERIODSTARTDATE, -1) THEN
                                       AHDB.VALUE
                                      ELSE
                                       0
                                    END),
                                0),
                   NVL(SUM(CASE
                             WHEN AHDB.PERIODSTARTDATE =
                                  ADD_MONTHS(V_PERIODSTARTDATE, -1) THEN
                              AHDB.VALUE
                             ELSE
                              0
                           END),
                       0) - NVL(SUM(CASE
                                      WHEN AHDB.PERIODSTARTDATE =
                                           ADD_MONTHS(V_PERIODSTARTDATE, -4) THEN
                                       AHDB.VALUE
                                      ELSE
                                       0
                                    END),
                                0),
                   NVL(SUM(CASE
                             WHEN AHDB.PERIODSTARTDATE =
                                  ADD_MONTHS(V_PERIODSTARTDATE, -4) THEN
                              AHDB.VALUE
                             ELSE
                              0
                           END),
                       0) - NVL(SUM(CASE
                                      WHEN AHDB.PERIODSTARTDATE =
                                           ADD_MONTHS(V_PERIODSTARTDATE, -7) THEN
                                       AHDB.VALUE
                                      ELSE
                                       0
                                    END),
                                0),
                   NVL(SUM(CASE
                             WHEN AHDB.PERIODSTARTDATE =
                                  ADD_MONTHS(V_PERIODSTARTDATE, -7) THEN
                              AHDB.VALUE
                             ELSE
                              0
                           END),
                       0) - NVL(SUM(CASE
                                      WHEN AHDB.PERIODSTARTDATE =
                                           ADD_MONTHS(V_PERIODSTARTDATE, -12) THEN
                                       AHDB.VALUE
                                      ELSE
                                       0
                                    END),
                                0),
                   NVL(SUM(CASE
                             WHEN AHDB.PERIODSTARTDATE =
                                  ADD_MONTHS(V_PERIODSTARTDATE, -12) THEN
                              AHDB.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN AHDB.PERIODSTARTDATE = V_PERIODSTARTDATE THEN
                              AHDB.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_HELD_DEPOSIT_BALANCE AHDB
             WHERE AHDB.POSITIONSEQ = AAD.POSITIONSEQ
               AND AHDB.EARNINGGROUPID = AAD.CURRENCY
               AND AHDB.PERIODSTARTDATE IN
                   (V_PERIODSTARTDATE,
                    ADD_MONTHS(V_PERIODSTARTDATE, -1),
                    ADD_MONTHS(V_PERIODSTARTDATE, -4),
                    ADD_MONTHS(V_PERIODSTARTDATE, -7),
                    ADD_MONTHS(V_PERIODSTARTDATE, -12))),
           UPDATE_DATE = SYSDATE
     WHERE AAD.PERIODSEQ = V_PERIODSEQ;
  
  -----ADDED BY ZHUBIN DELETE THE AGENT WHOSE TOTAL BALANCE IS 0
     DELETE FROM AIA_AGEING_DETAIL AAD
     WHERE AAD.PERIODSEQ = V_PERIODSEQ
     AND AAD.TOTAL = 0;
  -----ADDED BY ZHUBIN 20140810
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_QTRLY_PROD_BONUS_PROC IS
    V_MTH1_PERIODSEQ  NUMBER(38);
    V_MTH1_PERIODNAME VARCHAR2(255);
    V_MTH2_PERIODSEQ  NUMBER(38);
    V_MTH2_PERIODNAME VARCHAR2(255);
    V_MTH3_PERIODSEQ  NUMBER(38);
    V_MTH3_PERIODNAME VARCHAR2(255);
  BEGIN
  
    DELETE FROM AIA_QTRLY_PROD_BONUS T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------Get Month1 Month2 Month3 Seq and Name
    SELECT PER.PERIODSEQ, PER.SHORTNAME
      INTO V_MTH1_PERIODSEQ, V_MTH1_PERIODNAME
      FROM CS_PERIOD PER
     WHERE PER.CALENDARSEQ = V_CALENDARSEQ
       AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
       AND PER.REMOVEDATE = C_REMOVEDATE
       AND PER.STARTDATE =
           ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'Q'), -1);
    SELECT PER.PERIODSEQ, PER.SHORTNAME
      INTO V_MTH2_PERIODSEQ, V_MTH2_PERIODNAME
      FROM CS_PERIOD PER
     WHERE PER.CALENDARSEQ = V_CALENDARSEQ
       AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
       AND PER.REMOVEDATE = C_REMOVEDATE
       AND PER.STARTDATE = TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'Q');
    SELECT PER.PERIODSEQ, PER.SHORTNAME
      INTO V_MTH3_PERIODSEQ, V_MTH3_PERIODNAME
      FROM CS_PERIOD PER
     WHERE PER.CALENDARSEQ = V_CALENDARSEQ
       AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
       AND PER.REMOVEDATE = C_REMOVEDATE
       AND PER.STARTDATE =
           ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'Q'), 1);
    ------Insert data
    INSERT INTO AIA_QTRLY_PROD_BONUS
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       MTH1_PERIODSEQ,
       MTH1_PERIODNAME,
       MTH2_PERIODSEQ,
       MTH2_PERIODNAME,
       MTH3_PERIODSEQ,
       MTH3_PERIODNAME,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       DISTRICT_CODE,
       UNIT_CODE,
       FSC_CODE,
       FSC_NAME,
       FSC_CLASS,
       AGENT_STATUS_CODE,
       CONTRACT_DATE,
       TERMINATION_DATE,
       LDR_CODE,
       LDR_NAME,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             V_MTH1_PERIODSEQ,
             V_MTH1_PERIODNAME,
             V_MTH2_PERIODSEQ,
             V_MTH2_PERIODNAME,
             V_MTH3_PERIODSEQ,
             V_MTH3_PERIODNAME,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             API.GENERICATTRIBUTE6,
             API.GENERICATTRIBUTE2,
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE8,
             API.GENERICATTRIBUTE1,
             API.HIREDATE,
             API.TERMINATIONDATE,
             API.GENERICATTRIBUTE4,
             API.GENERICATTRIBUTE5,
             SYSDATE
        FROM AIA_PAYEE_INFOR API
       WHERE API.BUSINESSUNITNAME = 'BRUAGY'
         AND API.POSITIONTITLE IN ('BR_DM', 'BR_UM', 'BR_FSC');
    ------Update Leader Information
    UPDATE AIA_QTRLY_PROD_BONUS AQPB
       SET (AQPB.LDR_CLASS,
            AQPB.LDR_CONTRACT_DATE,
            AQPB.LDR_AGENT_STATUS_CODE,
            AQPB.LDR_TERMINATION_DATE) =
           (SELECT API.GENERICATTRIBUTE8,
                   API.HIREDATE,
                   API.GENERICATTRIBUTE1,
                   API.TERMINATIONDATE
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AQPB.LDR_CODE
               AND API.POSITIONTITLE IN ('BR_DM', 'BR_UM', 'BR_FSC')
               AND API.BUSINESSUNITNAME = 'BRUAGY'
               AND API.POSITIONNAME LIKE '%T%'
               AND ROWNUM = 1)
     WHERE AQPB.PERIODSEQ = V_PERIODSEQ;
    ------Update Month data
    UPDATE AIA_QTRLY_PROD_BONUS AQPB
       SET (AQPB.MTH1_LIFE_FYC,
            AQPB.MTH1_AH_FYC,
            AQPB.MTH1_GROUP_FYC,
            AQPB.MTH1_LIFE_RIDER_FYC,
            AQPB.MTH1_TOTAL_FYC_LF_RDR,
            AQPB.MTH1_TOTAL_FYC_LF) =
           (SELECT NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS')
                             -----modified by zhubin 20140811
                                  THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 = 'PA' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 IN ('CS', 'CL') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS') AND
                             -----modified by zhubin 20140811
                                  CRD.GENERICBOOLEAN4 = 1 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 = 'PA' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0) + NVL(SUM(CASE
                                      WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                               -----modified by zhubin add the product type 'CS' for APB
                                    --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                    CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS') AND
                               -----modified by zhubin 20140811
                                           CRD.GENERICBOOLEAN4 = 1 THEN
                                       CRD.VALUE
                                      ELSE
                                       0
                                    END),
                                0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS') THEN
                             -----modified by zhubin 20140811
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0) + NVL(SUM(CASE
                                      WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                           CRD.GENERICATTRIBUTE2 = 'PA' THEN
                                       CRD.VALUE
                                      ELSE
                                       0
                                    END),
                                0) + NVL(SUM(CASE
                                               WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                                    CRD.GENERICATTRIBUTE2 IN ('CS', 'CL') THEN
                                                CRD.VALUE
                                               ELSE
                                                0
                                             END),
                                         0)
              FROM CS_CREDIT CRD, CS_CREDITTYPE CRDT
             WHERE CRD.PERIODSEQ = V_MTH1_PERIODSEQ
               AND CRD.POSITIONSEQ = AQPB.POSITIONSEQ
               AND CRD.CREDITTYPESEQ = CRDT.DATATYPESEQ
               AND CRDT.REMOVEDATE = C_REMOVEDATE
               AND CRDT.CREDITTYPEID IN ('FYC', 'APB')),
           (AQPB.MTH2_LIFE_FYC,
            AQPB.MTH2_AH_FYC,
            AQPB.MTH2_GROUP_FYC,
            AQPB.MTH2_LIFE_RIDER_FYC,
            AQPB.MTH2_TOTAL_FYC_LF_RDR,
            AQPB.MTH2_TOTAL_FYC_LF) =
           (SELECT NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS')
                             -----modified by zhubin 20140811
                                  THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 = 'PA' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 IN ('CS', 'CL') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS') AND
                             -----modified by zhubin 20140811
                                  CRD.GENERICBOOLEAN4 = 1 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 = 'PA' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0) + NVL(SUM(CASE
                                      WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                                      -----modified by zhubin add the product type 'CS' for APB
                                      --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                           CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS') AND
                                      -----modified by zhubin 20140811
                                           CRD.GENERICBOOLEAN4 = 1 THEN
                                       CRD.VALUE
                                      ELSE
                                       0
                                    END),
                                0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS') THEN
                             -----modified by zhubin 20140811
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0) + NVL(SUM(CASE
                                      WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                           CRD.GENERICATTRIBUTE2 = 'PA' THEN
                                       CRD.VALUE
                                      ELSE
                                       0
                                    END),
                                0) + NVL(SUM(CASE
                                               WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                                    CRD.GENERICATTRIBUTE2 IN ('CS', 'CL') THEN
                                                CRD.VALUE
                                               ELSE
                                                0
                                             END),
                                         0)
              FROM CS_CREDIT CRD, CS_CREDITTYPE CRDT
             WHERE CRD.PERIODSEQ = V_MTH2_PERIODSEQ
               AND CRD.POSITIONSEQ = AQPB.POSITIONSEQ
               AND CRD.CREDITTYPESEQ = CRDT.DATATYPESEQ
               AND CRDT.REMOVEDATE = C_REMOVEDATE
               AND CRDT.CREDITTYPEID IN ('FYC', 'APB')),
           (AQPB.MTH3_LIFE_FYC,
            AQPB.MTH3_AH_FYC,
            AQPB.MTH3_GROUP_FYC,
            AQPB.MTH3_LIFE_RIDER_FYC,
            AQPB.MTH3_TOTAL_FYC_LF_RDR,
            AQPB.MTH3_TOTAL_FYC_LF) =
           (SELECT NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS')
                             -----modified by zhubin 20140811
                                  THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 = 'PA' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 IN ('CS', 'CL') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS') AND
                             -----modified by zhubin 20140811
                                  CRD.GENERICBOOLEAN4 = 1 THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                  CRD.GENERICATTRIBUTE2 = 'PA' THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0) + NVL(SUM(CASE
                                      WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                                      -----modified by zhubin add the product type 'CS' for APB
                                           --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                           CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS') AND
                                      -----modified by zhubin 20140811
                                           CRD.GENERICBOOLEAN4 = 1 THEN
                                       CRD.VALUE
                                      ELSE
                                       0
                                    END),
                                0),
                   NVL(SUM(CASE
                             WHEN CRDT.CREDITTYPEID IN ('FYC', 'APB') AND
                             -----modified by zhubin add the product type 'CS' for APB
                                  --CRD.GENERICATTRIBUTE2 IN ('LF', 'HS')
                                  CRD.GENERICATTRIBUTE2 IN ('LF', 'HS', 'CS')
                             -----modified by zhubin 20140811
                                  THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0) + NVL(SUM(CASE
                                      WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                           CRD.GENERICATTRIBUTE2 = 'PA' THEN
                                       CRD.VALUE
                                      ELSE
                                       0
                                    END),
                                0) + NVL(SUM(CASE
                                               WHEN CRDT.CREDITTYPEID = 'FYC' AND
                                                    CRD.GENERICATTRIBUTE2 IN ('CS', 'CL') THEN
                                                CRD.VALUE
                                               ELSE
                                                0
                                             END),
                                         0)
              FROM CS_CREDIT CRD, CS_CREDITTYPE CRDT
             WHERE CRD.PERIODSEQ = V_MTH3_PERIODSEQ
               AND CRD.POSITIONSEQ = AQPB.POSITIONSEQ
               AND CRD.CREDITTYPESEQ = CRDT.DATATYPESEQ
               AND CRDT.REMOVEDATE = C_REMOVEDATE
               AND CRDT.CREDITTYPEID IN ('FYC', 'APB')),
           (AQPB.BONUS_OF_RIDER_QTR_FYC,
            AQPB.QTRLY_RIDER_PB,
            AQPB.BONUS_OF_QTR_TOTAL_FYC,
            AQPB.QTRLY_PB) =
           (SELECT NVL(SUM(CASE
                             WHEN INC.NAME = 'I_QPB_Rider' THEN
                              INC.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INC.NAME = 'I_QPB_Rider' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INC.NAME = 'I_QPB_BN' THEN
                              INC.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INC.NAME = 'I_QPB_BN' THEN
                              INC.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_INCENTIVE INC
             WHERE INC.PERIODSEQ = AQPB.PERIODSEQ
               AND INC.POSITIONSEQ = AQPB.POSITIONSEQ
               AND INC.NAME IN ('I_QPB_Rider', 'I_QPB_BN')),
           UPDATE_DATE = SYSDATE
     WHERE AQPB.PERIODSEQ = V_PERIODSEQ;
    ------Update Quater data
    UPDATE AIA_QTRLY_PROD_BONUS AQPB
       SET AQPB.QTR_LIFE_FYC         = AQPB.MTH1_LIFE_FYC + AQPB.MTH2_LIFE_FYC +
                                       AQPB.MTH3_LIFE_FYC,
           AQPB.QTR_AH_FYC           = AQPB.MTH1_AH_FYC + AQPB.MTH2_AH_FYC +
                                       AQPB.MTH3_AH_FYC,
           AQPB.QTR_GROUP_FYC        = AQPB.MTH1_GROUP_FYC + AQPB.MTH2_GROUP_FYC +
                                       AQPB.MTH3_GROUP_FYC,
           AQPB.QTR_LIFE_RIDER_FYC   = AQPB.MTH1_LIFE_RIDER_FYC +
                                       AQPB.MTH2_LIFE_RIDER_FYC +
                                       AQPB.MTH3_LIFE_RIDER_FYC,
           AQPB.QTR_TOTAL_FYC_LF_RDR = AQPB.MTH1_TOTAL_FYC_LF_RDR +
                                       AQPB.MTH2_TOTAL_FYC_LF_RDR +
                                       AQPB.MTH3_TOTAL_FYC_LF_RDR,
           AQPB.QTR_TOTAL_FYC_LF     = AQPB.MTH1_TOTAL_FYC_LF +
                                       AQPB.MTH2_TOTAL_FYC_LF +
                                       AQPB.MTH3_TOTAL_FYC_LF,
           UPDATE_DATE               = SYSDATE
     WHERE AQPB.PERIODSEQ = V_PERIODSEQ;
    ------Year to Date data
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) > 0 THEN
      UPDATE AIA_QTRLY_PROD_BONUS AQPB
         SET (AQPB.YEAR_QTRLY_RIDER_PB, AQPB.YEAR_QTRLY_PB) =
             (SELECT AQPB.QTRLY_RIDER_PB + NVL(MAX(T.YEAR_QTRLY_RIDER_PB), 0),
                     AQPB.QTRLY_PB + NVL(MAX(T.YEAR_QTRLY_PB), 0)
                FROM AIA_QTRLY_PROD_BONUS T
               WHERE T.PERIODSEQ = V_PRIOR_PERIODSEQ
                 AND T.POSITIONSEQ = AQPB.POSITIONSEQ),
             UPDATE_DATE = SYSDATE
       WHERE AQPB.PERIODSEQ = V_PERIODSEQ;
    ELSE
      UPDATE AIA_QTRLY_PROD_BONUS AQPB
         SET AQPB.YEAR_QTRLY_RIDER_PB = AQPB.QTRLY_RIDER_PB,
             AQPB.YEAR_QTRLY_PB       = AQPB.QTRLY_PB,
             UPDATE_DATE              = SYSDATE
       WHERE AQPB.PERIODSEQ = V_PERIODSEQ;
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_INDIRECT_OVERRIDE_PROC IS
  BEGIN
  
    DELETE FROM AIA_INDIRECT_OVERRIDE_LEADER T WHERE T.PERIODSEQ = V_PERIODSEQ;
    DELETE FROM AIA_INDIRECT_OVERRIDE_AGENT T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------All Leader Agents with last version in current period
    INSERT INTO AIA_INDIRECT_OVERRIDE_LEADER
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       LAST_DATE,
       LDR_UNIT,
       LDR_CODE,
       LDR_NAME,
       LDR_CLASS,
       SM_UNIT,
       SM_CODE,
       SM_NAME,
       SM_CLASS,
       AGENT_STATUS_CODE,
       TERMINATION_DATE,
       IO_TOTAL,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.MANAGERSEQ,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             V_PERIODENDDATE - 1,
             API.GENERICATTRIBUTE2,
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE8,
             API.GENERICATTRIBUTE2,
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE8,
             API.GENERICATTRIBUTE1,
             API.TERMINATIONDATE,
             DEP.VALUE,
             SYSDATE
        FROM AIA_PAYEE_INFOR API, CS_DEPOSIT DEP
       WHERE API.BUSINESSUNITNAME = 'BRUAGY'
         AND DEP.PERIODSEQ = V_PERIODSEQ
         AND DEP.POSITIONSEQ = API.POSITIONSEQ
         AND DEP.NAME = 'D_Indirect_Override_BN';
    ------Insert Contribute Agents' Records
    INSERT INTO AIA_INDIRECT_OVERRIDE_AGENT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       POSITIONNAME,
       POSITIONTITLE,
       MANAGERSEQ,
       LAST_DATE,
       LDR_UNIT,
       LDR_CODE,
       LDR_NAME,
       LDR_CLASS,
       ------Contribute Agent
       SM_UNIT,
       SM_CODE,
       SM_NAME,
       SM_CLASS,
       AGENT_STATUS_CODE,
       TERMINATION_DATE,
       DO_TOTAL,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             AIOL.POSITIONSEQ, --MANAGERSEQ
             AIOL.LAST_DATE,
             AIOL.LDR_UNIT,
             AIOL.LDR_CODE,
             AIOL.LDR_NAME,
             AIOL.LDR_CLASS,
             ------Contribute Agent
             API.GENERICATTRIBUTE2,
             API.PARTICIPANTID,
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
             API.GENERICATTRIBUTE8,
             API.GENERICATTRIBUTE1,
             API.TERMINATIONDATE,
             NVL(SUM(ADTI.INCENTIVEVALUE), 0),
             SYSDATE
        FROM AIA_INDIRECT_OVERRIDE_LEADER AIOL,
             AIA_DEPOSIT_TRACE_INFOR      ADTI,
             AIA_PAYEE_INFOR              API
       WHERE AIOL.POSITIONSEQ = ADTI.POSITIONSEQ
         AND AIOL.PERIODSEQ = ADTI.PERIODSEQ
         AND ADTI.GENERICATTRIBUTE1 = API.PARTICIPANTSEQ
         AND AIOL.PERIODSEQ = V_PERIODSEQ
         AND ADTI.TRACELEVEL = 'Incentive Level'
         AND ADTI.DEPOSITNAME = 'D_Indirect_Override_BN'
       GROUP BY AIOL.POSITIONSEQ,
                AIOL.LAST_DATE,
                AIOL.LDR_UNIT,
                AIOL.LDR_CODE,
                AIOL.LDR_NAME,
                AIOL.LDR_CLASS,
                ------Contribute Agent
                API.PARTICIPANTSEQ,
                API.POSITIONSEQ,
                API.EFFECTIVESTARTDATE,
                API.EFFECTIVEENDDATE,
                API.POSITIONNAME,
                API.POSITIONTITLE,
                API.GENERICATTRIBUTE2,
                API.PARTICIPANTID,
                API.FIRSTNAME,
                API.MIDDLENAME,
                API.LASTNAME,
                API.GENERICATTRIBUTE8,
                API.GENERICATTRIBUTE1,
                API.TERMINATIONDATE;
    ------Update DO data
    UPDATE AIA_INDIRECT_OVERRIDE_AGENT AIOA
       SET (AIOA.DO_BASE, AIOA.DO_NEW, AIOA.DO_QTR) =
           (SELECT NVL(SUM(CASE
                             WHEN ADTI.SMEASUREMENTNAME = 'SM_DO_Base_BN' THEN
                              ADTI.SMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.SMEASUREMENTNAME = 'SM_DO_New_Agent_BN' THEN
                              ADTI.SMEASUREMENTVALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN ADTI.SMEASUREMENTNAME = 'PM_DO_QTR_BN' THEN
                              ADTI.SMEASUREMENTVALUE * NVL(ADTI.GENERICNUMBER7, 0)
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_DEPOSIT_TRACE_INFOR ADTI
             WHERE ADTI.PERIODSEQ = AIOA.PERIODSEQ
               AND ADTI.POSITIONSEQ = AIOA.POSITIONSEQ
               AND ADTI.DEPOSITNAME = 'D_Indirect_Override_BN'
               AND ADTI.SMEASUREMENTNAME IN
                   ('SM_DO_Base_BN', 'SM_DO_New_Agent_BN', 'PM_DO_QTR_BN')
               AND ADTI.TRACELEVEL = 'Measurement Level'),
           AIOA.IO_TOTAL = AIOA.DO_TOTAL *
                           (SELECT NVL(MAX(INC.GENERICNUMBER1), 0)
                              FROM CS_INCENTIVE INC
                             WHERE INC.PERIODSEQ = AIOA.PERIODSEQ
                               AND INC.POSITIONSEQ = AIOA.MANAGERSEQ
                               AND INC.NAME = 'I_Indirect_Override_BN'),
           UPDATE_DATE = SYSDATE
     WHERE AIOA.PERIODSEQ = V_PERIODSEQ;
  
    ------Update Leader data
    UPDATE AIA_INDIRECT_OVERRIDE_LEADER AIOL
       SET (AIOL.DO_BASE, AIOL.DO_NEW, AIOL.DO_QTR, AIOL.DO_TOTAL) =
           (SELECT NVL(SUM(AIOA.DO_BASE), 0),
                   NVL(SUM(AIOA.DO_NEW), 0),
                   NVL(SUM(AIOA.DO_QTR), 0),
                   NVL(SUM(AIOA.DO_TOTAL), 0)
              FROM AIA_INDIRECT_OVERRIDE_AGENT AIOA
             WHERE AIOA.PERIODSEQ = AIOL.PERIODSEQ
               AND AIOA.LDR_CODE = AIOL.LDR_CODE),
           /*AIOL.DO_TOTAL =
           (SELECT NVL(SUM(INC.VALUE), 0)
              FROM CS_DEPOSIT               DEP,
                   CS_DEPOSITINCENTIVETRACE DEPI,
                   CS_INCENTIVESELFTRACE    INCT,
                   CS_INCENTIVE             INC
             WHERE DEP.PERIODSEQ = V_PERIODSEQ
               AND DEP.NAME = 'D_Indirect_Override_BN'
               AND DEP.DEPOSITSEQ = DEPI.DEPOSITSEQ
               AND DEPI.INCENTIVESEQ = INCT.TARGETINCENTIVESEQ
               AND INCT.SOURCEINCENTIVESEQ = INC.INCENTIVESEQ
               AND INC.NAME = 'I_Direct_Override_Indirect_Team_BN'
               AND INC.POSITIONSEQ = AIOL.POSITIONSEQ),*/
           UPDATE_DATE = SYSDATE
     WHERE AIOL.PERIODSEQ = V_PERIODSEQ;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_AOR_PROC IS
  BEGIN
    ------Include DM Payee and UM Payee
    DELETE FROM AIA_AOR T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------Insert DM Payee
    INSERT INTO AIA_AOR
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       DISTRICT_CODE,
       DISTRICT_NAME,
       DM_CODE,
       DM_NAME,
       UNIT_CODE,
       FSC_AGT_CODE,
       CREATE_DATE)
      SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      API.PARTICIPANTID,
                      API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                      API.GENERICATTRIBUTE4,
                      API.GENERICATTRIBUTE5,
                      CRD.GENERICATTRIBUTE13,
                      CRD.GENERICATTRIBUTE12,
                      SYSDATE
        FROM CS_CREDIT CRD, AIA_PAYEE_INFOR API
       WHERE CRD.POSITIONSEQ = API.POSITIONSEQ
         AND CRD.PERIODSEQ = V_PERIODSEQ
         AND CRD.NAME IN ('C_AOR_PIB_Crossover_SG',
                          'C_AOR_RYC_Crossover_SG',
                          'C_AOR_PIB_Indirect_Team_SG',
                          'C_AOR_RYC_Indirect_Team_SG',
                          'C_AOR_PIB_Direct_Team_SG',
                          'C_AOR_RYC_Direct_Team_SG')
         AND CRD.VALUE <> 0
         AND API.BUSINESSUNITNAME = 'SGPAGY'
         AND API.POSITIONTITLE = 'DISTRICT';
    ------Update DM/UM/FSC Detail
    UPDATE AIA_AOR AA
       SET (AA.MTH_PIB, AA.MTH_RENEWAL_COMM) =
           (SELECT NVL(SUM(CASE
                             WHEN CRD.NAME IN ('C_AOR_PIB_Crossover_SG',
                                               'C_AOR_PIB_Indirect_Team_SG',
                                               'C_AOR_PIB_Direct_Team_SG') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.NAME IN ('C_AOR_RYC_Crossover_SG',
                                               'C_AOR_RYC_Indirect_Team_SG',
                                               'C_AOR_RYC_Direct_Team_SG') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_CREDIT CRD, AIA_PAYEE_INFOR API
             WHERE CRD.PERIODSEQ = AA.PERIODSEQ
               AND CRD.POSITIONSEQ = API.POSITIONSEQ
               AND API.PARTICIPANTID = AA.DISTRICT_CODE
               AND CRD.GENERICATTRIBUTE12 = AA.FSC_AGT_CODE
               AND CRD.NAME IN ('C_AOR_PIB_Crossover_SG',
                                'C_AOR_RYC_Crossover_SG',
                                'C_AOR_PIB_Indirect_Team_SG',
                                'C_AOR_RYC_Indirect_Team_SG',
                                'C_AOR_PIB_Direct_Team_SG',
                                'C_AOR_RYC_Direct_Team_SG')
               AND CRD.VALUE <> 0),
           (AA.PARTICIPANTSEQ,
            AA.POSITIONSEQ,
            AA.EFFECTIVESTARTDATE,
            AA.EFFECTIVEENDDATE,
            AA.MANAGERSEQ,
            AA.POSITIONNAME,
            AA.POSITIONTITLE) =
           (SELECT API.PARTICIPANTSEQ,
                   API.POSITIONSEQ,
                   API.EFFECTIVESTARTDATE,
                   API.EFFECTIVEENDDATE,
                   API.MANAGERSEQ,
                   API.POSITIONNAME,
                   API.POSITIONTITLE
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AA.DM_CODE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND API.POSITIONNAME LIKE '%T%' ------Modified by Chao 20140812
               AND ROWNUM = 1),
           (AA.AGENCY,
            AA.UM_CODE,
            AA.UM_NAME,
            AA.AGENCY_DISSOLVED_DATE,
            AA.ROLE) =
           (SELECT API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                   API.GENERICATTRIBUTE4,
                   API.GENERICATTRIBUTE5,
                   API.TERMINATIONDATE,
                   API.GENERICATTRIBUTE10
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AA.UNIT_CODE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND API.POSITIONNAME LIKE '%Y%' ------Modified by Chao 20140812
               AND ROWNUM = 1),
           (AA.CROSSOVER_DATE) =
           (SELECT API.GENERICDATE7
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AA.UM_CODE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND API.POSITIONNAME LIKE '%T%' ------Modified by Chao 20140812
               AND ROWNUM = 1),
           (AA.FSC_NAME, AA.TERMINATION_DATE, AA.CLASS) =
           (SELECT API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                   API.TERMINATIONDATE,
                   API.GENERICATTRIBUTE8
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AA.FSC_AGT_CODE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND API.POSITIONNAME LIKE '%T%' ------MODified by chao 20140812
               AND ROWNUM = 1),
           UPDATE_DATE = SYSDATE
     WHERE AA.PERIODSEQ = V_PERIODSEQ;
    ------Insert UM Payee
    INSERT INTO AIA_AOR
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       --DISTRICT_CODE,
       --DISTRICT_NAME,
       --DM_CODE,
       --DM_NAME,
       UNIT_CODE,
       AGENCY,
       UM_CODE,
       UM_NAME,
       CROSSOVER_DATE,
       AGENCY_DISSOLVED_DATE,
       ROLE,
       FSC_AGT_CODE,
       CREATE_DATE)
      SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      API.PARTICIPANTID,
                      API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                      API.GENERICATTRIBUTE4,
                      API.GENERICATTRIBUTE5,
                      API.GENERICDATE7,
                      API.TERMINATIONDATE,
                      API.GENERICATTRIBUTE10,
                      CRD.GENERICATTRIBUTE12,
                      SYSDATE
        FROM CS_CREDIT CRD, AIA_PAYEE_INFOR API
       WHERE CRD.POSITIONSEQ = API.POSITIONSEQ
         AND CRD.PERIODSEQ = V_PERIODSEQ
         AND CRD.NAME IN ('C_AOR_PIB_Crossover_SG',
                          'C_AOR_RYC_Crossover_SG',
                          'C_AOR_PIB_Indirect_Team_SG',
                          'C_AOR_RYC_Indirect_Team_SG',
                          'C_AOR_PIB_Direct_Team_SG',
                          'C_AOR_RYC_Direct_Team_SG')
         AND CRD.VALUE <> 0
         AND API.BUSINESSUNITNAME = 'SGPAGY'
         AND API.POSITIONTITLE = 'AGENCY';
    ------Update UM/FSC Detail
    UPDATE AIA_AOR AA
       SET (AA.MTH_PIB, AA.MTH_RENEWAL_COMM) =
           (SELECT NVL(SUM(CASE
                             WHEN CRD.NAME IN ('C_AOR_PIB_Crossover_SG',
                                               'C_AOR_PIB_Indirect_Team_SG',
                                               'C_AOR_PIB_Direct_Team_SG') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRD.NAME IN ('C_AOR_RYC_Crossover_SG',
                                               'C_AOR_RYC_Indirect_Team_SG',
                                               'C_AOR_RYC_Direct_Team_SG') THEN
                              CRD.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CS_CREDIT CRD, AIA_PAYEE_INFOR API
             WHERE CRD.PERIODSEQ = AA.PERIODSEQ
               AND CRD.POSITIONSEQ = API.POSITIONSEQ
               AND API.PARTICIPANTID = AA.UNIT_CODE
               AND CRD.GENERICATTRIBUTE12 = AA.FSC_AGT_CODE
               AND CRD.NAME IN ('C_AOR_PIB_Crossover_SG',
                                'C_AOR_RYC_Crossover_SG',
                                'C_AOR_PIB_Indirect_Team_SG',
                                'C_AOR_RYC_Indirect_Team_SG',
                                'C_AOR_PIB_Direct_Team_SG',
                                'C_AOR_RYC_Direct_Team_SG')
               AND CRD.VALUE <> 0),
           (AA.PARTICIPANTSEQ,
            AA.POSITIONSEQ,
            AA.EFFECTIVESTARTDATE,
            AA.EFFECTIVEENDDATE,
            AA.MANAGERSEQ,
            AA.POSITIONNAME,
            AA.POSITIONTITLE,
            AA.CROSSOVER_DATE) =
           (SELECT API.PARTICIPANTSEQ,
                   API.POSITIONSEQ,
                   API.EFFECTIVESTARTDATE,
                   API.EFFECTIVEENDDATE,
                   API.MANAGERSEQ,
                   API.POSITIONNAME,
                   API.POSITIONTITLE,
                   API.GENERICDATE7
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AA.UM_CODE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND API.POSITIONNAME LIKE '%T%' ------Modified by Chao 20140812
               AND ROWNUM = 1),
           (AA.AGENCY,
            AA.UM_CODE,
            AA.UM_NAME,
            AA.AGENCY_DISSOLVED_DATE,
            AA.ROLE) =
           (SELECT API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                   API.GENERICATTRIBUTE4,
                   API.GENERICATTRIBUTE5,
                   API.TERMINATIONDATE,
                   API.GENERICATTRIBUTE10
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AA.UNIT_CODE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND API.POSITIONNAME LIKE '%Y%' ------Modified by Chao 20140812
               AND ROWNUM = 1),
           (AA.FSC_NAME, AA.TERMINATION_DATE, AA.CLASS) =
           (SELECT API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME,
                   API.TERMINATIONDATE,
                   API.GENERICATTRIBUTE8
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AA.FSC_AGT_CODE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND API.POSITIONNAME LIKE '%T%' ------Modified by Chao 20140812
               AND ROWNUM = 1),
           UPDATE_DATE = SYSDATE
     WHERE AA.PERIODSEQ = V_PERIODSEQ
       AND AA.DM_CODE IS NULL;
    --Update YTD Data
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) > 0 THEN
      UPDATE AIA_AOR AA
         SET (AA.YTD_PIB, AA.YTD_RENEWAL_COMM) =
             (SELECT NVL(SUM(T.YTD_PIB), 0) + AA.MTH_PIB,
                     NVL(SUM(T.YTD_RENEWAL_COMM), 0) + AA.MTH_RENEWAL_COMM
                FROM AIA_AOR T
               WHERE T.POSITIONSEQ = AA.POSITIONSEQ
                 AND T.PERIODSEQ = V_PRIOR_PERIODSEQ
                 AND T.FSC_AGT_CODE = AA.FSC_AGT_CODE),
             UPDATE_DATE = SYSDATE
       WHERE AA.PERIODSEQ = V_PERIODSEQ;
    ELSE
      UPDATE AIA_AOR AA
         SET AA.YTD_PIB          = AA.MTH_PIB,
             AA.YTD_RENEWAL_COMM = AA.MTH_RENEWAL_COMM,
             UPDATE_DATE         = SYSDATE
       WHERE AA.PERIODSEQ = V_PERIODSEQ;
    END IF;
    ------Update YTD_AOR Field
    UPDATE AIA_AOR AA
       SET (AA.YTD_PIB_AOR, AA.YTD_REN_COMM_AOR) =
           (SELECT NVL(MAX(MEA.GENERICNUMBER1), 0) * AA.YTD_PIB,
                   NVL(MAX(MEA.GENERICNUMBER2), 0) * AA.YTD_RENEWAL_COMM
              FROM CS_MEASUREMENT MEA
             WHERE MEA.NAME = 'SM_AOR_DM_Annual_SG'
               AND MEA.PERIODSEQ = V_PERIODSEQ
               AND MEA.POSITIONSEQ = AA.POSITIONSEQ),
           UPDATE_DATE = SYSDATE
     WHERE AA.PERIODSEQ = V_PERIODSEQ;
    ------Update AOR Total Field
    UPDATE AIA_AOR AA
       SET AA.TOTAL_AOR = AA.YTD_PIB_AOR + AA.YTD_REN_COMM_AOR,
           UPDATE_DATE  = SYSDATE
     WHERE AA.PERIODSEQ = V_PERIODSEQ;
    ------Insert Last Period YTD Record
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) > 0 THEN
      INSERT INTO AIA_AOR
        (PERIODSEQ,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         PARTICIPANTSEQ,
         POSITIONSEQ,
         EFFECTIVESTARTDATE,
         EFFECTIVEENDDATE,
         MANAGERSEQ,
         POSITIONNAME,
         POSITIONTITLE,
         DISTRICT_CODE,
         DISTRICT_NAME,
         DM_CODE,
         DM_NAME,
         UNIT_CODE,
         AGENCY,
         UM_CODE,
         UM_NAME,
         CROSSOVER_DATE,
         AGENCY_DISSOLVED_DATE,
         ROLE,
         FSC_AGT_CODE,
         FSC_NAME,
         TERMINATION_DATE,
         CLASS,
         MTH_PIB,
         YTD_PIB,
         YTD_PIB_AOR,
         MTH_RENEWAL_COMM,
         YTD_RENEWAL_COMM,
         YTD_REN_COMM_AOR,
         TOTAL_AOR,
         CREATE_DATE)
        SELECT V_PERIODSEQ,
               V_CALENDARNAME,
               V_PERIODNAME,
               V_PERIODSTARTDATE,
               V_PERIODENDDATE,
               AA.PARTICIPANTSEQ,
               AA.POSITIONSEQ,
               AA.EFFECTIVESTARTDATE,
               AA.EFFECTIVEENDDATE,
               AA.MANAGERSEQ,
               AA.POSITIONNAME,
               AA.POSITIONTITLE,
               AA.DISTRICT_CODE,
               AA.DISTRICT_NAME,
               AA.DM_CODE,
               AA.DM_NAME,
               AA.UNIT_CODE,
               AA.AGENCY,
               AA.UM_CODE,
               AA.UM_NAME,
               AA.CROSSOVER_DATE,
               AA.AGENCY_DISSOLVED_DATE,
               AA.ROLE,
               AA.FSC_AGT_CODE,
               AA.FSC_NAME,
               AA.TERMINATION_DATE,
               AA.CLASS,
               AA.MTH_PIB,
               AA.YTD_PIB,
               AA.YTD_PIB_AOR,
               AA.MTH_RENEWAL_COMM,
               AA.YTD_RENEWAL_COMM,
               AA.YTD_REN_COMM_AOR,
               AA.TOTAL_AOR,
               SYSDATE
          FROM AIA_AOR AA
         WHERE AA.PERIODSEQ = V_PRIOR_PERIODSEQ
           AND NOT EXISTS
         (SELECT 1
                  FROM AIA_AOR T
                 WHERE T.PERIODSEQ = V_PERIODSEQ
                   AND (T.DM_CODE = AA.DM_CODE OR T.UM_CODE = AA.UM_CODE)
                   AND T.FSC_AGT_CODE = AA.FSC_AGT_CODE);
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;
  PROCEDURE AIA_AOR_UNIT_PROC IS
  BEGIN
    DELETE FROM AIA_AOR_UNIT T WHERE T.PERIODSEQ = V_PERIODSEQ;
    INSERT INTO AIA_AOR_UNIT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PERIODYEAR,
       PERIODMONTH,
       PERIODMONTHSEQ,
       BUSINESSUNITNAME,
       POSITIONTITLE,
       UNIT_CODE,
       UNIT_CODE_DESC,
       CREATE_DATE)
      SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      EXTRACT(YEAR FROM V_PERIODSTARTDATE),
                      SUBSTR(V_PERIODNAME, 0, LENGTH(V_PERIODNAME) - 5),
                      SUBSTR('0' ||
                             MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 13),
                             -2),
                      'SGPAGY',
                      AA.POSITIONTITLE,
                     -- REPLACE DM_CODE, UM_CODE WITH DISTRICT_CODE, UNIT_CODE
                     /* CASE
                        WHEN AA.DM_CODE IS NULL THEN
                         AA.UM_CODE
                        ELSE
                         AA.DM_CODE
                      END,
                      CASE
                        WHEN AA.DM_CODE IS NULL  THEN
                         AA.UM_CODE || ' - ' || AA.UM_NAME
                        ELSE
                         AA.DM_CODE || ' - ' || AA.DM_NAME
                      END,*/
                      CASE
                        WHEN AA.DISTRICT_CODE IS NULL THEN
                         AA.UNIT_CODE
                        ELSE
                         AA.DISTRICT_CODE
                      END,
                      CASE
                        WHEN AA.DISTRICT_CODE IS NULL THEN
                         AA.UNIT_CODE || '-' || AA.AGENCY
                        ELSE
                         AA.DISTRICT_CODE || '-' || AA.DISTRICT_NAME
                      END,
                      SYSDATE
        FROM AIA_AOR AA
       WHERE AA.PERIODSEQ = V_PERIODSEQ
       --Added parameter All
       UNION ALL
             SELECT DISTINCT V_PERIODSEQ,
                      V_CALENDARNAME,
                      V_PERIODNAME,
                      V_PERIODSTARTDATE,
                      V_PERIODENDDATE,
                      EXTRACT(YEAR FROM V_PERIODSTARTDATE),
                      SUBSTR(V_PERIODNAME, 0, LENGTH(V_PERIODNAME) - 5),
                      SUBSTR('0' ||
                             MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 13),
                             -2),
                      'SGPAGY',
                      AA.POSITIONTITLE,
                      'All',
                      ' All Unit Code',
                      SYSDATE
        FROM AIA_AOR AA
       WHERE AA.PERIODSEQ = V_PERIODSEQ;     
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_ADPI_PROC IS
  BEGIN
  
    DELETE FROM AIA_ADPI_LEADER T WHERE T.PERIODSEQ = V_PERIODSEQ;
    DELETE FROM AIA_ADPI_AGENT T WHERE T.PERIODSEQ = V_PERIODSEQ;
    DELETE FROM AIA_ADPI_LEADER_HALF T WHERE T.PERIODSEQ = V_PERIODSEQ;
    ------Insert Contribute Agents' Records
    INSERT INTO AIA_ADPI_AGENT
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       POSITIONNAME,
       POSITIONTITLE,
       MANAGERSEQ,
       DISTRICT_CODE,
       --DM_NAME,
       UNIT_CODE,
       LEADER_CODE,
       AGENCY,
       AGENCY_LEADER_NAME,
       LDR_PARTICIPANTSEQ,
       LDR_POSITIONSEQ,
       ROLE,
       CLASS,
       APPOINTMENT_DATE,
       AGENCY_DISSOLVED_DATE,
       ------Contribute Agent
       FSC_CODE,
       FSC_NAME,
       FSC_CLASS,
       FSC_CONT_DATE,
       FSC_ASSIGNED_DATE,
       FSC_TERMINATION_DATE,
       YTD_PIB,
       RATE,
       ADPI_AMOUNT,
       CREATE_DATE)
      SELECT V_PERIODSEQ,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             API.PARTICIPANTSEQ,
             API.POSITIONSEQ,
             API.EFFECTIVESTARTDATE,
             API.EFFECTIVEENDDATE,
             API.POSITIONNAME,
             API.POSITIONTITLE,
             API.MANAGERSEQ,
             API.GENERICATTRIBUTE6, --DISTRICT_CODE 
             --API.GENERICATTRIBUTE7, --DM_NAME 
             API.PARTICIPANTID, --UNIT_CODE
             API.GENERICATTRIBUTE4, --LEADER_CODE
             API.FIRSTNAME || API.MIDDLENAME || API.LASTNAME, --AGENCY
             API.GENERICATTRIBUTE5, --AGENCY_LEADER_NAME
             APL.PARTICIPANTSEQ,
             APL.POSITIONSEQ,
             APL.POSITIONTITLE, --ROLE
             APL.GENERICATTRIBUTE8, --CLASS
             APL.GENERICDATE9, --APPOINTMENT_DATE
             API.TERMINATIONDATE, --AGENCY_DISSOLVED_DATE
             ------Contribute Agent
             APIF.PARTICIPANTID,
             APIF.FIRSTNAME || APIF.MIDDLENAME || APIF.LASTNAME,
             --APIF.GENERICATTRIBUTE8,
             CRD.GENERICATTRIBUTE14, --FSC_CLASS
             APIF.HIREDATE,
             APIF.GENERICDATE8,
             APIF.TERMINATIONDATE,
             NVL(SUM(CRD.VALUE), 0),
             0,
             0,
             SYSDATE
        FROM CS_MEASUREMENT   MEA,
             CS_PMCREDITTRACE MEAT,
             CS_CREDIT        CRD,
             AIA_PAYEE_INFOR  API,
             AIA_PAYEE_INFOR  APIF,
             AIA_PAYEE_INFOR  APL
       WHERE MEA.MEASUREMENTSEQ = MEAT.MEASUREMENTSEQ
         AND MEAT.CREDITSEQ = CRD.CREDITSEQ
         AND CRD.POSITIONSEQ = API.POSITIONSEQ
         AND CRD.GENERICATTRIBUTE12 = APIF.PARTICIPANTID
         AND CRD.PERIODSEQ = V_PERIODSEQ
         AND MEA.NAME IN
             ('PM_PIB_DIRECT_TEAM_Assigned', 'PM_PIB_DIRECT_TEAM_Not_Assigned')
         AND API.POSITIONNAME LIKE '%Y%' ------Modified by Chao 20140812
         AND API.GENERICATTRIBUTE4 = APL.PARTICIPANTID
         AND APL.POSITIONTITLE IN ('AM', 'FSM', 'FSAD')
         AND API.BUSINESSUNITNAME = 'SGPAGY'
         AND APL.BUSINESSUNITNAME = 'SGPAGY'
         AND APIF.BUSINESSUNITNAME = 'SGPAGY'
       GROUP BY API.PARTICIPANTSEQ,
                API.POSITIONSEQ,
                API.EFFECTIVESTARTDATE,
                API.EFFECTIVEENDDATE,
                API.POSITIONNAME,
                API.POSITIONTITLE,
                API.MANAGERSEQ,
                API.GENERICATTRIBUTE6,
                API.GENERICATTRIBUTE7,
                API.PARTICIPANTID,
                API.GENERICATTRIBUTE4,
                API.FIRSTNAME,
                API.MIDDLENAME,
                API.LASTNAME,
                API.GENERICATTRIBUTE5,
                APL.PARTICIPANTSEQ,
                APL.POSITIONSEQ,
                APL.POSITIONTITLE,
                APL.GENERICATTRIBUTE8,
                APL.GENERICDATE9,
                API.TERMINATIONDATE,
                ------Contribute Agent
                APIF.PARTICIPANTID,
                APIF.FIRSTNAME,
                APIF.MIDDLENAME,
                APIF.LASTNAME,
                --APIF.GENERICATTRIBUTE8,
                CRD.GENERICATTRIBUTE14,
                APIF.HIREDATE,
                APIF.GENERICDATE8,
                APIF.TERMINATIONDATE;
    ------Update DM and Leader infor
    UPDATE AIA_ADPI_AGENT AAA
       SET AAA.DM_NAME =
           (SELECT API.GENERICATTRIBUTE5
              FROM AIA_PAYEE_INFOR API
             WHERE API.PARTICIPANTID = AAA.DISTRICT_CODE
               AND API.BUSINESSUNITNAME = 'SGPAGY'
               AND ROWNUM = 1),
           UPDATE_DATE = SYSDATE
     WHERE AAA.PERIODSEQ = V_PERIODSEQ;
    ------Update FSC/Leader data
    ------Add 1st half year and 2nd half year group
    UPDATE AIA_ADPI_AGENT AAA
       SET AAA.CONTRIBUTING_FSC = --I_ADPI_SG to SM to SM to PM to Credits 
           /*NVL((SELECT 'YES'
             FROM CS_INCENTIVE        INC,
                  CS_INCENTIVEPMTRACE INCT,
                  CS_PMSELFTRACE      MEAT,
                  CS_PMSELFTRACE      MEAT2,
                  CS_PMCREDITTRACE    CRDT,
                  CS_CREDIT           CRD
            WHERE INC.INCENTIVESEQ = INCT.INCENTIVESEQ
              AND INCT.MEASUREMENTSEQ = MEAT.TARGETMEASUREMENTSEQ
              AND MEAT.SOURCEMEASUREMENTSEQ = MEAT2.TARGETMEASUREMENTSEQ
              AND MEAT2.SOURCEMEASUREMENTSEQ = CRDT.MEASUREMENTSEQ
              AND CRDT.CREDITSEQ = CRD.CREDITSEQ
              AND INC.PERIODSEQ = V_PERIODSEQ
              AND INC.POSITIONSEQ = AAA.LDR_POSITIONSEQ
              AND CRD.GENERICATTRIBUTE12 = AAA.FSC_CODE
              AND INC.NAME = 'I_ADPI_SG'
              AND ROWNUM = 1),
           'NO'),*/ CASE
                      WHEN AAA.ROLE IN ('FSAD', 'FSM') AND AAA.FSC_CLASS = '12' THEN
                       'NO'
                      ELSE
                       'YES'
                    END,
           /*AAA.RATE             = NVL((SELECT NVL(MAX(INC.GENERICNUMBER1), 0)
             FROM CS_INCENTIVE INC
            WHERE INC.PERIODSEQ = AAA.PERIODSEQ
              AND INC.POSITIONSEQ = AAA.LDR_POSITIONSEQ
              AND INC.NAME = 'I_ADPI_SG'),
           0),*/
           AAA.PIB_HALF = TRUNC(MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) / 6),
           UPDATE_DATE  = SYSDATE
     WHERE AAA.PERIODSEQ = V_PERIODSEQ;
    ------Update YTD data
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 6) > 0 THEN
      UPDATE AIA_ADPI_AGENT AAA
         SET AAA.YTD_PIB     = AAA.YTD_PIB +
                               (SELECT NVL(SUM(T.YTD_PIB), 0)
                                  FROM AIA_ADPI_AGENT T
                                 WHERE T.PERIODSEQ = V_PRIOR_PERIODSEQ
                                   AND T.POSITIONSEQ = AAA.POSITIONSEQ
                                   AND T.FSC_CODE = AAA.FSC_CODE
                                   AND T.FSC_CLASS = AAA.FSC_CLASS
                                   AND T.PIB_HALF = AAA.PIB_HALF),
             AAA.UPDATE_DATE = SYSDATE
       WHERE AAA.PERIODSEQ = V_PERIODSEQ;
    END IF;
  
    ------Insert Agent record, just in prior period
    ------Add 1st half year and 2nd half year group
    IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) > 0 THEN
      INSERT INTO AIA_ADPI_AGENT
        (PERIODSEQ,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         PARTICIPANTSEQ,
         POSITIONSEQ,
         EFFECTIVESTARTDATE,
         EFFECTIVEENDDATE,
         MANAGERSEQ,
         POSITIONNAME,
         POSITIONTITLE,
         DISTRICT_CODE,
         DM_NAME,
         UNIT_CODE,
         LEADER_CODE,
         AGENCY,
         AGENCY_LEADER_NAME,
         LDR_PARTICIPANTSEQ,
         LDR_POSITIONSEQ,
         ROLE,
         CLASS,
         APPOINTMENT_DATE,
         AGENCY_DISSOLVED_DATE,
         FSC_CODE,
         FSC_NAME,
         FSC_CLASS,
         FSC_CONT_DATE,
         FSC_ASSIGNED_DATE,
         FSC_TERMINATION_DATE,
         --validation_pib,
         YTD_PIB,
         CONTRIBUTING_FSC,
         RATE,
         ADPI_AMOUNT,
         PIB_HALF,
         CREATE_DATE)
        SELECT V_PERIODSEQ,
               V_CALENDARNAME,
               V_PERIODNAME,
               V_PERIODSTARTDATE,
               V_PERIODENDDATE,
               AAA.PARTICIPANTSEQ,
               AAA.POSITIONSEQ,
               AAA.EFFECTIVESTARTDATE,
               AAA.EFFECTIVEENDDATE,
               AAA.MANAGERSEQ,
               AAA.POSITIONNAME,
               AAA.POSITIONTITLE,
               AAA.DISTRICT_CODE,
               AAA.DM_NAME,
               AAA.UNIT_CODE,
               AAA.LEADER_CODE,
               AAA.AGENCY,
               AAA.AGENCY_LEADER_NAME,
               AAA.LDR_PARTICIPANTSEQ,
               AAA.LDR_POSITIONSEQ,
               AAA.ROLE,
               AAA.CLASS,
               AAA.APPOINTMENT_DATE,
               AAA.AGENCY_DISSOLVED_DATE,
               AAA.FSC_CODE,
               AAA.FSC_NAME,
               AAA.FSC_CLASS,
               AAA.FSC_CONT_DATE,
               AAA.FSC_ASSIGNED_DATE,
               AAA.FSC_TERMINATION_DATE,
               --aaa.validation_pib,
               AAA.YTD_PIB,
               AAA.CONTRIBUTING_FSC,
               AAA.RATE,
               AAA.ADPI_AMOUNT,
               AAA.PIB_HALF,
               SYSDATE
          FROM AIA_ADPI_AGENT AAA
         WHERE AAA.PERIODSEQ = V_PRIOR_PERIODSEQ
           AND NOT EXISTS (SELECT 1
                  FROM AIA_ADPI_AGENT T
                 WHERE T.PERIODSEQ = V_PERIODSEQ
                   AND T.POSITIONSEQ = AAA.POSITIONSEQ
                   AND T.FSC_CODE = AAA.FSC_CODE
                   AND T.PIB_HALF = AAA.PIB_HALF);
    
      IF MOD(EXTRACT(MONTH FROM V_PERIODSTARTDATE), 12) = 11 THEN
        ------Update rate and adpi_amount
        UPDATE AIA_ADPI_AGENT AAA
           SET (AAA.RATE, AAA.ADPI_AMOUNT) =
               (SELECT NVL(MAX(INC.GENERICNUMBER1), 0),
                       CASE
                         WHEN AAA.CONTRIBUTING_FSC = 'YES' THEN
                          AAA.YTD_PIB * NVL(MAX(INC.GENERICNUMBER1), 0)
                         ELSE
                          0
                       END
                  FROM CS_INCENTIVE INC
                 WHERE INC.PERIODSEQ = AAA.PERIODSEQ
                   AND INC.POSITIONSEQ = AAA.LDR_POSITIONSEQ
                   AND INC.NAME = 'I_ADPI_SG'),
               AAA.UPDATE_DATE = SYSDATE
         WHERE AAA.PERIODSEQ = V_PERIODSEQ;
        /*------Update adpi_amount
        UPDATE AIA_ADPI_AGENT AAA
           SET AAA.ADPI_AMOUNT = CASE
                                   WHEN AAA.CONTRIBUTING_FSC = 'YES' THEN
                                    AAA.YTD_PIB * AAA.RATE
                                   ELSE
                                    0
                                 END,
               AAA.UPDATE_DATE = SYSDATE
         WHERE AAA.PERIODSEQ = V_PERIODSEQ;*/
      END IF;
    END IF;
    
    --modified by zhubin for duplicate half records 20140808
    ------Insert Leader Half record
    INSERT INTO AIA_ADPI_LEADER_HALF
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       --PARTICIPANTSEQ,
       --POSITIONSEQ,
       --EFFECTIVESTARTDATE,
       --EFFECTIVEENDDATE,
       --MANAGERSEQ,
       --POSITIONNAME,
       --POSITIONTITLE,
       DISTRICT_CODE,
       --DM_NAME,
       UNIT_CODE,
       LEADER_CODE,
       AGENCY,
       AGENCY_LEADER_NAME,
       --LDR_PARTICIPANTSEQ,
       --LDR_POSITIONSEQ,
       --ROLE,
       CLASS,
       --APPOINTMENT_DATE,
       --AGENCY_DISSOLVED_DATE,
       /*fsc_code,
       fsc_name,
       fsc_class,
       fsc_cont_date,
       fsc_assigned_date,
       fsc_termination_date,*/
       --validation_pib,
       YTD_PIB,
       --contributing_fsc,
       --rate,
       ADPI_AMOUNT,
       PIB_HALF,
       CREATE_DATE)
      SELECT AAA.PERIODSEQ, 
             AAA.CALENDARNAME, 
             AAA.PERIODNAME,
             AAA.PERIODSTARTDATE,
             AAA.PERIODENDDATE,
             --AAA.PARTICIPANTSEQ,
             --AAA.POSITIONSEQ,
             --AAA.EFFECTIVESTARTDATE,
             --AAA.EFFECTIVEENDDATE,
             --AAA.MANAGERSEQ,
             --AAA.POSITIONNAME,
             --AAA.POSITIONTITLE,
             AAA.DISTRICT_CODE, 
             --AAA.DM_NAME,
             AAA.UNIT_CODE,
             AAA.LEADER_CODE,
             AAA.AGENCY,
             AAA.AGENCY_LEADER_NAME,
             --AAA.LDR_PARTICIPANTSEQ,
             --AAA.LDR_POSITIONSEQ,
             --AAA.ROLE,
             AAA.CLASS,
             --AAA.APPOINTMENT_DATE,
             --AAA.AGENCY_DISSOLVED_DATE,
             /*aaa.fsc_code,
             aaa.fsc_name,
             aaa.fsc_class,
             aaa.fsc_cont_date,
             aaa.fsc_assigned_date,
             aaa.fsc_termination_date,*/
             --aaa.validation_pib,
             NVL(SUM(CASE
                       WHEN AAA.CONTRIBUTING_FSC = 'YES' THEN
                        AAA.YTD_PIB
                       ELSE
                        0
                     END),
                 0),
             --aaa.contributing_fsc,
             --nvl(max(aaa.rate),0),
             NVL(SUM(AAA.ADPI_AMOUNT), 0),
             AAA.PIB_HALF,
             SYSDATE
        FROM AIA_ADPI_AGENT AAA
       WHERE AAA.PERIODSEQ = V_PERIODSEQ
       GROUP BY AAA.PERIODSEQ,
                AAA.CALENDARNAME,
                AAA.PERIODNAME,
                AAA.PERIODSTARTDATE,
                AAA.PERIODENDDATE,
                --AAA.PARTICIPANTSEQ,
                --AAA.POSITIONSEQ,
                --AAA.EFFECTIVESTARTDATE,
                --AAA.EFFECTIVEENDDATE,
                --AAA.MANAGERSEQ,
                --AAA.POSITIONNAME,
                --AAA.POSITIONTITLE,
                AAA.DISTRICT_CODE,
                --AAA.DM_NAME,
                AAA.UNIT_CODE,
                AAA.LEADER_CODE,
                AAA.AGENCY,
                AAA.AGENCY_LEADER_NAME,
                --AAA.LDR_PARTICIPANTSEQ,
                --AAA.LDR_POSITIONSEQ,
                --AAA.ROLE,
                AAA.CLASS,
                --AAA.APPOINTMENT_DATE,
                --AAA.AGENCY_DISSOLVED_DATE,
                AAA.PIB_HALF;
    ----modified by zhubin
    
    --modified by zhubin for duplicate unit records 20140808           
    ------Insert Leader record
    INSERT INTO AIA_ADPI_LEADER
      (PERIODSEQ,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       --PARTICIPANTSEQ,
       --POSITIONSEQ,
       --EFFECTIVESTARTDATE,
       --EFFECTIVEENDDATE,
       --MANAGERSEQ,
       --POSITIONNAME,
       --POSITIONTITLE,
       DISTRICT_CODE,
       --DM_NAME,
       UNIT_CODE,
       LEADER_CODE,
       AGENCY,
       AGENCY_LEADER_NAME,
       --LDR_PARTICIPANTSEQ,
       --LDR_POSITIONSEQ,
       --ROLE,
       CLASS,
       --APPOINTMENT_DATE,
       --AGENCY_DISSOLVED_DATE,
       /*fsc_code,
       fsc_name,
       fsc_class,
       fsc_cont_date,
       fsc_assigned_date,
       fsc_termination_date,*/
       --validation_pib,
       YTD_PIB,
       --contributing_fsc,
       --rate,
       --ADPI_AMOUNT,
       CREATE_DATE)
      SELECT AAA.PERIODSEQ,
             AAA.CALENDARNAME,
             AAA.PERIODNAME,
             AAA.PERIODSTARTDATE,
             AAA.PERIODENDDATE,
             --AAA.PARTICIPANTSEQ,
             --AAA.POSITIONSEQ,
             --AAA.EFFECTIVESTARTDATE,
             --AAA.EFFECTIVEENDDATE,
             --AAA.MANAGERSEQ,
             --AAA.POSITIONNAME,
             --AAA.POSITIONTITLE,
             AAA.DISTRICT_CODE,
             --AAA.DM_NAME,
             AAA.UNIT_CODE,
             AAA.LEADER_CODE,
             AAA.AGENCY,
             AAA.AGENCY_LEADER_NAME,
             --AAA.LDR_PARTICIPANTSEQ,
             --AAA.LDR_POSITIONSEQ,
             --AAA.ROLE,
             AAA.CLASS,
             --AAA.APPOINTMENT_DATE,
             --AAA.AGENCY_DISSOLVED_DATE,
             /*aaa.fsc_code,
             aaa.fsc_name,
             aaa.fsc_class,
             aaa.fsc_cont_date,
             aaa.fsc_assigned_date,
             aaa.fsc_termination_date,*/
             --aaa.validation_pib,
             NVL(SUM(CASE
                       WHEN AAA.CONTRIBUTING_FSC = 'YES' THEN
                        AAA.YTD_PIB
                       ELSE
                        0
                     END),
                 0),
             --aaa.contributing_fsc,
             --nvl(max(aaa.rate),0),
             --NVL(SUM(AAA.ADPI_AMOUNT), 0),
             SYSDATE
        FROM AIA_ADPI_AGENT AAA
       WHERE AAA.PERIODSEQ = V_PERIODSEQ
       GROUP BY AAA.PERIODSEQ,
                AAA.CALENDARNAME,
                AAA.PERIODNAME,
                AAA.PERIODSTARTDATE,
                AAA.PERIODENDDATE,
                --AAA.PARTICIPANTSEQ,
                --AAA.POSITIONSEQ,
                --AAA.EFFECTIVESTARTDATE,
                --AAA.EFFECTIVEENDDATE,
                --AAA.MANAGERSEQ,
                --AAA.POSITIONNAME,
                --AAA.POSITIONTITLE,
                AAA.DISTRICT_CODE,
                --AAA.DM_NAME,
                AAA.UNIT_CODE,
                AAA.LEADER_CODE,
                AAA.AGENCY,
                AAA.AGENCY_LEADER_NAME,
                --AAA.LDR_PARTICIPANTSEQ,
                --AAA.LDR_POSITIONSEQ,
                --AAA.ROLE,
                AAA.CLASS;
                --AAA.APPOINTMENT_DATE,
                --AAA.AGENCY_DISSOLVED_DATE;
    ------Update leader data
    --modified by zhubin
    
    UPDATE AIA_ADPI_LEADER AAL
       SET AAL.VALIDATION_PIB =
           (SELECT NVL(SUM(MEA.VALUE), 0)
              FROM CS_MEASUREMENT MEA, CS_PERIOD PER
             WHERE MEA.PERIODSEQ = PER.PERIODSEQ
               AND MEA.POSITIONSEQ = AAL.LDR_POSITIONSEQ
               AND MEA.NAME = 'SM_ADPI_Target_Semi_Year'
               AND PER.CALENDARSEQ = V_CALENDARSEQ
               AND PER.PERIODTYPESEQ = V_PERIODTYPESEQ
               AND PER.STARTDATE = ADD_MONTHS(V_PERIODSTARTDATE, -6)) +
           (SELECT NVL(MAX(MEA.GENERICNUMBER1), 0)
              FROM CS_MEASUREMENT MEA
             WHERE MEA.PERIODSEQ = AAL.PERIODSEQ
               AND MEA.POSITIONSEQ = AAL.LDR_POSITIONSEQ
               AND MEA.NAME = 'SM_Second_Half_Year_PIB_ACC'),
           AAL.ADPI_AMOUNT   =
           (SELECT NVL(SUM(INC.VALUE), 0)
              FROM CS_INCENTIVE INC
             WHERE INC.PERIODSEQ = AAL.PERIODSEQ
               AND INC.POSITIONSEQ = AAL.LDR_POSITIONSEQ
               AND INC.NAME = 'I_ADPI_SG'),
           AAL.UPDATE_DATE    = SYSDATE
     WHERE AAL.PERIODSEQ = V_PERIODSEQ;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_SINGAPORE_REPORT_PROC IS
  BEGIN
  
    ------
    AIA_INCOME_SUMMARY_PROC;
    AIA_INCOME_SUMMARY_BRUNEI_PROC;
    AIA_NLPI_PROC;
    AIA_SPI_PROC;
    AIA_RENEWAL_COMMISSION_PROC;
    AIA_DIRECT_OVERRIDE_PROC;
    AIA_RENEWAL_OVERRIDE_PROC;
    AIA_CAREER_BENEFIT_PROC;
    ------
    AIA_BALANCE_DATA;
    AIA_AGEING_DETAIL_PROC;
    ------
    AIA_QTRLY_PROD_BONUS_PROC;
    AIA_INDIRECT_OVERRIDE_PROC;
    ------
    AIA_AOR_PROC;
    AIA_AOR_UNIT_PROC;
    ------
    AIA_ADPI_PROC;
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

BEGIN

  /*SELECT PERD.PERIODSEQ,
        CAL.CALENDARSEQ,
        CAL.NAME,
        PERT.PERIODTYPESEQ,
        PERD.NAME,
        PERD.STARTDATE,
        PERD.ENDDATE
   INTO V_PERIODSEQ,
        V_CALENDARSEQ,
        V_CALENDARNAME,
        V_PERIODTYPESEQ,
        V_PERIODNAME,
        V_PERIODSTARTDATE,
        V_PERIODENDDATE
   FROM CS_PERIOD PERD, CS_PERIODTYPE PERT, CS_CALENDAR CAL
  WHERE PERD.CALENDARSEQ = CAL.CALENDARSEQ
    AND PERD.PERIODTYPESEQ = PERT.PERIODTYPESEQ
    AND PERD.REMOVEDATE = C_REMOVEDATE
    AND PERT.REMOVEDATE = C_REMOVEDATE
    AND CAL.REMOVEDATE = C_REMOVEDATE
    AND CAL.NAME = 'AIA Singapore Calendar'
    AND PERD.NAME = 'March 2000';*/

  SELECT *
    INTO V_CALENDARNAME,
         V_PERIODSEQ,
         V_PERIODNAME,
         V_PERIODSTARTDATE,
         V_PERIODENDDATE,
         V_CALENDARSEQ,
         V_PERIODTYPESEQ
    FROM AIA_PERIOD_INFO;

  ------get prior period key
  SELECT PERD.PERIODSEQ
    INTO V_PRIOR_PERIODSEQ
    FROM CS_PERIOD PERD
   WHERE PERD.REMOVEDATE = C_REMOVEDATE
     AND PERD.CALENDARSEQ = V_CALENDARSEQ
     AND PERD.PERIODTYPESEQ = V_PERIODTYPESEQ
     AND PERD.ENDDATE = V_PERIODSTARTDATE;

  AIA_AGENT_INFORMATION;
  AIA_DISTRICT_UNIT_AGENT_INFOR;
  AIA_DEPOSIT_TRACE_BACK;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/
