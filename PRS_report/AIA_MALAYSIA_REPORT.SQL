CREATE OR REPLACE PACKAGE BODY AIA_MALAYSIA_REPORT_PKG_z IS

  C_REMOVEDATE PERIODDIMENSION.REMOVEDATE%TYPE := TO_DATE('2200-1-1', 'YYYY-MM-DD');
  --C_PERIODTYPE PERIODDIMENSION.PERIODTYPE%TYPE := 'semi-month';
  V_ERROR_CODE    VARCHAR2(255);
  V_ERROR_MESSAGE VARCHAR2(255);

  C_ORIGINID_MANUAL VARCHAR2(125) := 'manual';
  TYPE T_EARNING_CODE IS TABLE OF VARCHAR2(255) INDEX BY BINARY_INTEGER;
  C_EARNING_CODE T_EARNING_CODE;

  V_CALENDARNAME    PERIODDIMENSION.CALENDARNAME%TYPE;
  V_PERIODTYPE      PERIODDIMENSION.PERIODTYPE%TYPE;
  V_PERIODNAME      PERIODDIMENSION.PERIODNAME%TYPE;
  V_PERIODKEY       PERIODDIMENSION.PERIODKEY%TYPE;
  V_PERIODSTARTDATE PERIODDIMENSION.PERIODSTARTDATE%TYPE;
  V_PERIODENDDATE   PERIODDIMENSION.PERIODENDDATE%TYPE;
  ------the prior period
  V_PRIOR_PERIODKEY PERIODDIMENSION.PERIODKEY%TYPE;

  PROCEDURE AIA_ERROR_LOG IS
  BEGIN
    V_ERROR_CODE    := SQLCODE;
    V_ERROR_MESSAGE := SQLERRM;
    INSERT INTO AIA_ERROR_MESSAGE
      (ERRORCODE, ERRORMESSAGE, ERRORBACKTRACE, CREATEDATE)
    VALUES
      (V_ERROR_CODE, V_ERROR_MESSAGE, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, SYSDATE);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  PROCEDURE AIA_AGENT_INFORMATION IS

    V_POSITIONSEQ   NUMBER;
    V_EFFECTIVEDATE DATE;
    V_UM            VARCHAR2(40);
    V_DM            VARCHAR2(40);

  BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE AIA_PAYEE_INFOR';

    INSERT INTO AIA_PAYEE_INFOR
      (PAKEY,
       PARTICIPANTSEQ,
       POSITIONSEQ,
       MANAGERSEQ,
       PARTICIPANTID,
       PREFIX,
       FIRSTNAME,
       MIDDLENAME,
       LASTNAME,
       SUFFIX,
       TAXID,
       SALARY,
       HIREDATE,
       TERMINATIONDATE,
       PARTICIPANTEFFECTIVESTARTDATE,
       PARTICIPANTEFFECTIVEENDDATE,
       POSITIONNAME,
       POSITIONTITLE,
       POSITIONEFFECTIVESTARTDATE,
       POSITIONEFFECTIVEENDDATE,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       REMOVEDATE,
       GENERICATTRIBUTE4,
       ETLHISTORYKEY,
       PRODUCERKEY,
       /*PRODUCERTYPENAME,
       PRODUCERSTATUS,
       COMPANYNAME,
       PHONE,
       FAX,
       EMAIL,
       BIRTHDAY,
       SEX,
       NATIONALPRODUCERID,
       NAICID,
       CONTACT,
       ADDRESS1,
       ADDRESS2,
       ADDRESS3,
       CITY,
       STATE,
       COUNTRY,
       POSTALCODE,
       WEBADDRESS,*/
       CREATEDATE)
      SELECT PAD.PAKEY,
             PAD.PARTICIPANTSEQ,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.PARTICIPANTID,
             PAD.PREFIX,
             PAD.FIRSTNAME,
             PAD.MIDDLENAME,
             PAD.LASTNAME,
             PAD.SUFFIX,
             PAD.TAXID,
             PAD.SALARY,
             PAD.HIREDATE,
             PAD.TERMINATIONDATE,
             PAD.PARTICIPANTEFFECTIVESTARTDATE,
             PAD.PARTICIPANTEFFECTIVEENDDATE,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             PAD.POSITIONEFFECTIVESTARTDATE,
             PAD.POSITIONEFFECTIVEENDDATE,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             PAD.REMOVEDATE,
             PAD.PARTICIPANTGENERICATTRIBUTE4,
             PAD.ETLHISTORYKEY,
             PAD.PRODUCERKEY,
             SYSDATE
        FROM PADIMENSION PAD
       WHERE  PAD.EFFECTIVESTARTDATE < V_PERIODENDDATE --TO_DATE('2014-5-1', 'YYYY-MM-DD')
         AND PAD.EFFECTIVEENDDATE > V_PERIODSTARTDATE --TO_DATE('2014-4-14', 'YYYY-MM-DD')

      ;
  UPDATE AIA_PAYEE_INFOR t
  SET (PRODUCERKEY,
       PRODUCERTYPENAME,
       PRODUCERSTATUS,
       COMPANYNAME,
       PHONE,
       FAX,
       EMAIL,
       BIRTHDAY,
       SEX,
       NATIONALPRODUCERID,
       NAICID,
       CONTACT,
       ADDRESS1,
       ADDRESS2,
       ADDRESS3,
       CITY,
       STATE,
       COUNTRY,
       POSTALCODE,
       WEBADDRESS,
       updatedate )=
       (SELECT prod.producerkey,
             PROD.PRODUCERTYPENAME,
             PROD.PRODUCERSTATUS,
             PROD.COMPANYNAME,
             PROD.PHONE,
             PROD.FAX,
             PROD.EMAIL,
             PROD.BIRTHDAY,
             PROD.SEX,
             PROD.NATIONALPRODUCERID,
             PROD.NAICID,
             PROD.CONTACT,
             PROD.ADDRESS1,
             PROD.ADDRESS2,
             PROD.ADDRESS3,
             PROD.CITY,
             PROD.STATE,
             PROD.COUNTRY,
             PROD.POSTALCODE,
             PROD.WEBADDRESS,SYSDATE
       FROM producerdimension prod
       WHERE prod.payeeseq=t.participantseq
       AND prod.effectivestartdate<t.effectiveenddate
       AND prod.effectiveenddate>t.effectivestartdate
       AND  V_PERIODENDDATE-1 between proD.effectivestartdate AND proD.effectiveenddate -1
       AND prod.producerkey=t.producerkey
       AND rownum=1)
   WHERE t.producerkey IS NOT NULL;
  UPDATE AIA_PAYEE_INFOR t
  SET (PRODUCERTYPENAME,
       PRODUCERSTATUS,
       PRODUCERSTATUSNAME,
       COMPANYNAME,
       PHONE,
       FAX,
       EMAIL,
       BIRTHDAY,
       SEX,
       NATIONALPRODUCERID,
       NAICID,
       CONTACT,
       ADDRESS1,
       ADDRESS2,
       ADDRESS3,
       CITY,
       STATE,
       COUNTRY,
       POSTALCODE,
       WEBADDRESS,
       updatedate )=
       (SELECT prot.name producertypename,
             sta.status producerstatus,
             sta.name producerstatusname,
             pro.companyname,
             pro.phone,
             pro.fax,
             pro.email,
             pro.birthday,
             pro.sex,
             pro.nationalproducerid,
             pro.naicid,
             proa.contact,
             proa.address1,
             proa.address2,
             proa.address3,
             proa.city,
             PROa.State,
             PROa.Country,
             PROa.Postalcode,
             PROa.Webaddress,
             SYSDATE
       FROM csp_producer        pro,
            csp_producertype    prot,
            csp_statuscode      sta,
            csp_produceraddress proa
       WHERE pro.payeeseq=t.participantseq
       AND pro.effectivestartdate<t.effectiveenddate
       AND pro.effectiveenddate>t.effectivestartdate
       AND pro.producertypeseq=prot.datatypeseq
       AND pro.payeeseq=proa.producerseq(+)
       AND pro.statuscodeseq=sta.datatypeseq
       AND sta.removedate>SYSDATE
       AND prot.removedate>SYSDATE
       AND pro.removedate>SYSDATE
       AND proa.removedate(+)>SYSDATE
       AND proa.effectivestartdate(+)<t.effectiveenddate
       AND proa.effectiveenddate(+)>t.effectivestartdate
       AND  V_PERIODENDDATE-1 between pro.effectivestartdate AND pro.effectiveenddate -1
       AND rownum=1)
   WHERE t.producerkey IS NULL;
    FOR P_AGENT IN (SELECT *
                      FROM AIA_PAYEE_INFOR T
                     WHERE T.POSITIONTITLE IN
                           ('Tied Agency-UM', 'Tied Agency-DM', 'Tied Agency-Agent')) LOOP
      V_POSITIONSEQ   := P_AGENT.POSITIONSEQ;
      V_EFFECTIVEDATE := P_AGENT.EFFECTIVESTARTDATE;

      ------update UN/DM
      IF P_AGENT.POSITIONTITLE = 'Tied Agency-DM' THEN
        UPDATE AIA_PAYEE_INFOR T
           SET T.MANAGER      = P_AGENT.PARTICIPANTID,
               T.GRANDMANAGER = P_AGENT.PARTICIPANTID
         WHERE T.PAKEY = P_AGENT.PAKEY;
        NULL;
      ELSE
        FOR P_MANAGER IN (SELECT *
                            FROM (SELECT PAD.PAKEY,
                                         PAD.POSITIONSEQ,
                                         PAD.MANAGERSEQ,
                                         PAD.POSITIONTITLE,
                                         PAD.EFFECTIVESTARTDATE,
                                         PAD.EFFECTIVEENDDATE,
                                         PAD.PARTICIPANTID
                                    FROM PADIMENSION PAD
                                   WHERE V_EFFECTIVEDATE BETWEEN PAD.EFFECTIVESTARTDATE AND
                                         PAD.EFFECTIVEENDDATE - 1
                                     AND PAD.REMOVEDATE = C_REMOVEDATE) PAD2
                           START WITH PAD2.POSITIONSEQ = V_POSITIONSEQ
                                  AND PAD2.EFFECTIVESTARTDATE = V_EFFECTIVEDATE
                          CONNECT BY PRIOR PAD2.MANAGERSEQ = PAD2.POSITIONSEQ) LOOP
          IF V_UM IS NULL AND P_MANAGER.POSITIONTITLE = 'Tied Agency-UM' THEN
            V_UM := P_MANAGER.PARTICIPANTID;
          ELSIF V_DM IS NULL AND P_MANAGER.POSITIONTITLE = 'Tied Agency-DM' THEN
            V_DM := P_MANAGER.PARTICIPANTID;
          END IF;
        END LOOP;

        UPDATE AIA_PAYEE_INFOR T
           SET T.MANAGER = V_UM, T.GRANDMANAGER = V_DM
         WHERE T.PAKEY = P_AGENT.PAKEY;
        V_UM := NULL;
        V_DM := NULL;
      END IF;
    END LOOP;
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_CREDIT_INFOR IS
  BEGIN
    ------truncate table
    EXECUTE IMMEDIATE 'TRUNCATE TABLE AIA_CREDIT_EARNING_CODE';
    ------insert credit data
    INSERT INTO AIA_CREDIT_EARNING_CODE
      (PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       TRANSACTIONFACTKEY,
       CREDITFACTKEY,
       PAKEY,
       CREDITRULENAME,
       CREDITRULETYPE,
       --EARNINGCODE ,
       CREATE_DATE)
      SELECT V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             CRDF.TRANSACTIONFACTKEY,
             CRDF.CREDITFACTKEY,
             CRDF.PAKEY,
             CRDM.CREDITRULENAME,
             CRDM.CREDITRULETYPE,
             SYSDATE
        FROM CREDITFACT CRDF, CREDITRULEDIMENSION CRDM
       WHERE CRDF.CREDITRULEKEY = CRDM.CREDITRULEKEY
         AND CRDF.PERIODKEY = V_PERIODKEY
         AND CRDM.CREDITRULENAME NOT LIKE '%Old_Scheme';
    ------update earning code
    UPDATE AIA_CREDIT_EARNING_CODE T
       SET T.EARNINGCODE = AIA_EARNING_CODE(T.CREDITFACTKEY);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  FUNCTION AIA_EARNING_CODE(P_CREDITFACTKEY NUMBER) RETURN VARCHAR2 IS
    V_EARNING_CODE VARCHAR2(255);

  BEGIN
    ------credit->measurement(2)->incentive(2)->deposit
    BEGIN
      SELECT EARD.EARNINGCODEID
        INTO V_EARNING_CODE
        FROM PMCREDITFACTTRACE         PMC,
             MEASUREMENTFACTTRACE      MEAT,
             INCENTIVEPMFACTTRACE      INCT,
             INCENTIVEFACTTRACE        INCFT,
             DEPOSITINCENTIVEFACTTRACE DEPT,
             DEPOSITFACT               DEPF,
             EARNINGDIMENSION          EARD
       WHERE PMC.CREDITFACTKEY = P_CREDITFACTKEY
         AND PMC.MEASUREMENTFACTKEY = MEAT.SOURCEMEASUREMENTFACTKEY(+)
         AND (PMC.MEASUREMENTFACTKEY = INCT.MEASUREMENTFACTKEY OR
             MEAT.TARGETMEASUREMENTFACTKEY = INCT.MEASUREMENTFACTKEY)
         AND INCT.INCENTIVEFACTKEY = INCFT.SOURCEINCENTIVEFACTKEY(+)
         AND (INCT.INCENTIVEFACTKEY = DEPT.INCENTIVEFACTKEY OR
             INCFT.TARGETINCENTIVEFACTKEY = DEPT.INCENTIVEFACTKEY)
         AND DEPT.DEPOSITFACTKEY = DEPF.DEPOSITFACTKEY
         AND DEPF.EARNINGKEY = EARD.EARNINGKEY
         AND ROWNUM = 1;
      RETURN V_EARNING_CODE;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    ------credit->measurement(2)->incentive(3)->deposit
    BEGIN
      SELECT EARD.EARNINGCODEID
        INTO V_EARNING_CODE
        FROM PMCREDITFACTTRACE         PMC,
             MEASUREMENTFACTTRACE      MEAT,
             INCENTIVEPMFACTTRACE      INCT,
             INCENTIVEFACTTRACE        INCFT,
             INCENTIVEFACTTRACE        INCFT2,
             DEPOSITINCENTIVEFACTTRACE DEPT,
             DEPOSITFACT               DEPF,
             EARNINGDIMENSION          EARD
       WHERE PMC.CREDITFACTKEY = P_CREDITFACTKEY
         AND PMC.MEASUREMENTFACTKEY = MEAT.SOURCEMEASUREMENTFACTKEY(+)
         AND (PMC.MEASUREMENTFACTKEY = INCT.MEASUREMENTFACTKEY OR
             MEAT.TARGETMEASUREMENTFACTKEY = INCT.MEASUREMENTFACTKEY)
         AND INCT.INCENTIVEFACTKEY = INCFT.SOURCEINCENTIVEFACTKEY
         AND INCFT.TARGETINCENTIVEFACTKEY = INCFT2.SOURCEINCENTIVEFACTKEY
         AND INCFT2.TARGETINCENTIVEFACTKEY = DEPT.INCENTIVEFACTKEY
         AND DEPT.DEPOSITFACTKEY = DEPF.DEPOSITFACTKEY
         AND DEPF.EARNINGKEY = EARD.EARNINGKEY
         AND ROWNUM = 1;
      RETURN V_EARNING_CODE;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    RETURN V_EARNING_CODE;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
      RETURN '';
  END;

  PROCEDURE AIA_OLD_SCHEME_DATA IS
  BEGIN

    EXECUTE IMMEDIATE 'TRUNCATE TABLE AIA_OLD_SCHEME_DTL';
    INSERT INTO AIA_OLD_SCHEME_DTL
      (POLICY_NO,
       EARNING_CODE,
       PRODUCTID,
       CHANNEL,
       DATASOURCE,
       BUSINESSUNITNAME,
       PREMIUM_MODE,
       PREMIUM_TYPE,
       BUSINESS_LINE,
       COVERAGE_ID,
       POLICY_HOLDER,
       POLICY_HOLDER_NRIC,
       POLICY_INSURED,
       POLICY_INSURED_NRIC,
       COMPANY_CODE,
       LIFE_NO,
       COVERAGE_NO,
       RIDER_NO,
       SEQ_NO,
       POLICY_YEAR,
       POLICY_ISSUE_DATE,
       DUE_DATE,
       ACCOUNTING_DATE,
       COMPENSATION_DATE,
       IS_WRITING_AGENT,
       COMMISSIONABLE_PREMIUM,
       RATE,
       VALUE,
       SPLIT_PERCENTAGE,
       DESCRIPTION,
       TAX_IND,
       REFERENCE,
       WRITING_AGT_CODE,
       UM,
       DM,
       BATCHNAME,
       PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       OFFICE,
       STATUS_CODE,
       STATUS_NAME,
       TERMINATIONDATE,
       PRODUCERNAME,
       PRODUCERCODE,
       IC_NUMBER,
       REGION,
       CREATE_DATE)
      SELECT /*+parallel*(AOASD,4)*/
       AOASD.POLICY_NO,
       AOASD.EARNING_CODE,
       AOASD.PRODUCTID,
       AOASD.CHANNEL,
       AOASD.DATASOURCE,
       AOASD.BUSINESSUNITNAME,
       --AOASD.PREMIUM_MODE,
       --DECODE(AOASD.DATASOURCE, 'LSP', NULL, AOASD.PREMIUM_MODE), ------just for LSP hardcode
       CASE
         WHEN V_PERIODNAME = 'December 2013A' AND AOASD.DATASOURCE = 'LSP' THEN
          NULL
         ELSE
          AOASD.PREMIUM_MODE
       END,
       AOASD.PREMIUM_TYPE,
       AOASD.BUSINESS_LINE,
       AOASD.COVERAGE_ID,
       AOASD.POLICY_HOLDER,
       AOASD.POLICY_HOLDER_NRIC,
       AOASD.POLICY_INSURED,
       AOASD.POLICY_INSURED_NRIC,
       AOASD.COMPANY_CODE,
       AOASD.LIFE_NO,
       AOASD.COVERAGE_NO,
       AOASD.RIDER_NO,
       AOASD.SEQ_NO,
       AOASD.POLICY_YEAR,
       AOASD.POLICY_ISSUE_DATE,
       AOASD.DUE_DATE,
       --AOASD.ACCOUNTING_DATE,
       --DECODE(AOASD.DATASOURCE, 'LSP', NULL, AOASD.ACCOUNTING_DATE), ------just for LSP hardcode
       CASE
         WHEN V_PERIODNAME = 'December 2013A' AND AOASD.DATASOURCE = 'LSP' THEN
          NULL
         ELSE
          AOASD.ACCOUNTING_DATE
       END,
       AOASD.COMPENSATION_DATE,
       AOASD.IS_WRITING_AGENT,
       AOASD.COMMISSIONABLE_PREMIUM,
       --AOASD.RATE,
       --DECODE(AOASD.DATASOURCE, 'LSP', NULL, AOASD.RATE), ------just for LSP hardcode
       CASE
         WHEN V_PERIODNAME = 'December 2013A' AND AOASD.DATASOURCE = 'LSP' THEN
          NULL
         ELSE
          AOASD.RATE
       END,
       AOASD.VALUE,
       AOASD.SPLIT_PERCENTAGE,
       AOASD.DESCRIPTION,
       AOASD.TAX_IND,
       AOASD.REFERENCE,
       AOASD.WRITING_AGT_CODE,
       AOASD.UM,
       AOASD.DM,
       AOASD.BATCHNAME,
       PAD.PAKEY,
       PAD.EFFECTIVESTARTDATE,
       PAD.EFFECTIVEENDDATE,
       V_PERIODKEY,
       V_CALENDARNAME,
       V_PERIODNAME,
       V_PERIODSTARTDATE,
       V_PERIODENDDATE,
       PAD.POSITIONSEQ,
       PAD.MANAGERSEQ,
       PAD.POSITIONNAME,
       PAD.POSITIONTITLE,
       NULL OFFICE,
       STA.STATUS STATUS_CODE,
       STA.NAME STATUS_NAME,
       PAR.TERMINATIONDATE,
       PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME || PAD.SUFFIX PRODUCERNAME,
       PAD.PARTICIPANTID PRODUCERCODE,
       PaD.NATIONALPRODUCERID IC_NUMBER,
       PAD.GENERICATTRIBUTE4 REGION,
       SYSDATE
        FROM --PADIMENSION               PAD,
             --PRODUCERDIMENSION         PROD,
             AIA_PAYEE_INFOR pad,
             AIA_OLD_AGT_STATEMENT_DTL AOASD,
             CS_PARTICIPANT            PAR,
             CSP_PRODUCER              PRO,
             CSP_STATUSCODE            STA
      /*       WHERE PAR.PAYEESEQ = PRO.PAYEESEQ
               AND PAR.EFFECTIVESTARTDATE = PRO.EFFECTIVESTARTDATE
               AND PAR.REMOVEDATE = PRO.REMOVEDATE
               AND PAD.PARTICIPANTSEQ = PRO.PAYEESEQ
               AND PRO.STATUSCODESEQ = STA.DATATYPESEQ
               AND PRO.REMOVEDATE = C_REMOVEDATE
               AND PAD.EFFECTIVESTARTDATE BETWEEN PRO.EFFECTIVESTARTDATE AND PRO.EFFECTIVEENDDATE - 1
               AND STA.REMOVEDATE = C_REMOVEDATE
               AND PAD.PRODUCERKEY = PROD.PRODUCERKEY
               AND PAD.PAKEY = (SELECT MAX(T.PAKEY)
                            FROM PADIMENSION T
                           WHERE T.POSITIONSEQ = PAD.POSITIONSEQ
                             AND T.CREATEDATE < V_PERIODENDDATE)
      --         AND AOASD.POSITIONNAME = PAD.POSITIONNAME -- Changed by corey 20140303
               AND AOASD.PAYEE_ID = PAD.POSITIONNAME
               AND AOASD.COMPENSATION_DATE BETWEEN PAD.EFFECTIVESTARTDATE AND
                   PAD.EFFECTIVEENDDATE - 1
               AND AOASD.COMPENSATION_DATE BETWEEN V_PERIODSTARTDATE AND V_PERIODENDDATE - 1
               AND AOASD.EARNING_CODE IS NOT NULL;*/
      -- CHANGED20140509
       WHERE AOASD.POSITIONNAME = PAD.POSITIONNAME
         AND PAD.REMOVEDATE=C_REMOVEDATE
        /* AND PAD.REMOVEDATE = (SELECT max(K.REMOVEDATE)
                                 FROM PADIMENSION K
                                WHERE K.POSITIONSEQ = PAD.POSITIONSEQ
                                  AND K.EFFECTIVESTARTDATE < V_PERIODENDDATE --TO_DATE('2014-5-1', 'YYYY-MM-DD')
                                  AND K.EFFECTIVEENDDATE > V_PERIODSTARTDATE --TO_DATE('2014-4-14', 'YYYY-MM-DD')
                                 )
         */
         -- modified by zhubin 20140624 replace the V_PERIODSTARTDATE with V_PERIODENDDATE
         /*
         AND PAD.EFFECTIVESTARTDATE < V_PERIODENDDATE
         AND PAD.EFFECTIVEENDDATE >  V_PERIODSTARTDATE
         */
         AND PAD.EFFECTIVESTARTDATE < V_PERIODENDDATE
         AND PAD.EFFECTIVEENDDATE >=  V_PERIODENDDATE
         --modified by zhubin 20140624
         AND PAR.PAYEESEQ = PAD.PARTICIPANTSEQ
         AND par.payeeseq=pro.payeeseq
         AND par.effectivestartdate=pro.effectivestartdate
         AND par.removedate=pro.removedate
         AND PAR.REMOVEDATE = C_REMOVEDATE
         AND STA.REMOVEDATE = C_REMOVEDATE
/*         AND PAR.EFFECTIVESTARTDATE <= pad.effectivestartdate
         AND PAR.EFFECTIVEENDDATE >= pad.effectiveenddate*/
         AND STA.DATATYPESEQ = PRO.STATUSCODESEQ
         AND V_PERIODENDDATE-1 BETWEEN PAD.EFFECTIVESTARTDATE AND PAD.EFFECTIVEENDDATE -1
         AND V_PERIODENDDATE-1 BETWEEN PAR.EFFECTIVESTARTDATE AND PAR.EFFECTIVEENDDATE - 1
         AND AOASD.EARNING_CODE IS NOT NULL
         AND AOASD.COMPENSATION_DATE BETWEEN V_PERIODSTARTDATE AND V_PERIODENDDATE - 1
       --  AND AOASD.COMPENSATION_DATE BETWEEN PAD.EFFECTIVESTARTDATE AND PAD.EFFECTIVEENDDATE -1
       --  AND AOASD.COMPENSATION_DATE BETWEEN PAR.EFFECTIVESTARTDATE AND PAR.EFFECTIVEENDDATE - 1
      ;
      --add by zjc 20140702, remove old scheme records which datasource in('LA','IGM')
      delete from aia_old_scheme_dtl t
      where t.compensation_date between V_PERIODSTARTDATE and V_PERIODENDDATE-1
      and (t.datasource <>'LFCM' -- in ('LA','IGM')
          OR t.datasource IS NULL)
      and t.status_code = 'Terminated'
      and t.status_name = 'Vesting Rights';


  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  ------Suspended No Payout
  PROCEDURE AIA_OLD_SCHEME_DATA_NOPAYOUT IS
  BEGIN
    DELETE FROM AIA_SUSPEND_NOPAYOUT T
     WHERE T.COMPENSATION_DATE BETWEEN V_PERIODSTARTDATE AND V_PERIODENDDATE - 1;
    INSERT INTO AIA_SUSPEND_NOPAYOUT
      (PAYEE_ID,
       POSITIONNAME,
       POLICY_NO,
       EARNING_CODE,
       PRODUCTID,
       CHANNEL,
       COMPENSATION_DATE,
       RATE,
       VALUE,
       STATUS,
       BATCHNAME,
       CREATE_DATE)
      SELECT AOSD.PRODUCERCODE,
             AOSD.POSITIONNAME,
             AOSD.POLICY_NO,
             AOSD.EARNING_CODE,
             AOSD.PRODUCTID,
             AOSD.CHANNEL,
             AOSD.COMPENSATION_DATE,
             AOSD.RATE,
             AOSD.VALUE,
             AOSD.STATUS_CODE || ':' || AOSD.STATUS_NAME,
             AOSD.BATCHNAME,
             SYSDATE
        FROM AIA_OLD_SCHEME_DTL AOSD
       WHERE CASE
               WHEN (AOSD.STATUS_CODE || ':' || AOSD.STATUS_NAME) IN
                    ('Terminated:Resignation',
                     'Terminated:Termination',
                     'Terminated:Fraud Case',
                     'Terminated:Mis-Conduct') AND
                    AOSD.TERMINATIONDATE < V_PERIODSTARTDATE THEN
                1
             -- no need to remove as suspended agent will still insert into table, even it need to generate into agent stmt
               WHEN (AOSD.STATUS_CODE || ':' || AOSD.STATUS_NAME) = 'Suspended:Suspend' THEN
                1
               ELSE
                0
             END = 1;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  ------Terminated status
  PROCEDURE AIA_OLD_SCHEME_DATA_MORTGAGE IS
  BEGIN
    DELETE FROM AIA_MORTGAGE_TERMINATED T
     WHERE T.COMPENSATION_DATE BETWEEN V_PERIODSTARTDATE AND V_PERIODENDDATE - 1;
    INSERT INTO AIA_MORTGAGE_TERMINATED
      (PAYEE_ID,
       POSITIONNAME,
       POLICY_NO,
       EARNING_CODE,
       PRODUCTID,
       CHANNEL,
       COMPENSATION_DATE,
       RATE,
       VALUE,
       STATUS,
       BATCHNAME,
       CREATE_DATE)
      SELECT AOSD.PRODUCERCODE,
             AOSD.POSITIONNAME,
             AOSD.POLICY_NO,
             AOSD.EARNING_CODE,
             AOSD.PRODUCTID,
             AOSD.CHANNEL,
             AOSD.COMPENSATION_DATE,
             AOSD.RATE,
             AOSD.VALUE,
             AOSD.STATUS_CODE || ':' || AOSD.STATUS_NAME,
             AOSD.BATCHNAME,
             SYSDATE
        FROM AIA_OLD_SCHEME_DTL AOSD
       WHERE AOSD.POSITIONTITLE IN ('Tied Agency-UM',
                                    'Tied Agency-DM',
                                    'Tied Agency-Agent',
                                    'Tied Agency-ALC')
         AND AOSD.EARNING_CODE = C_EARNING_CODE(8)
         AND AOSD.STATUS_CODE = 'Terminated';
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_AGENT_ID IS
  BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE AIA_AGENT_ID';
    INSERT INTO AIA_AGENT_ID
      (RECORDNO,
       PRODUCERCODE,
       --    PRODUCERNAME,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       CREATE_DATE)
      SELECT ROWNUM,
             CODE,
             --         NAME,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             SYSDATE
        FROM (SELECT DISTINCT T.CODE --, T.NAME
                FROM AIA_AGT_STMT T
               WHERE T.PERIODKEY = V_PERIODKEY
              --AND t.code NOT IN ('T1430','T1996','1024A','12810')
               ORDER BY T.CODE);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  /*this procedure is for the new scheme of agent statement??
  It will get records from credit ,transaction level
  */
  PROCEDURE AIA_AGT_STMT_PROC IS
    ------Duration 9999 for APF 7 year
    ------Duration 10000 for Commission and Override
    ------sub_total_group 1 for first year commission and overriding
    ------sub_total_group 2 for renewal year commission and overriding
    ------sub_total_group 3 for 7 year commission and overriding
    ------sub_total_group 4 for miscellaneous
    ------sub_total_group 10000 for prior total balance, should be hide in detail report
  BEGIN

    DELETE FROM AIA_AGT_STMT AAS
     WHERE AAS.CALENDARNAME = V_CALENDARNAME
       AND AAS.PERIODNAME = V_PERIODNAME;
    DELETE FROM AIA_AGT_STMT_TOTAL T
     WHERE T.CALENDARNAME = V_CALENDARNAME
       AND T.PERIODNAME = V_PERIODNAME;
    /*DELETE FROM AIA_AGT_STMT_MISC T
    WHERE T.CALENDARNAME = V_CALENDARNAME
      AND T.PERIODNAME = V_PERIODNAME;*/

    INSERT INTO AIA_AGT_STMT
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       TRANSACTIONFACTKEY,
       EVENTTYPE,
       CREDITFACTKEY,
       --CREDITRULETYPE,
       CREDITTYPE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       OFFICE,
       --AGENCY,
       PRM_TYPE,
       LOB,
       COMMISSION_TYPE,
       COVERAGE_ID,
       PRD_END_DATE,
       STATUS,
       NAME,
       CODE,
       IC_NUMBER,
       REGION,
       POLICY,
       INSURED,
       REF,
       ISSUE_DATE,
       DUE_DATE, --PTD
       TRAN_DATE,
       DUR,
       PREM_MODE,
       PLAN,
       PREMIUM,
       SHARE_PCT, ------
       COMM_PCT,
       COMM,
       PERS_BONUS,
       APF,
       AGT_WS,
       CREATE_DATE,
       SUB_TOTAL_GROUP,
       TAX_IND)
      SELECT PAD.PAKEY,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             TXF.TRANSACTIONFACTKEY,
             TXDM.EVENTTYPE,
             CRDF.CREDITFACTKEY,
             --CRDD.CREDITRULETYPE,
             CRDM.CREDITTYPE,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             --'Office' OFFICE,
             NULL OFFICE,
             --'Agency' AGENCY,
             TXD.TRANSACTIONGENERICATTRIBUTE2 PRM_TYPE,
             UPPER(TXD.TRANSACTIONGENERICATTRIBUTE4) LOB,
             --EARD.EARNINGCODE                 COMMISSION_TYPE,
             CRDT.GENERICATTRIBUTE8           COMMISSION_TYPE,
             TXD.TRANSACTIONGENERICATTRIBUTE6 COVERAGE_ID,
             V_PERIODENDDATE                  PRD_END_DATE,
             PaD.PRODUCERSTATUS              STATUS,
             --PROD.PRODUCERTYPENAME AGENT_TYPE,
             PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME ||
             PAD.SUFFIX NAME,
             PAD.PARTICIPANTID CODE,
             PaD.NATIONALPRODUCERID IC_NUMBER,
             PAD.genericattribute4  REGION,--participantgenericattribute4
             --TXF.ORDERID POLICY,
             --SUBSTR(TXF.ORDERID, 11, 8) POLICY,
             TXD.TRANSACTIONGENERICATTRIBUTE20 POLICY,
             TXD.TRANSACTIONGENERICATTRIBUTE23 INSURED,
             NULL                              REF, --FOR PHASE1A IS BLANK
             TXD.TRANSACTIONGENERICDATE2       ISSUE_DATE,
             TXD.TRANSACTIONGENERICDATE4       DUE_DATE, --PTD
             TIMD.CALENDARDATE                 TRAN_DATE,
             TXD.TRANSACTIONGENERICNUMBER1     DUR, ------
             --TXD.TRANSACTIONGENERICATTRIBUTE1 PREM_MODE,
             CASE
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 IN ('00', '99', '12') THEN
                'A'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '01' THEN
                'M'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '03' THEN
                'Q'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '06' THEN
                'SA'
               ELSE
                NULL
             END PREM_MODE,
             TXD.PRODUCTID PLAN,
             TXD.TRANSACTIONGENERICNUMBER6 PREMIUM,
             --NULL SHARE_PCT, ------FOR PHASE1A IS BLANK
             DECODE(TXD.TRANSACTIONGENERICNUMBER5,
                    1,
                    NULL,
                    TXD.TRANSACTIONGENERICNUMBER5) * 100 SHARE_PCT,
             CASE
               WHEN TXDM.EVENTTYPE LIKE '%Commissions' THEN
                NVL(TXD.TRANSACTIONGENERICNUMBER2, 0)
               ELSE
                DECODE(CRDF.VALUE, 0, 0, NVL(CRDT.GENERICNUMBER3, 0) / CRDF.VALUE)
             END * 100 COMM_PCT,
             /*CASE
               WHEN TXDM.EVENTTYPE LIKE '%Commissions' THEN
                TXF.VALUE
               ELSE
               --NVL(TXD.TRANSACTIONGENERICNUMBER6, 0) * NVL(CRDT.GENERICNUMBER4, 0)
                NVL(CRDT.GENERICNUMBER3, 0)
             END COMM,*/
             NVL(CRDT.GENERICNUMBER3, 0) COMM,
             --TXD.TRANSACTIONGENERICNUMBER2 COMM_PCT,
             --TXF.VALUE                     COMM,
             0 PERS_BONUS, --FOR PHASE1A IS BLANK
             0 APF, --FOR PHASE1A IS BLANK
             --NULL AGT_WS, --CS_TRANSACTIONASSIGNMENT.GENERICBOOLEAN1,
             CASE
               WHEN TXD.TRANSACTIONGENERICBOOLEAN1 = 1 THEN
                'W'
               WHEN TXD.TRANSACTIONGENERICBOOLEAN1 = 0 THEN
                'S'
               ELSE
                ''
             END AGT_WS,
             SYSDATE,
             CASE
               WHEN TXD.TRANSACTIONGENERICNUMBER1 = 1 THEN
                1
               WHEN TXD.TRANSACTIONGENERICNUMBER1 > 1 AND
                    TXD.TRANSACTIONGENERICNUMBER1 < 7 THEN
                2
               WHEN TXD.TRANSACTIONGENERICNUMBER1 < 10000 THEN
                3
               ELSE
                10000
             END SUB_TOTAL_GROUP,
             --'Y'
             DECODE(TXD.TRANSACTIONGENERICATTRIBUTE18, 'N', 'N', 'Y')
        FROM /*PADIMENSION          PAD,
             PRODUCERDIMENSION    PROD,*/
             AIA_PAYEE_INFOR pad,
             TRANSACTIONFACT      TXF,
             TRANSACTIONDETAIL    TXD,
             TRANSACTIONDIMENSION TXDM,
             CREDITFACT           CRDF,
             CREDITDIMENSION      CRDM,
             --CREDITRULEDIMENSION  CRDD,
             CREDITDETAIL         CRDT,
             TIMEDIMENSION        TIMD
       WHERE TXF.TRANSACTIONDETAILKEY = TXD.TRANSACTIONDETAILKEY
         AND TXF.TRANSACTIONKEY = TXDM.TRANSACTIONKEY
         AND TXF.TRANSACTIONFACTKEY = CRDF.TRANSACTIONFACTKEY
         AND CRDF.PAKEY = PAD.PAKEY
         AND CRDF.PERIODKEY = V_PERIODKEY
         AND TXF.ACCOUNTINGTIMEKEY = TIMD.TIMEKEY
         AND PAD.POSITIONTITLE IN ('Tied Agency-UM',
                                   'Tied Agency-DM',
                                   'Tied Agency-Agent',
                                   'Tied Agency-ALC',
                                    'Broker-Agent',
                                    'Broker-Leader',
                                    'IFA-FA Leader',
                                    'IFA-FAR')
         AND (TXDM.EVENTTYPE LIKE '%Commissions' OR
             TXDM.EVENTTYPE LIKE '%Premiums' OR
             TXDM.EVENTTYPE = 'Extra Premium for Loading')
         AND CRDF.CREDITDETAILKEY = CRDT.CREDITDETAILKEY
         AND TXDM.ORIGINID != C_ORIGINID_MANUAL
         AND CRDT.GENERICATTRIBUTE8 IS NOT NULL
         AND CRDF.CREDITKEY = CRDM.CREDITKEY
         and crdm.credittype <> 'FYP PO For Gen1';

    DELETE FROM AIA_AGT_STMT T
     WHERE T.CALENDARNAME = V_CALENDARNAME
       AND T.PERIODNAME = V_PERIODNAME
       AND T.COMMISSION_TYPE NOT IN (C_EARNING_CODE(1),
                                     C_EARNING_CODE(2),
                                     C_EARNING_CODE(3),
                                     C_EARNING_CODE(4),
                                     C_EARNING_CODE(5),
                                     C_EARNING_CODE(6),
                                     C_EARNING_CODE(7),
                                     C_EARNING_CODE(8));

    /* update DM_positionname to ALC_positionname */

      UPDATE AIA_AGT_STMT A
       SET (A.PAKEY,
            A.EFFECTIVESTARTDATE,
            A.EFFECTIVEENDDATE,
            A.POSITIONSEQ,
            A.MANAGERSEQ,
            A.POSITIONNAME,
            A.POSITIONTITLE,
            A.STATUS,
            A.NAME,
            A.CODE,
            A.IC_NUMBER,
            A.REGION,
            A.FROM_DM) =
           (SELECT ALC.PAKEY,
                   ALC.EFFECTIVESTARTDATE,
                   ALC.EFFECTIVEENDDATE,
                   ALC.POSITIONSEQ,
                   DM.MANAGERSEQ,
                   ALC.POSITIONNAME,
                   ALC.POSITIONTITLE,
                   ALC.PRODUCERSTATUS,
                   ALC.PREFIX || ALC.FIRSTNAME || ALC.MIDDLENAME || ALC.LASTNAME ||
                   ALC.SUFFIX,
                   ALC.PARTICIPANTID,
                   ALC.NATIONALPRODUCERID,
                   ALC.GENERICATTRIBUTE4,
                   A.POSITIONSEQ
              FROM AIA_PAYEE_INFOR ALC,
               CS_POSITION DM,
               CS_POSITIONRELATION PR,
               CS_POSITIONRELATIONTYPE PRT
             WHERE DM.RULEELEMENTOWNERSEQ=PR.CHILDPOSITIONSEQ
               AND ALC.POSITIONSEQ=PR.PARENTPOSITIONSEQ
               AND DM.RULEELEMENTOWNERSEQ=A.POSITIONSEQ
               AND DM.NAME = A.POSITIONNAME
               AND dm.effectivestartdate<PR.EFFECTIVEENDDATE
               AND dm.effectiveenddate>PR.EFFECTIVESTARTDATE
               AND DM.REMOVEDATE=C_REMOVEDATE
               AND alc.effectivestartdate<PR.EFFECTIVEENDDATE
               AND alc.effectiveenddate>PR.EFFECTIVESTARTDATE
               AND ALC.REMOVEDATE=C_REMOVEDATE
               AND PR.EFFECTIVESTARTDATE < V_PERIODENDDATE --'01-May-2014'
               AND PR.EFFECTIVEENDDATE > V_PERIODENDDATE --'14-Apr-2014'
               AND PR.REMOVEDATE=C_REMOVEDATE
               --AND DM.POSITIONTITLE = 'Tied Agency-DM'
               AND PR.POSITIONRELATIONTYPESEQ=PRT.DATATYPESEQ
               AND PRT.REMOVEDATE=C_REMOVEDATE
               AND PRT.NAME = 'ALC_Roll'
               AND ALC.POSITIONTITLE = 'Tied Agency-ALC'
               AND DM.GENERICBOOLEAN4 = 1
               AND ROWNUM = 1)
     WHERE A.PERIODKEY = V_PERIODKEY
       AND A.COMMISSION_TYPE IN
           (C_EARNING_CODE(3), C_EARNING_CODE(4), C_EARNING_CODE(5), C_EARNING_CODE(6))
       AND EXISTS (SELECT 1
              FROM PADIMENSION T
             WHERE T.POSITIONGENERICBOOLEAN4 = 1
               AND T.PAKEY = A.PAKEY)
       AND A.POSITIONTITLE='Tied Agency-DM'
       AND A.CREDITTYPE <> 'FYP PO For Gen1'; -- PO G1 not give to ALC until the end of year
    --------old scheme
    AIA_AGT_STMT_OLD_PROC;

    -- UPDATE ALC pakey and managerseq
    UPDATE AIA_AGT_STMT T
       SET (T.PAKEY, T.MANAGERSEQ) =
           (SELECT K.PAKEY, K.MANAGERSEQ
              FROM PADIMENSION K
             WHERE K.PAKEY = (SELECT MAX(A.PAKEY)
                                FROM AIA_AGT_STMT A
                               WHERE A.PERIODKEY = V_PERIODKEY
                                 AND A.POSITIONNAME = K.POSITIONNAME)

               AND K.EFFECTIVESTARTDATE < V_PERIODENDDATE
               AND K.EFFECTIVEENDDATE > V_PERIODSTARTDATE
               AND T.POSITIONNAME = K.POSITIONNAME
               AND ROWNUM = 1)
     WHERE T.POSITIONTITLE = 'Tied Agency-ALC'
       AND T.PERIODKEY = V_PERIODKEY;
    COMMIT;
    ------------------
    --------MISC
    INSERT INTO AIA_AGT_STMT
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       STATUS,
       NAME,
       CODE,
       LOB,
       COMMISSION_TYPE,
       POLICY,
       INSURED,
       REF,
       TRAN_DATE,
       COMM,
       SUB_TOTAL_GROUP,
       TAX_IND,
       CREATE_DATE)
      SELECT PAD.PAKEY,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             PaD.PRODUCERSTATUS,
             PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME ||
             PAD.SUFFIX NAME,
             PAD.PARTICIPANTID,
             C_EARNING_CODE(101) LOB,
             C_EARNING_CODE(29) COMMISSION_TYPE, --'Miscellaneous'
             DEPD.EARNINGCODEID,
             NULL, ------Description
             NULL REF,
             NULL TRAN_DATE,
             DEPF.VALUE,
             4,
             'Y',
             SYSDATE
        FROM --PADIMENSION       PAD,
             --PRODUCERDIMENSION PROD,
             AIA_PAYEE_INFOR pad,
             DEPOSITFACT       DEPF,
             DEPOSITDIMENSION  DEPD
       WHERE DEPF.PERIODKEY = V_PERIODKEY
       AND DEPF.PAKEY = PAD.PAKEY
       AND DEPF.DEPOSITKEY = DEPD.DEPOSITKEY
       AND DEPD.EARNINGCODEID IN (C_EARNING_CODE(11),
                              C_EARNING_CODE(12),
                              C_EARNING_CODE(13),
                              C_EARNING_CODE(14),
                              C_EARNING_CODE(15),
                              C_EARNING_CODE(16),
                              C_EARNING_CODE(17),
                              C_EARNING_CODE(18),
                              C_EARNING_CODE(19),
                              C_EARNING_CODE(20),
                              C_EARNING_CODE(21),
                              C_EARNING_CODE(22),
                              C_EARNING_CODE(23))
       AND PAD.POSITIONTITLE IN ('Tied Agency-UM',
                             'Tied Agency-DM',
                             'Tied Agency-Agent',
                             'Tied Agency-ALC',
                              'Broker-Agent',
                              'Broker-Leader',
                              'IFA-FA Leader',
                              'IFA-FAR')

      -- Production Bonus , Just for MayB, After MayB , remove this condition
/*      and case
          when DEPD.EARNINGCODEID = C_EARNING_CODE(12)  and DEPF.Value = 0
          then 0
          else 1
       end = 1*/
      ------

      UNION ALL
      SELECT PAD.PAKEY,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             PaD.PRODUCERSTATUS,
             PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME ||
             PAD.SUFFIX NAME,
             PAD.PARTICIPANTID,
             UPPER(TXD.TRANSACTIONGENERICATTRIBUTE4) LOB,
             C_EARNING_CODE(29) COMMISSION_TYPE, --'Miscellaneous'
             TXDM.EVENTTYPE,
             TXD.COMMENTS DESCRIPTION,
             -- Add by Jason 17-04-2014, Special handling for April A 2014, pls remove after workflow
             /*CASE
               WHEN TXDM.Eventtype LIKE '%Balance%' THEN
                    TXDM.EVENTTYPE
               ELSE
                  TXD.COMMENTS
             END DESCRIPTION,   */
             NULL              REF,
             TIMD.CALENDARDATE TRAN_DATE,
             TXF.VALUE,
             4,
             --'Y',-- CHANGE BY Corey 20140527
             DECODE(TXD.TRANSACTIONGENERICATTRIBUTE18, 'N', 'N', 'Y'),
             -- #### Add by Jason 17-04-2014, Special handling for April A 2014, pls remove after workflow
             /*             CASE
               WHEN TXDM.Eventtype LIKE '%Balance%' THEN
                  'N'
               ELSE
                  'Y'
             END TAX_IND,*/
             SYSDATE
        FROM --PADIMENSION          PAD,
             --PRODUCERDIMENSION    PROD,
             AIA_PAYEE_INFOR pad,
             TRANSACTIONFACT      TXF,
             TRANSACTIONDETAIL    TXD,
             TRANSACTIONDIMENSION TXDM,
             CREDITFACT           CRDF,
             TIMEDIMENSION        TIMD
       WHERE TXF.TRANSACTIONDETAILKEY = TXD.TRANSACTIONDETAILKEY
         AND TXF.TRANSACTIONKEY = TXDM.TRANSACTIONKEY
         AND TXF.TRANSACTIONFACTKEY = CRDF.TRANSACTIONFACTKEY
         AND CRDF.PAKEY = PAD.PAKEY
         AND CRDF.PERIODKEY = V_PERIODKEY
         AND TXF.ACCOUNTINGTIMEKEY = TIMD.TIMEKEY
         AND (TXDM.EVENTTYPE IN
             (C_EARNING_CODE(25), C_EARNING_CODE(26), C_EARNING_CODE(27))
             /*   --#### Add by Jason 17-04-2014, Special handling for April A 2014, pls remove after workflow
             OR TXDM.EVENTTYPE LIKE '%Balance%'*/
             )
         AND PAD.POSITIONTITLE IN ('Tied Agency-UM',
                                   'Tied Agency-DM',
                                   'Tied Agency-Agent',
                                   'Tied Agency-ALC',
                                    'Broker-Agent',
                                    'Broker-Leader',
                                    'IFA-FA Leader',
                                    'IFA-FAR');
    COMMIT;

    --------insert into Agent Statement just exists in Prior Balance
    --------these records no need show in detail report
    --------let commission_type blank, and set sub_total_group to 10000
    INSERT INTO AIA_AGT_STMT
      (PAKEY,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       STATUS,
       NAME,
       CODE,
       LOB,
       DUR,
       MISC_FLAG,
       SUB_TOTAL_GROUP,
       CREATE_DATE)
      SELECT /*+parallel*(T,4)*/
      DISTINCT PAY.PAKEY,
               V_PERIODKEY,
               V_CALENDARNAME,
               V_PERIODNAME,
               V_PERIODSTARTDATE,
               V_PERIODENDDATE,
               PAY.POSITIONSEQ,
               PAY.MANAGERSEQ,
               PAY.POSITIONNAME,
               PAY.POSITIONTITLE,
               PAY.PRODUCERSTATUS,
               PAY.PREFIX || PAY.FIRSTNAME || PAY.MIDDLENAME || PAY.LASTNAME ||
               PAY.SUFFIX NAME,
               T.CODE,
               T.LOB,
               10000,
               0,
               10000,
               SYSDATE
        FROM AIA_AGT_STMT_TOTAL T,
             AIA_PAYEE_INFOR PAY--, padimension PAY
        WHERE T.PERIODKEY = V_PRIOR_PERIODKEY
       --  AND T.Pakey = pay.pakey
        and t.positionname = pay.positionname
        AND PAY.REMOVEDATE = C_REMOVEDATE
        and V_PERIODENDDATE between pay.effectivestartdate and pay.effectiveenddate
         AND NOT EXISTS
       (SELECT 1
                FROM AIA_AGT_STMT AAS
               WHERE AAS.PERIODKEY = V_PERIODKEY
                 AND AAS.CODE = T.CODE
                 AND AAS.LOB = T.LOB)
         AND (T.CLOSING_BAL_AMOUNT != 0 OR T.CLOSING_BAL_APF != 0);

    COMMIT;
    ------Insert Agent ID
    AIA_AGENT_ID;
    ------update lob and earning_code seq
    UPDATE AIA_AGT_STMT T
       SET T.LOB_SEQ          = CASE T.LOB
                                  WHEN C_EARNING_CODE(101) THEN
                                   1
                                  WHEN C_EARNING_CODE(102) THEN
                                   2
                                  WHEN C_EARNING_CODE(103) THEN
                                   3
                                  WHEN C_EARNING_CODE(104) THEN
                                   4
                                  WHEN C_EARNING_CODE(105) THEN
                                   5
                                  WHEN C_EARNING_CODE(106) THEN
                                   6
                                  WHEN C_EARNING_CODE(107) THEN
                                   7
                                  WHEN C_EARNING_CODE(108) THEN
                                   8
                                  WHEN C_EARNING_CODE(109) THEN
                                   9
                                  WHEN C_EARNING_CODE(110) THEN
                                   10
                                  WHEN C_EARNING_CODE(111) THEN
                                   11
                                  ELSE
                                   12
                                END,
           T.EARNING_CODE_SEQ = CASE T.COMMISSION_TYPE
                                  WHEN C_EARNING_CODE(1) THEN
                                   1
                                  WHEN C_EARNING_CODE(2) THEN
                                   2
                                  WHEN C_EARNING_CODE(3) THEN
                                   3
                                  WHEN C_EARNING_CODE(4) THEN
                                   4
                                  WHEN C_EARNING_CODE(5) THEN
                                   5
                                  WHEN C_EARNING_CODE(6) THEN
                                   6
                                  WHEN C_EARNING_CODE(7) THEN
                                   7
                                  WHEN C_EARNING_CODE(8) THEN
                                   8
                                  WHEN C_EARNING_CODE(29) THEN
                                   9
                                  ELSE
                                   10
                                END,
           T.UPDATE_DATE      = SYSDATE
     WHERE T.PERIODKEY = V_PERIODKEY;
    --------update APF's comm and apf
    --------adjust comm to 0, and apf to comm
    UPDATE AIA_AGT_STMT AAS
       SET AAS.COMM = 0, AAS.APF = AAS.COMM
     WHERE AAS.PERIODKEY = V_PERIODKEY
       AND AAS.COMMISSION_TYPE = C_EARNING_CODE(2);
    COMMIT;

      UPDATE Aia_Agt_Stmt T
         SET T.PAKEY = (SELECT MAX(PAKEY)
                          FROM AIA_AGT_STMT K
                         WHERE K.CODE = T.CODE
                           AND K.PERIODKEY = T.PERIODKEY)
       WHERE /*T.POSITIONNAME = 'Z0777'
             AND*/
       T.PERIODKEY = V_PERIODKEY;


       -- DELETE (nvl(comm,0) = 0 and nvl(apf,0) = 0 )
      DELETE
      FROM AIA_AGT_STMT T
      WHERE T.PERIODKEY = V_PERIODKEY
      AND NVL(T.COMM,0) = NVL(T.APF,0)
      AND NVL(T.COMM,0) = 0
      AND T.DUR <> 10000; -- used for pass balance to next period

    --------Total fields
    INSERT INTO AIA_AGT_STMT_TOTAL
      (RECORDNO,
       PAKEY,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       STATUS,
       NAME,
       CODE,
       LOB,
       TOTAL_1YEAR_COUNT,
       TOTAL_1YEAR_PREMIUM,
       TOTAL_1YEAR_COMM,
       TOTAL_1YEAR_APF,
       TOTAL_RENEWAL_COUNT,
       TOTAL_RENEWAL_PREMIUM,
       TOTAL_RENEWAL_COMM,
       TOTAL_RENEWAL_APF,
       TOTAL_7YEAR_COUNT,
       TOTAL_7YEAR_PREMIUM,
       TOTAL_7YEAR_COMM,
       TOTAL_7YEAR_APF,
       CREATE_DATE)
      SELECT M.RECORDNO,
             T.PAKEY,
             T.PERIODKEY,
             T.CALENDARNAME,
             T.PERIODNAME,
             T.PERIODSTARTDATE,
             T.PERIODENDDATE,
             T.POSITIONSEQ,
             T.MANAGERSEQ,
             T.POSITIONNAME,
             T.POSITIONTITLE,
             T.STATUS,
             T.NAME,
             T.CODE,
             T.LOB,
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 1 THEN
                    1
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 1 THEN
                    NVL(T.PREMIUM, 0)
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 1 THEN
                    NVL(T.COMM, 0)
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 1 THEN
                    NVL(T.APF, 0)
                   ELSE
                    0
                 END),

             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 2 THEN
                    1
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 2 THEN
                    NVL(T.PREMIUM, 0)
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 2 THEN
                    NVL(T.COMM, 0)
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 2 THEN
                    NVL(T.APF, 0)
                   ELSE
                    0
                 END),

             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 3 THEN
                    1
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 3 THEN
                    NVL(T.PREMIUM, 0)
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 3 THEN
                    NVL(T.COMM, 0)
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.SUB_TOTAL_GROUP = 3 THEN
                    NVL(T.APF, 0)
                   ELSE
                    0
                 END),
             SYSDATE
        FROM AIA_AGT_STMT T, AIA_AGENT_ID M
       WHERE T.PERIODKEY = V_PERIODKEY
         AND T.CODE = M.PRODUCERCODE
       GROUP BY M.RECORDNO,
                T.PAKEY,
                T.PERIODKEY,
                T.CALENDARNAME,
                T.PERIODNAME,
                T.PERIODSTARTDATE,
                T.PERIODENDDATE,
                T.POSITIONSEQ,
                T.MANAGERSEQ,
                T.POSITIONNAME,
                T.POSITIONTITLE,
                T.STATUS,
                T.NAME,
                T.CODE,
                T.LOB;
    COMMIT;

    --WRITING_AGT_CODE        UM       AM
    UPDATE AIA_AGT_STMT T
       SET (T.WRITING_AGT_CODE,
            T.W_AGENT_KEY,
            T.W_POSITION_SEQ,
            T.W_MANAGERSEQ,
            T.W_EFFECTIVESTARTDATE,
            T.W_POSITIONTITLE) =
           (SELECT PAD.PARTICIPANTID,
                   PAD.PAKEY,
                   PAD.POSITIONSEQ,
                   PAD.MANAGERSEQ,
                   PAD.EFFECTIVESTARTDATE,
                   PAD.POSITIONTITLE
              FROM CREDITFACT CRDF, CREDITRULEDIMENSION CRDD, PADIMENSION PAD
             WHERE CRDF.CREDITRULEKEY = CRDD.CREDITRULEKEY
               AND CRDD.CREDITRULETYPE = 'Direct Transaction Credit Rule'
               AND CRDF.TRANSACTIONFACTKEY = T.TRANSACTIONFACTKEY
               AND CRDF.PAKEY = PAD.PAKEY
               AND PAD.REMOVEDATE = C_REMOVEDATE
               AND CRDD.REMOVEDATE = C_REMOVEDATE
               AND PAD.POSITIONTITLE != 'Tied Agency-Agency'
               AND ROWNUM = 1)
     WHERE T.PERIODKEY = V_PERIODKEY
       AND T.TRANSACTIONFACTKEY IS NOT NULL; ------just for new scheme

    UPDATE AIA_AGT_STMT T
       SET (T.UM, T.DM) =
           (SELECT m.MANAGER, m.GRANDMANAGER
              FROM AIA_PAYEE_INFOR m
             WHERE m.PAKEY = T.W_AGENT_KEY
               AND ROWNUM = 1)
     WHERE T.PERIODKEY = V_PERIODKEY
       AND T.TRANSACTIONFACTKEY IS NOT NULL; ------just for new scheme

-- modified by zhubin 20140626 get the agency_code, agency_name from ODS replace the PAROLL
    ---------update Agency
    /*UPDATE AIA_AGT_STMT AAS
       SET (AAS.AGENCY_CODE, AAS.AGENCY_NAME) =
           (SELECT PAD2.PARTICIPANTID,
                   PAD2.PREFIX || PAD2.FIRSTNAME || PAD2.MIDDLENAME || PAD2.LASTNAME ||
                   PAD2.SUFFIX
              FROM PADIMENSION PAD1, PAROLL PAR, PADIMENSION PAD2
             WHERE PAD1.POSITIONSEQ = DECODE(AAS.POSITIONTITLE,
                                             'Tied Agency-Agent',
                                             AAS.MANAGERSEQ,
                                             'Tied Agency-ALC',
                                             AAS.FROM_DM,
                                             AAS.POSITIONSEQ)
               AND PAD1.REMOVEDATE = C_REMOVEDATE
               AND PAD1.EFFECTIVESTARTDATE < AAS.EFFECTIVEENDDATE
               AND PAD1.EFFECTIVEENDDATE > AAS.EFFECTIVESTARTDATE
               AND PAR.ROLLTYPE = 'Assigned_Roll'
               AND PAR.REMOVEDATE = C_REMOVEDATE
               AND PAR.FROMPAKEY = PAD1.PAKEY
               AND PAR.TOPAKEY = PAD2.PAKEY
               AND PAD2.REMOVEDATE = C_REMOVEDATE
               AND ROWNUM = 1)
     WHERE AAS.PERIODKEY = V_PERIODKEY;*/
  -- update Agent_Code, Agent_Name of Tied Agency
  UPDATE AIA_AGT_STMT AAS
     SET (AAS.AGENCY_CODE, AAS.AGENCY_NAME) =
     (select posa.name,
             par.PREFIX || par.FIRSTNAME || par.MIDDLENAME|| par.LASTNAME || par.SUFFIX
                                                 from cs_participant par,
                                                      cs_position    posa
                                                where par.payeeseq =
                                                      posa.payeeseq
                                                  and par.removedate =
                                                      C_REMOVEDATE
                                                  and posa.removedate =
                                                      C_REMOVEDATE
                                                  and par.effectivestartdate <=
                                                      V_PERIODENDDATE
                                                  and par.effectiveenddate >
                                                      V_PERIODENDDATE
                                                  and posa.effectivestartdate <=
                                                      V_PERIODENDDATE
                                                  and posa.effectiveenddate >
                                                      V_PERIODENDDATE
                                                  and posa.ruleelementownerseq IN
                                                 --query the postionseq of unit code
                                                    (select max(cspr.childpositionseq)
                                                     from cs_position  csp,
                                                     cs_positionrelation cspr
                                                     where cspr.parentpositionseq =
                                                     csp.ruleelementownerseq
                                                     and cspr.positionrelationtypeseq =
                                                       (--query the Assigned_Roll relationSEQ
                                                        select relt.datatypeseq
                                                        from cs_positionrelationtype relt
                                                        where relt.name ='Assigned_Roll'
                                                        and relt.removedate = C_REMOVEDATE)
                                                     and csp.removedate = C_REMOVEDATE
                                                     and cspr.removedate =C_REMOVEDATE
                                                     and csp.effectivestartdate <=
                                                     V_PERIODENDDATE
                                                     and csp.effectiveenddate > V_PERIODENDDATE
                                                     and cspr.effectivestartdate <=
                                                     V_PERIODENDDATE
                                                     and cspr.effectiveenddate > V_PERIODENDDATE
                                                     and csp.ruleelementownerseq =
                                                       DECODE(AAS.POSITIONTITLE,
                                                              'Tied Agency-Agent',
                                                              AAS.MANAGERSEQ,
                                                              'Tied Agency-ALC',
                                                              AAS.FROM_DM,
                                                              AAS.POSITIONSEQ)))
                       where AAS.Periodkey = V_PERIODKEY
                       and AAS.Positiontitle like '%Tied Agency%';
    --update the Agent_CODE, Agent_NAME of IFA /BROKER
    UPDATE AIA_AGT_STMT AAS
     SET (AAS.AGENCY_CODE, AAS.AGENCY_NAME) =
         --JUST QUERY THE MANAGER OF IFA
         (select posa.name,
             par.PREFIX || par.FIRSTNAME || par.MIDDLENAME|| par.LASTNAME || par.SUFFIX
                                                 from cs_participant par,
                                                      cs_position    posa
                                                where par.payeeseq =
                                                      posa.payeeseq
                                                  and par.removedate =
                                                      C_REMOVEDATE
                                                  and posa.removedate =
                                                      C_REMOVEDATE
                                                  and par.effectivestartdate <
                                                      V_PERIODENDDATE
                                                  and par.effectiveenddate >=
                                                      V_PERIODENDDATE
                                                  and posa.effectivestartdate <
                                                      V_PERIODENDDATE
                                                  and posa.effectiveenddate >=
                                                      V_PERIODENDDATE
                                                  and posa.ruleelementownerseq =
                                                  AAS.MANAGERSEQ
                                                  AND ROWNUM = 1
         )
     WHERE AAS.PERIODKEY = V_PERIODKEY
     AND AAS.POSITIONTITLE IN(  'Broker-Agent',
                                'Broker-Leader',
                                'IFA-FA Leader',
                                'IFA-FAR')
     AND AAS.MANAGERSEQ IS NOT NULL;
-- modified by zhubin 20140626
    --------update Rank Report To
    UPDATE AIA_AGT_STMT AAS
       SET AAS.RANK_REPORT_TO =
           (SELECT CASE
                     WHEN AAS.POSITIONTITLE = 'Tied Agency-DM' THEN
                      NULL
                     ELSE
                      PAD.PARTICIPANTID
                   END
              FROM PADIMENSION PAD
             WHERE PAD.POSITIONSEQ = AAS.MANAGERSEQ
               AND AAS.EFFECTIVESTARTDATE BETWEEN PAD.EFFECTIVESTARTDATE AND
                   PAD.EFFECTIVEENDDATE - 1
               AND PAD.REMOVEDATE = C_REMOVEDATE
               AND ROWNUM = 1)
     WHERE AAS.PERIODKEY = V_PERIODKEY;

    COMMIT;
    --############
    UPDATE AIA_AGT_STMT_TOTAL AAS
       SET AAS.BEGINING_BALANCE = NVL((SELECT T.CLOSING_BAL_AMOUNT
                                        FROM AIA_AGT_STMT_TOTAL T
                                       WHERE T.PERIODKEY = V_PRIOR_PERIODKEY
                                         AND T.CODE = AAS.CODE
                                         AND T.LOB = AAS.LOB
                                         AND ROWNUM = 1),
                                      0),
           (AAS.BEGINING_APF, AAS.PAYMENT_APF, AAS.CLOSING_BAL_APF) =
           (SELECT /*+parallel*(T,4)*/
             NVL(SUM(CASE
                       WHEN T.EARNING_CODE = C_EARNING_CODE(41) THEN
                        T.VALUE
                       ELSE
                        0
                     END),
                 0),
             0,
             NVL(SUM(CASE
                       WHEN T.EARNING_CODE = C_EARNING_CODE(42) THEN
                        T.VALUE
                       ELSE
                        0
                     END),
                 0)
              FROM AIA_OLD_SCHEME_DTL T
             WHERE T.PRODUCERCODE = AAS.CODE
               --AND T.COMPENSATION_DATE BETWEEN V_PERIODSTARTDATE AND V_PERIODENDDATE - 1
               AND T.PERIODKEY=AAS.PERIODKEY
               AND T.BUSINESS_LINE = AAS.LOB
               AND T.EARNING_CODE IN (C_EARNING_CODE(41), C_EARNING_CODE(42)))
     WHERE AAS.PERIODKEY = V_PERIODKEY
    -- AND AAS.POSITIONNAME = 'T0177'
    ;
    -- Suspended--------------------
    UPDATE AIA_AGT_STMT_TOTAL AAS
       SET --if status is Suspended ,get aia_agent_stmt.comm as closing_balance
           (AAS.PAYMENT_AMOUNT, AAS.CLOSING_BAL_AMOUNT) =
           (SELECT 0,
                   NVL((SELECT SUM(A.COMM)
                         FROM AIA_AGT_STMT A
                        WHERE A.PAKEY = AAS.PAKEY
                          AND A.PERIODKEY = AAS.PERIODKEY
                          AND A.LOB = AAS.LOB
                             ------
                          AND CASE
                                WHEN A.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                                     A.TAX_IND = 'N' AND
                                     (A.TRAN_DATE BETWEEN V_PERIODSTARTDATE AND
                                     V_PERIODENDDATE - 1) THEN
                                 1
                                ELSE
                                 0
                              END = 0
                             AND (A.CREDITTYPE <> 'FYP PO For Gen1' or A.credittype is null)
                          -- Gen1 should use an addtional way to calculate when the
                          -- period is the end of the year
                       ------
                       ),
                       0) + NVL(AAS.BEGINING_BALANCE, 0)
              FROM DUAL)
     WHERE AAS.PERIODKEY = V_PERIODKEY
       AND AAS.STATUS = 'Suspended'
        ;
    --not Suspended---------------------

    --
    UPDATE AIA_AGT_STMT_TOTAL AAS
       SET (AAS.PAYMENT_AMOUNT, AAS.CLOSING_BAL_AMOUNT) =
           (SELECT CASE
                     WHEN NVL((SELECT SUM(A.BEGINING_BALANCE)
                                FROM AIA_AGT_STMT_TOTAL A
                               WHERE A.PERIODKEY = V_PERIODKEY
                                 AND A.CODE = AAS.CODE),
                              0) +
                          NVL((SELECT SUM(T.COMM)
                                FROM AIA_AGT_STMT T
                               WHERE T.PERIODKEY = V_PERIODKEY
                                 AND T.CODE = AAS.CODE
                                 AND (T.CREDITTYPE <> 'FYP PO For Gen1' or T.credittype is null)
                                    ------
                                 AND CASE
                                       WHEN T.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                                            T.TAX_IND = 'N' AND
                                            (T.TRAN_DATE BETWEEN V_PERIODSTARTDATE AND
                                            V_PERIODENDDATE - 1) THEN
                                        1
                                       ELSE
                                        0
                                     END = 0),
                                     --20140710 start
                              0) >= 0--50
                                    --20140710 end
                     -- ALL LOB's Beginning Balance + all LOB's Comm  >= 50
                      THEN
                      NVL(AAS.BEGINING_BALANCE, 0) +
                      NVL((SELECT SUM(T.COMM)
                            FROM AIA_AGT_STMT T
                           WHERE T.PERIODKEY = V_PERIODKEY
                             AND T.CODE = AAS.CODE
                             AND (T.CREDITTYPE <> 'FYP PO For Gen1' or T.credittype is null)
                                ------
                             AND CASE
                                   WHEN T.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                                        T.TAX_IND = 'N' AND
                                        (T.TRAN_DATE BETWEEN V_PERIODSTARTDATE AND
                                        V_PERIODENDDATE - 1) THEN
                                    1
                                   ELSE
                                    0
                                 END = 0
                                ------
                             AND T.LOB = AAS.LOB),
                          0)
                   -- this lob's Beginning Balance + this lob's Comm
                     ELSE
                      0
                   END PAYMENT_AMOUNT,
                   CASE
                     WHEN NVL((SELECT SUM(A.BEGINING_BALANCE)
                                FROM AIA_AGT_STMT_TOTAL A
                               WHERE A.PERIODKEY = V_PERIODKEY
                                 AND A.CODE = AAS.CODE),
                              0) +
                          NVL((SELECT SUM(T.COMM)
                                FROM AIA_AGT_STMT T
                               WHERE T.PERIODKEY = V_PERIODKEY
                                 AND T.CODE = AAS.CODE
                                 AND (T.CREDITTYPE <> 'FYP PO For Gen1' or T.credittype is null)
                                    ------
                                 AND CASE
                                       WHEN T.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                                            T.TAX_IND = 'N' AND
                                            (T.TRAN_DATE BETWEEN V_PERIODSTARTDATE AND
                                            V_PERIODENDDATE - 1) THEN
                                        1
                                       ELSE
                                        0
                                     END = 0),
                                     --20140710 start
                              0) < 0-- 50
                                     --20140710 end
                              THEN
                     -- ALL LOB's Beginning Balance + all LOB's Comm  < 50
                      NVL(AAS.BEGINING_BALANCE, 0) +
                      NVL((SELECT SUM(T.COMM)
                            FROM AIA_AGT_STMT T
                           WHERE T.PERIODKEY = V_PERIODKEY
                             AND T.CODE = AAS.CODE
                             AND (T.CREDITTYPE <> 'FYP PO For Gen1' or T.credittype is null)
                                ------
                             AND CASE
                                   WHEN T.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                                        T.TAX_IND = 'N' AND
                                        (T.TRAN_DATE BETWEEN V_PERIODSTARTDATE AND
                                        V_PERIODENDDATE - 1) THEN
                                    1
                                   ELSE
                                    0
                                 END = 0
                                /*     AND T.COMPENSATION_DATE BETWEEN V_PERIODSTARTDATE AND
                                   V_PERIODENDDATE - 1
                                AND T.OLD_SCHEME_DESC NOT LIKE '%APF%'
                                AND T.LOB <> 'MORTGAGE'*/
                                ------
                             AND T.LOB = AAS.LOB),
                          0)
                   -- this lob's Beginning Balance + this lob's Comm
                     ELSE
                      0
                   END
              FROM DUAL)
     WHERE AAS.PERIODKEY = V_PERIODKEY
       AND AAS.STATUS != 'Suspended'
          --  and aas.positionname = 'A1366'
       AND NVL((SELECT SUM(T.VALUE)
                 FROM PAYMENTFACT T, AIA_PAYEE_INFOR PAY
                WHERE T.PERIODKEY = V_PERIODKEY
                  AND T.PAKEY = PAY.PAKEY
                  AND PAY.PARTICIPANTID = AAS.CODE),
               0) = 0;
  UPDATE AIA_AGT_STMT_TOTAL AAS
   SET (AAS.PAYMENT_AMOUNT, AAS.CLOSING_BAL_AMOUNT) =
   (SELECT CASE
        WHEN NVL((SELECT SUM(A.BEGINING_BALANCE)
                   FROM AIA_AGT_STMT_TOTAL A
                  WHERE A.PERIODKEY = V_PERIODKEY
                    AND A.CODE =
                        AAS.CODE),
                 0) +
             NVL((SELECT SUM(T.COMM)
                   FROM AIA_AGT_STMT T
                  WHERE T.PERIODKEY = V_PERIODKEY
                    AND T.CODE = AAS.CODE
                    AND (T.CREDITTYPE <> 'FYP PO For Gen1' or T.credittype is null)
                         ------
                      AND CASE
                            WHEN T.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                                 T.TAX_IND = 'N' AND
                                 (T.TRAN_DATE BETWEEN v_PERIODSTARTDATE AND
                                 V_PERIODENDDATE - 1) THEN
                             1
                            ELSE
                             0
                          END = 0
                 ),
                   --20140710 start
                 0) >= 0--50
                   --20140710 end
        -- ALL LOB's Beginning Balance + all LOB's Comm  >= 50
         THEN
         NVL(AAS.BEGINING_BALANCE,
             0) +
         NVL((SELECT SUM(T.COMM)
               FROM AIA_AGT_STMT T
              WHERE T.PERIODKEY = V_PERIODKEY
                AND T.CODE = AAS.CODE
                AND (T.CREDITTYPE <> 'FYP PO For Gen1' or T.credittype is null)
                         ------
                AND CASE
                      WHEN T.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                           T.TAX_IND = 'N' AND
                           (T.TRAN_DATE BETWEEN v_PERIODSTARTDATE AND
                           V_PERIODENDDATE - 1) THEN
                       1
                      ELSE
                       0
                    END = 0
                   ------
                AND T.LOB = AAS.LOB),
             0)
      -- this lob's Beginning Balance + this lob's Comm
        ELSE
         0
      END PAYMENT_AMOUNT,
      CASE
        WHEN NVL((SELECT SUM(A.BEGINING_BALANCE)
                   FROM AIA_AGT_STMT_TOTAL A
                  WHERE A.PERIODKEY = V_PERIODKEY
                    AND A.CODE =
                        AAS.CODE),
                 0) +
             NVL((SELECT SUM(T.COMM)
                   FROM AIA_AGT_STMT T
                  WHERE T.PERIODKEY = V_PERIODKEY
                    AND T.CODE = AAS.CODE
                    AND (T.CREDITTYPE <> 'FYP PO For Gen1' or T.credittype is null)
                         ------
                      AND CASE
                            WHEN T.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                                 T.TAX_IND = 'N' AND
                                 (T.TRAN_DATE BETWEEN v_PERIODSTARTDATE AND
                                 V_PERIODENDDATE - 1) THEN
                             1
                            ELSE
                             0
                          END = 0
                         /*     AND T.COMPENSATION_DATE BETWEEN to_date('2014-5-1', 'YYYY-MM-DD') AND
                         to_date('2014-5-12', 'YYYY-MM-DD') - 1
                      AND T.OLD_SCHEME_DESC NOT LIKE '%APF%'
                      AND T.LOB <> 'MORTGAGE'*/
                   ------
                 /*AND T.LOB = AAS.LOB*/
                 ),
                   --20140710 start
                 0) < 0--50
                   --20140710 end
                 THEN
        -- ALL LOB's Beginning Balance + all LOB's Comm  < 50
         NVL(AAS.BEGINING_BALANCE,
             0) +
         NVL((SELECT SUM(T.COMM)
               FROM AIA_AGT_STMT T
              WHERE T.PERIODKEY = V_PERIODKEY
                AND T.CODE = AAS.CODE
                AND (T.CREDITTYPE <> 'FYP PO For Gen1' or T.credittype is null)
                         ------
                      AND CASE
                            WHEN T.OLD_SCHEME_DESC LIKE '%INITIAL FYC ADVANCE' AND
                                 T.TAX_IND = 'N' AND
                                 (T.TRAN_DATE BETWEEN v_PERIODSTARTDATE AND
                                 V_PERIODENDDATE - 1) THEN
                             1
                            ELSE
                             0
                          END = 0
                   ------*/
                AND T.LOB = AAS.LOB),
             0)
      -- this lob's Beginning Balance + this lob's Comm
        ELSE
         0
      END
  FROM DUAL)
 WHERE AAS.PERIODKEY = V_PERIODKEY
   AND AAS.PAYMENT_AMOUNT IS NULL;
    ------------------------------------------------------------------------------------

    UPDATE AIA_AGT_STMT_TOTAL T
       SET (T.FIRST_YEAR_CURR, T.RENEWAL_CURR, T.MISC_CURR) =
           (SELECT NVL(SUM(CASE
                             WHEN AAS.COMMISSION_TYPE = C_EARNING_CODE(1) AND
                                  AAS.CREDITTYPE LIKE 'FYC%' THEN
                              NVL(AAS.COMM, 0)
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN AAS.COMMISSION_TYPE = C_EARNING_CODE(1) AND
                                  AAS.CREDITTYPE LIKE 'RYC%' THEN
                              NVL(AAS.COMM, 0)
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN AAS.COMMISSION_TYPE IN
                                  (C_EARNING_CODE(2),
                                   C_EARNING_CODE(3),
                                   C_EARNING_CODE(4),
                                   C_EARNING_CODE(5),
                                   C_EARNING_CODE(6),
                                   C_EARNING_CODE(7),
                                   C_EARNING_CODE(29)) THEN
                              NVL(AAS.COMM, 0)
                             ELSE
                              0
                           END),
                       0)
              FROM AIA_AGT_STMT AAS
             WHERE AAS.PERIODKEY = V_PERIODKEY
               AND AAS.CODE = T.CODE
               AND AAS.TAX_IND = 'Y'),
           (T.FIRST_YEAR_YTD, T.RENEWAL_YTD, T.MISC_YTD) =
           (SELECT /*+parallel*(AAS,4)*/
             NVL(SUM(CASE
                       WHEN AAS.COMMISSION_TYPE = C_EARNING_CODE(1) AND
                            AAS.CREDITTYPE LIKE 'FYC%' THEN
                        NVL(AAS.COMM, 0)
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN AAS.COMMISSION_TYPE = C_EARNING_CODE(1) AND
                            AAS.CREDITTYPE LIKE 'RYC%' THEN
                        NVL(AAS.COMM, 0)
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN AAS.COMMISSION_TYPE IN (C_EARNING_CODE(2),
                                                    C_EARNING_CODE(3),
                                                    C_EARNING_CODE(4),
                                                    C_EARNING_CODE(5),
                                                    C_EARNING_CODE(6),
                                                    C_EARNING_CODE(7),
                                                    C_EARNING_CODE(29)) THEN

                        NVL(AAS.COMM, 0)
                       ELSE
                        0
                     END),
                 0)
              FROM AIA_AGT_STMT AAS
             WHERE AAS.CALENDARNAME = 'AIA MY Fiscal Calendar'
               AND AAS.PERIODSTARTDATE >=
                   ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), -1)
               AND AAS.PERIODENDDATE <= V_PERIODENDDATE
               AND AAS.CODE = T.CODE
               AND AAS.TAX_IND = 'Y')
     WHERE T.PERIODKEY = V_PERIODKEY;
    -----------

    UPDATE AIA_AGT_STMT_TOTAL T
       SET (T.TOTAL_CURR) = NVL(T.FIRST_YEAR_CURR, 0) + NVL(T.RENEWAL_CURR, 0) +
                            NVL(T.MISC_CURR, 0),
           (T.TOTAL_YTD) = NVL(T.FIRST_YEAR_YTD, 0) + NVL(T.RENEWAL_YTD, 0) +
                           NVL(T.MISC_YTD, 0)
     WHERE T.PERIODKEY = V_PERIODKEY;
    --############

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_AGT_STMT_OLD_PROC IS
    ------Duration 997 for first year
    ------Duration 998 for Renewal
    ------Duration 999 for 7 year
  BEGIN
    INSERT INTO AIA_AGT_STMT
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       CREDITTYPE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       OFFICE,
       PRM_TYPE,
       LOB,
       COMMISSION_TYPE,
       COVERAGE_ID,
       PRD_END_DATE,
       STATUS,
       NAME,
       CODE,
       IC_NUMBER,
       REGION,
       POLICY,
       INSURED,
       REF,
       ISSUE_DATE,
       DUE_DATE, --PTD
       TRAN_DATE,
       DUR,
       PREM_MODE,
       PLAN,
       PREMIUM,
       SHARE_PCT, ------
       COMM_PCT,
       COMM,
       PERS_BONUS,
       APF,
       AGT_WS,
       VALUE,
       WRITING_AGT_CODE,
       UM,
       DM,
       CREATE_DATE,
       SUB_TOTAL_GROUP,
       TAX_IND,
       OLD_SCHEME_DESC) -- Add by corey for old scheme specil handle
      SELECT AOSD.PAKEY,
             AOSD.EFFECTIVESTARTDATE,
             AOSD.EFFECTIVEENDDATE,
             CASE
               WHEN AOSD.EARNING_CODE = C_EARNING_CODE(1) AND
                    AOSD.POLICY_YEAR IN (1, 997) THEN
                'FYC'
               WHEN AOSD.EARNING_CODE = C_EARNING_CODE(1) THEN
                'RYC'
               ELSE
                ''
             END CREDITTYPE,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             AOSD.POSITIONSEQ,
             AOSD.MANAGERSEQ,
             AOSD.POSITIONNAME,
             AOSD.POSITIONTITLE,
             AOSD.OFFICE OFFICE,
             AOSD.PREMIUM_TYPE PRM_TYPE,
             UPPER(AOSD.BUSINESS_LINE) LOB,
             AOSD.EARNING_CODE COMMISSION_TYPE,
             AOSD.COVERAGE_ID COVERAGE_ID,
             V_PERIODENDDATE PRD_END_DATE,
             AOSD.STATUS_CODE STATUS,
             AOSD.PRODUCERNAME NAME,
             AOSD.PRODUCERCODE CODE,
             AOSD.IC_NUMBER IC_NUMBER,
             AOSD.REGION REGION,
             AOSD.POLICY_NO POLICY,
             CASE
               WHEN AOSD.EARNING_CODE = C_EARNING_CODE(2) AND AOSD.POLICY_NO IS NULL THEN
                AOSD.DESCRIPTION
               ELSE
                AOSD.POLICY_INSURED
             END INSURED,
             AOSD.REFERENCE REF,
             AOSD.POLICY_ISSUE_DATE ISSUE_DATE,
             AOSD.DUE_DATE DUE_DATE, --PTD
             AOSD.ACCOUNTING_DATE TRAN_DATE,
             CASE
               WHEN AOSD.EARNING_CODE = C_EARNING_CODE(2) AND AOSD.POLICY_NO IS NULL THEN
                9999
               ELSE
                AOSD.POLICY_YEAR
             END DUR,
             CASE
               WHEN AOSD.PREMIUM_MODE IN ('00', '99', '12') THEN
                'A'
               WHEN AOSD.PREMIUM_MODE = '01' THEN
                'M'
               WHEN AOSD.PREMIUM_MODE = '03' THEN
                'Q'
               WHEN AOSD.PREMIUM_MODE = '06' THEN
                'SA'
               ELSE
                ''
             END PREM_MODE,
             AOSD.PRODUCTID PLAN,
             AOSD.COMMISSIONABLE_PREMIUM PREMIUM,
             DECODE(AOSD.SPLIT_PERCENTAGE, 1, NULL, AOSD.SPLIT_PERCENTAGE) * 100 SHARE_PCT, ------different from new shceme
             NVL(AOSD.RATE, 0) * 100 COMM_PCT,
             NVL(AOSD.VALUE, 0) COMM,
             0 PERS_BONUS, --FOR PHASE1A IS BLANK
             0 APF, --FOR PHASE1A IS BLANK
             CASE
               WHEN AOSD.IS_WRITING_AGENT = 1 THEN
                'W'
               WHEN AOSD.IS_WRITING_AGENT = 0 THEN
                'S'
               ELSE
                ''
             END AGT_WS,
             AOSD.VALUE,
             AOSD.WRITING_AGT_CODE,
             AOSD.UM,
             AOSD.DM,
             SYSDATE,
             CASE
               WHEN AOSD.EARNING_CODE = C_EARNING_CODE(2) AND AOSD.POLICY_NO IS NULL THEN
                3
               WHEN AOSD.POLICY_YEAR IN (1, 997) THEN
                1
               WHEN AOSD.POLICY_YEAR IN (2, 3, 4, 5, 6, 998) THEN
                2
               WHEN AOSD.POLICY_YEAR < 10000 THEN
                3
               ELSE
                10000
             END SUB_TOTAL_GROUP,
             AOSD.TAX_IND,
             AOSD.DESCRIPTION OLD_SCHEME_DESC
        FROM AIA_OLD_SCHEME_DTL AOSD
       WHERE (AOSD.EARNING_CODE IN (C_EARNING_CODE(1),
                                    C_EARNING_CODE(2),
                                    C_EARNING_CODE(3),
                                    C_EARNING_CODE(4),
                                    C_EARNING_CODE(5),
                                    C_EARNING_CODE(6),
                                    C_EARNING_CODE(7)) OR
             (AOSD.EARNING_CODE = C_EARNING_CODE(8) AND
             AOSD.STATUS_CODE != 'Terminated'))
         AND AOSD.POSITIONTITLE IN ('Tied Agency-UM',
                                    'Tied Agency-DM',
                                    'Tied Agency-Agent',
                                    'Tied Agency-ALC',
                                    'Broker-Agent',
                                    'Broker-Leader',
                                    'IFA-FA Leader',
                                    'IFA-FAR')
/* termination logic , by Corey & Neal 20140722
   normal terminate:
          (1) Terminated:Resignation
          (2) Terminated:Termination

          compensation_date <= terminated_date ==> payout
          compensation_date > terminated_date  ==> unpay
   unNormal terminate:
          (1) Terminated:Fraud Case
          (2) Terminated:Mis-Conduct

          all ==> unpay
*/
         AND CASE
               WHEN (AOSD.STATUS_CODE || ':' || AOSD.STATUS_NAME) IN
                    ('Terminated:Resignation',
                     'Terminated:Termination') AND
                     -- changed by Corey 20140722
                    AOSD.COMPENSATION_DATE <= AOSD.TERMINATIONDATE
                    THEN
                      0
               ELSE
                1
             END = 0;

-- termination logic end , by Corey & Neal 20140722

    --------MISC
    INSERT INTO AIA_AGT_STMT
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       STATUS,
       NAME,
       CODE,
       LOB,
       COMMISSION_TYPE,
       POLICY,
       INSURED,
       REF,
       TRAN_DATE,
       COMM,
       SUB_TOTAL_GROUP,
       TAX_IND,
       CREATE_DATE)
      SELECT AOSD.PAKEY,
             AOSD.EFFECTIVESTARTDATE,
             AOSD.EFFECTIVEENDDATE,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             AOSD.POSITIONSEQ,
             AOSD.MANAGERSEQ,
             AOSD.POSITIONNAME,
             AOSD.POSITIONTITLE,
             AOSD.STATUS_CODE,
             AOSD.PRODUCERNAME NAME,
             AOSD.PRODUCERCODE CODE,
             AOSD.BUSINESS_LINE,
             C_EARNING_CODE(29) COMMISSION_TYPE, --'Miscellaneous'
             AOSD.DESCRIPTION,
             AOSD.POLICY_NO, ------Description
             AOSD.REFERENCE REF,
             AOSD.ACCOUNTING_DATE,
             AOSD.VALUE,
             4,
             AOSD.TAX_IND,
             SYSDATE
        FROM AIA_OLD_SCHEME_DTL AOSD
       WHERE AOSD.EARNING_CODE = C_EARNING_CODE(28)
         AND AOSD.POSITIONTITLE IN ('Tied Agency-UM',
                                    'Tied Agency-DM',
                                    'Tied Agency-Agent',
                                    'Tied Agency-ALC',
                                    'Broker-Agent',
                                    'Broker-Leader',
                                    'IFA-FA Leader',
                                    'IFA-FAR')
         AND CASE
               WHEN (AOSD.STATUS_CODE || ':' || AOSD.STATUS_NAME) IN
                    ('Terminated:Resignation',
                     'Terminated:Termination') AND
                     -- changed by Corey 20140722
                    AOSD.COMPENSATION_DATE <= AOSD.TERMINATIONDATE
                    THEN
                      0
               ELSE
                1
             END = 0;

    ------old scheme data mortage
    AIA_OLD_SCHEME_DATA_MORTGAGE;
    ------old scheme data nopayout
    --    AIA_OLD_SCHEME_DATA_NOPAYOUT;
  EXCEPTION
    WHEN OTHERS THEN
      AIA_ERROR_LOG;
  END;

  PROCEDURE AIA_IFA_PROC IS
    --------------Just for IFA

  BEGIN

    DELETE FROM AIA_IFA AI
     WHERE AI.CALENDARNAME = V_CALENDARNAME
       AND AI.PERIODNAME = V_PERIODNAME;

    INSERT INTO AIA_IFA
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       TRANSACTIONFACTKEY,
       EVENTTYPE,
       CREDITFACTKEY,
       CREDITRULETYPE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       --UNIT_CODE,
       --COMPANY_NAME,
       --COMPANY_CODE,
       LOB,
       COVERAGE_ID,
       POLICY_DATE,
       PAID_TO_DATE,
       --PLANNER_NAME,
       CLIENT_NAME,
       IC_NUMBER,
       POLICY_NUMBER,
       TYPE,
       POLICY_YEAR,
       PLAN_NAME,
       PLAN_MODE,
       PREMIUM_TYPE,
       MODAL_PREMIUM_RM,
       --COMMISSION_RM,
       --DIRECT_OVERRIDING_RM,
       --INDIRECT_OVERRIDING_RM,
       --PRODUCTION_BONUS_10P,
       --AH_PRIZES_AWARDS_1P,
       MORT_LOAN_REF_RM,
       MISC_RM,
       YEAR1_PERS_BONUS_5P_RM,
       YEAR2_PERS_BONUS_5P_RM,
       --TOTAL_PAYMENT_RM,
       YEAR1_PERS_BONUS_5P,
       DIRECT_OR_RATE_P,
       INDIRECT_OR_RATE_P,
       --TOTAL_COMM_OR_APB_RM,
       --AGENCY_COMM_RATE_P,
       --IFA_TOTAL_COMM_RATE,
       LIFE,
       PA,
       CREDIT_LIFE,
       P_LINES,
       MISCELLANEOUS,
       CREATE_DATE)
      SELECT PAD.PAKEY,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             TXF.TRANSACTIONFACTKEY,
             TXDM.EVENTTYPE,
             CRDF.CREDITFACTKEY,
             CRDD.CREDITRULETYPE,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             --PAD.PARTICIPANTID UNIT_CODE,
             --DECODE(TXD.TRANSACTIONGENERICATTRIBUTE28, '016', 'AIA', '072', 'TAKAFUL', 'UNKNOWN CODE'),
             PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME ||
             --PAD.SUFFIX COMPANY_NAME,
             --PAD.PARTICIPANTID COMPANY_CODE,
             UPPER(TXD.TRANSACTIONGENERICATTRIBUTE4) LOB,
             TXD.TRANSACTIONGENERICATTRIBUTE6 COVERAGE_ID,
             TXD.TRANSACTIONGENERICDATE2 POLICY_DATE,
             --TXD.TRANSACTIONGENERICDATE2 APP_SUBM_DATE,
             TXD.TRANSACTIONGENERICDATE4 PAID_TO_DATE,
             --PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME || PAD.SUFFIX PLANNER_NAME,
             TXD.TRANSACTIONGENERICATTRIBUTE21 CLIENT_NAME,
             TXD.TRANSACTIONGENERICATTRIBUTE22 IC_NUMBER,
             --TXF.ORDERID POLICY_NUMBER,
             --SUBSTR(TXF.ORDERID, 11, 8) POLICY_NUMBER,
             TXD.TRANSACTIONGENERICATTRIBUTE20 POLICY,
             UPPER(TXD.TRANSACTIONGENERICATTRIBUTE4) TYPE,
             TXD.TRANSACTIONGENERICNUMBER1 POLICY_YEAR,
             TXD.PRODUCTID PLAN_NAME,
             --TXD.TRANSACTIONGENERICATTRIBUTE1  PLAN_MODE,
             CASE
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 IN ('00', '99', '12') THEN
                'A'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '01' THEN
                'M'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '03' THEN
                'Q'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '06' THEN
                'SA'
               ELSE
                ''
             END PLAN_MODE,
             TXD.TRANSACTIONGENERICATTRIBUTE2 PREMIUM_TYPE,
             TXD.TRANSACTIONGENERICNUMBER6 MODAL_PREMIUM_RM,
             --TXF.VALUE COMMISSION_RM,
             /*CASE
               WHEN TXDM.EVENTTYPE LIKE '%Commissions' THEN
                TXF.VALUE
               ELSE
                0
             END COMMISSION_RM,*/
             --0 DIRECT_OVERRIDING_RM, --PAYF.VALUE
             --0 INDIRECT_OVERRIDING_RM, --PAYF.VALUE
             --0 PRODUCTION_BONUS_10P, --PAYF.VALUE
             --0 AH_PRIZES_AWARDS_1P, --PAYF.VALUE
             0 MORT_LOAN_REF_RM,
             0 MISC_RM,
             0 YEAR1_PERS_BONUS_5P_RM,
             0 YEAR2_PERS_BONUS_5P_RM,
             --0 TOTAL_PAYMENT_RM,
             --(COMMISSION_RM + DIRECT_OVERRIDING_RM + INDIRECT_OVERRIDING_RM + PRODUCTION_BONUS_10P + AH_PRIZES_AWARDS_1P +
             --MORT_LOAN_REF_RM + MISC_RM)
             0 YEAR1_PERS_BONUS_5P,
             0 DIRECT_OR_RATE_P,
             0 INDIRECT_OR_RATE_P,
             --0 TOTAL_COMM_OR_APB_RM,
             --(COMMISSION_RM + DIRECT_OVERRIDING_RM + INDIRECT_OVERRIDING_RM + PRODUCTION_BONUS_10P + AH_PRIZES_AWARDS_1P),
             --0 AGENCY_COMM_RATE_P,
             --COMMISSION_RM / MODAL_PREMIUM_RM * 100 AGENCY_COMM_RATE_P,
             --0 IFA_TOTAL_COMM_RATE,
             --TOTAL_COMM_OR_APB_RM / MODAL_PREMIUM_RM * 100 IFA_TOTAL_COMM_RATE,
             0       LIFE,
             0       PA,
             0       CREDIT_LIFE,
             0       P_LINES,
             0       MISCELLANEOUS,
             SYSDATE
        FROM --CS_CLASSIFIER,
             PADIMENSION          PAD,
             TRANSACTIONDETAIL    TXD,
             TRANSACTIONFACT      TXF,
             TRANSACTIONDIMENSION TXDM,
             CREDITFACT           CRDF,
             CREDITRULEDIMENSION  CRDD,
             CREDITDIMENSION      CRDM
       WHERE TXF.TRANSACTIONDETAILKEY = TXD.TRANSACTIONDETAILKEY
         AND TXF.TRANSACTIONKEY = TXDM.TRANSACTIONKEY
         AND TXF.TRANSACTIONFACTKEY = CRDF.TRANSACTIONFACTKEY
         AND CRDF.PAKEY = PAD.PAKEY
         AND CRDF.PERIODKEY = V_PERIODKEY
         AND CRDF.CREDITRULEKEY = CRDD.CREDITRULEKEY
         AND V_PERIODENDDATE-1 BETWEEN PAD.EFFECTIVESTARTDATE AND PAD.EFFECTIVEENDDATE -1
         AND CRDD.REMOVEDATE = C_REMOVEDATE
         AND PAD.REMOVEDATE = C_REMOVEDATE
--         AND PAD.POSITIONTITLE = 'IFA-FA Company'
         AND PAD.POSITIONTITLE IN(  'Broker-Agent',
                                    'Broker-Leader',
                                    'IFA-FA Leader',
                                    'IFA-FAR')
         AND CRDF.CREDITKEY = CRDM.CREDITKEY
         AND CRDM.CREDITTYPE IN ('FYP', 'RYP');
    --------old scheme
    AIA_IFA_OLD_PROC;
    COMMIT;
    ------------------
    UPDATE AIA_IFA T
       SET (T.WRITING_AGT_CODE,
            T.W_AGENT_KEY,
            T.W_POSITION_SEQ,
            T.W_MANAGERSEQ,
            T.W_EFFECTIVESTARTDATE,
            T.W_POSITIONTITLE,
            T.PLANNER_NAME) =
           (SELECT --PAD.PARTICIPANTID,
             PAD.POSITIONNAME,
             PAD.PAKEY,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.EFFECTIVESTARTDATE,
             PAD.POSITIONTITLE,
             PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME || PAD.SUFFIX
              FROM CREDITFACT CRDF, CREDITRULEDIMENSION CRDD, PADIMENSION PAD
             WHERE CRDF.CREDITRULEKEY = CRDD.CREDITRULEKEY
               AND CRDD.CREDITRULETYPE = 'Direct Transaction Credit Rule'
               AND CRDF.TRANSACTIONFACTKEY = T.TRANSACTIONFACTKEY
               AND CRDF.PAKEY = PAD.PAKEY
               AND PAD.REMOVEDATE = C_REMOVEDATE
               AND CRDD.REMOVEDATE = C_REMOVEDATE
               AND PAD.POSITIONTITLE != 'IFA-FA Company'
               AND ROWNUM = 1)
     WHERE T.PERIODKEY = V_PERIODKEY
       AND T.TRANSACTIONFACTKEY IS NOT NULL; ------JUST FOR NEW SCHEME
/*    ---------update UNIT
    UPDATE AIA_IFA AI
       SET (AI.UNIT_CODE) =
           (SELECT PAD2.PARTICIPANTID
              FROM PADIMENSION PAD1, PAROLL PAR, PADIMENSION PAD2
             WHERE PAD1.POSITIONSEQ = DECODE(AI.POSITIONTITLE,
                                             'Tied Agency-Agent',
                                             AI.MANAGERSEQ,
                                             AI.POSITIONSEQ)
               AND PAD1.REMOVEDATE = C_REMOVEDATE
               AND PAD1.EFFECTIVESTARTDATE < V_PERIODENDDATE
               AND PAD1.EFFECTIVEENDDATE >= V_PERIODENDDATE
               AND PAR.ROLLTYPE = 'Assigned_Roll'
               AND PAR.REMOVEDATE = C_REMOVEDATE
               AND PAR.FROMPAKEY = PAD1.PAKEY
               AND PAR.TOPAKEY = PAD2.PAKEY
               AND PAD2.REMOVEDATE = C_REMOVEDATE
               AND ROWNUM = 1)
     WHERE AI.PERIODKEY = V_PERIODKEY; */

    --update the COMPANY_CODE, COMPANY_NAME of IFA /BROKER
    UPDATE AIA_IFA IFA
     SET (IFA.COMPANY_CODE, IFA.COMPANY_NAME) =
         --JUST QUERY THE MANAGER OF IFA
         (select posa.name,
             par.PREFIX || par.FIRSTNAME || par.MIDDLENAME|| par.LASTNAME || par.SUFFIX
                                                 from cs_participant par,
                                                      cs_position    posa,
                                                      cs_position    far
                                                where par.payeeseq =
                                                      posa.payeeseq
                                                  and par.removedate =
                                                      C_REMOVEDATE
                                                  and posa.removedate =
                                                      C_REMOVEDATE
                                                  AND far.removedate =
                                                      C_REMOVEDATE
                                                  and par.effectivestartdate <
                                                      V_PERIODENDDATE
                                                  and par.effectiveenddate >=
                                                      V_PERIODENDDATE
                                                  and far.effectivestartdate <
                                                      V_PERIODENDDATE
                                                  and far.effectiveenddate >=
                                                      V_PERIODENDDATE
                                                  and posa.effectivestartdate <
                                                      V_PERIODENDDATE
                                                  and posa.effectiveenddate >=
                                                      V_PERIODENDDATE
                                                  AND ifa.positionname = far.name
                                                  AND far.managerseq = posa.ruleelementownerseq
                                                  AND ROWNUM = 1
         )
     WHERE IFA.PERIODKEY = V_PERIODKEY
     AND IFA.POSITIONTITLE IN(  'Broker-Agent',
                                'Broker-Leader',
                                'IFA-FA Leader',
                                'IFA-FAR')
     AND IFA.MANAGERSEQ IS NOT NULL
     AND IFA.TRANSACTIONFACTKEY IS NOT NULL; -- Just for new scheme
     -----------------

    UPDATE AIA_IFA AI
       SET (AI.DIRECT_OVERRIDING_RM, AI.DIRECT_OR_RATE_P) =
           (SELECT NVL(CRDD.GENERICNUMBER3, 0),
                   DECODE(CRDF.VALUE, 0, 0, NVL(CRDD.GENERICNUMBER3, 0) / CRDF.VALUE) * 100
              FROM CREDITFACT CRDF, CREDITDETAIL CRDD, CREDITDIMENSION CRDM
             WHERE CRDF.CREDITDETAILKEY = CRDD.CREDITDETAILKEY
               AND CRDF.CREDITKEY = CRDM.CREDITKEY
               AND CRDF.TRANSACTIONFACTKEY = AI.TRANSACTIONFACTKEY
               AND CRDM.CREDITTYPE LIKE '%DO'
               AND ROWNUM = 1),
           (AI.INDIRECT_OVERRIDING_RM, AI.INDIRECT_OR_RATE_P) =
           (SELECT NVL(CRDD.GENERICNUMBER3, 0),
                   DECODE(CRDF.VALUE, 0, 0, NVL(CRDD.GENERICNUMBER3, 0) / CRDF.VALUE) * 100
              FROM CREDITFACT CRDF, CREDITDETAIL CRDD, CREDITDIMENSION CRDM
             WHERE CRDF.CREDITDETAILKEY = CRDD.CREDITDETAILKEY
               AND CRDF.CREDITKEY = CRDM.CREDITKEY
               AND CRDF.TRANSACTIONFACTKEY = AI.TRANSACTIONFACTKEY
                   --20140710 start
               AND AI.POSITIONTITLE = CRDD.GENERICATTRIBUTE5
                   --20140710 end
               AND CRDM.CREDITTYPE LIKE '%IO'
               AND ROWNUM = 1),
           AI.COMMISSION_RM =
           (SELECT SUM(CRDF.VALUE)
              FROM TRANSACTIONFACT TXF,
                   TRANSACTIONFACT TXF2,
                   CREDITFACT      CRDF,
                   CREDITDIMENSION CRDM,
                   --20140710 start
                   CREDITDETAIL    CRDT
                   --20140710 end
             WHERE TXF.TRANSACTIONFACTKEY = AI.TRANSACTIONFACTKEY
               AND TXF.ORDERID = TXF2.ORDERID
               AND TXF.TRANSACTIONFACTKEY != TXF2.TRANSACTIONFACTKEY
               AND TXF2.TRANSACTIONFACTKEY = CRDF.TRANSACTIONFACTKEY
               AND CRDF.PERIODKEY = AI.PERIODKEY --
               AND CRDF.CREDITKEY = CRDM.CREDITKEY
               --20140710 start
               AND CRDT.GENERICATTRIBUTE5 = AI.POSITIONTITLE
               AND CRDT.CREDITDETAILKEY = CRDF.CREDITDETAILKEY
               --20140710 end
               AND CRDM.CREDITTYPE IN ('FYC', 'RYC')),
           AI.PRODUCTION_BONUS_10P = CASE
                                       WHEN AI.POLICY_YEAR = 1 AND
                                            AI.LOB IN ('LIFE', 'TAKAFUL') AND
                                            UPPER(AI.PREMIUM_TYPE) = 'REGULAR PREMIUM' THEN
                                        AI.MODAL_PREMIUM_RM * 0.1
                                       ELSE
                                        0
                                     END,
           AI.AH_PRIZES_AWARDS_1P = CASE
                                      WHEN UPPER(AI.LOB) IN ('PA', 'GROUP') THEN
                                       AI.MODAL_PREMIUM_RM * 0.01
                                      ELSE
                                       0
                                    END /*,

               YEAR1_PERS_BONUS_5P_RM = CASE
                                          WHEN (SELECT SUM(DEPF.VALUE)
                                                  FROM DEPOSITFACT      DEPF,
                                                       DEPOSITDIMENSION DEPD,
                                                       AIA_PAYEE_INFOR  PAY
                                                 WHERE DEPF.DEPOSITKEY = DEPD.DEPOSITKEY
                                                   AND DEPF.PERIODKEY = AI.PERIODKEY
                                                   AND DEPF.PAKEY = PAY.PAKEY
                                                   AND PAY.PARTICIPANTID = AI.WRITING_AGT_CODE
                                                   AND DEPD.EARNINGCODEID =
                                                       'Persistency Bonus(1st Year)') = 0 AND
                                               UPPER(AI.LOB) IN ('LIFE', 'TAKAFUL') AND
                                               UPPER(AI.PREMIUM_TYPE) != 'SINGLE PREMIUM' THEN
                                           0
                                          ELSE
                                           AI.MODAL_PREMIUM_RM * 0.05
                                        END,

               YEAR2_PERS_BONUS_5P_RM = CASE
                                          WHEN (SELECT SUM(DEPF.VALUE)
                                                  FROM DEPOSITFACT      DEPF,
                                                       DEPOSITDIMENSION DEPD,
                                                       AIA_PAYEE_INFOR  PAY
                                                 WHERE DEPF.DEPOSITKEY = DEPD.DEPOSITKEY
                                                   AND DEPF.PERIODKEY = AI.PERIODKEY
                                                   AND DEPF.PAKEY = PAY.PAKEY
                                                   AND PAY.PARTICIPANTID = AI.WRITING_AGT_CODE
                                                   AND DEPD.EARNINGCODEID =
                                                       'Persistency Bonus(2nd Year)') = 0 AND
                                               UPPER(AI.LOB) IN ('LIFE', 'TAKAFUL') AND
                                               UPPER(AI.PREMIUM_TYPE) != 'SINGLE PREMIUM' THEN
                                           0
                                          ELSE
                                           AI.MODAL_PREMIUM_RM * 0.05
                                        END */ -- changed by corey  20140218
     WHERE AI.PERIODKEY = V_PERIODKEY
       AND AI.TRANSACTIONFACTKEY IS NOT NULL; ------Just for new shceme

    UPDATE AIA_IFA AI
       SET AI.TOTAL_PAYMENT_RM    =
           (NVL(COMMISSION_RM, 0) + NVL(DIRECT_OVERRIDING_RM, 0) +
           NVL(INDIRECT_OVERRIDING_RM, 0) + NVL(PRODUCTION_BONUS_10P, 0) +
           NVL(AH_PRIZES_AWARDS_1P, 0) + NVL(MORT_LOAN_REF_RM, 0) + NVL(MISC_RM, 0)),
           AI.TOTAL_COMM_OR_APB_RM =
           (NVL(COMMISSION_RM, 0) + NVL(DIRECT_OVERRIDING_RM, 0) +
           NVL(INDIRECT_OVERRIDING_RM, 0) + NVL(PRODUCTION_BONUS_10P, 0) +
           NVL(AH_PRIZES_AWARDS_1P, 0)),
           AI.AGENCY_COMM_RATE_P   = DECODE(MODAL_PREMIUM_RM,
                                            0,
                                            0,
                                            NVL(COMMISSION_RM, 0) / MODAL_PREMIUM_RM * 100),
           AI.IFA_TOTAL_COMM_RATE  = DECODE(MODAL_PREMIUM_RM,
                                            0,
                                            0,
                                            (NVL(COMMISSION_RM, 0) +
                                            NVL(DIRECT_OVERRIDING_RM, 0) +
                                            NVL(INDIRECT_OVERRIDING_RM, 0) +
                                            NVL(PRODUCTION_BONUS_10P, 0) +
                                            NVL(AH_PRIZES_AWARDS_1P, 0)) /
                                            MODAL_PREMIUM_RM * 100)
     WHERE AI.PERIODKEY = V_PERIODKEY;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  PROCEDURE AIA_IFA_OLD_PROC IS
  BEGIN
    INSERT INTO AIA_IFA
      ( --PAKEY,
       --EFFECTIVESTARTDATE,
       --EFFECTIVEENDDATE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       --POSITIONSEQ,
       --MANAGERSEQ,
       --POSITIONNAME,
       --POSITIONTITLE,
       --UNIT_CODE,
       COMPANY_NAME,
       COMPANY_CODE,
       LOB,
       COVERAGE_ID,
       POLICY_DATE,
       PAID_TO_DATE,
       --PLANNER_NAME,
       CLIENT_NAME,
       IC_NUMBER,
       POLICY_NUMBER,
       TYPE,
       POLICY_YEAR,
       PLAN_NAME,
       PLAN_MODE,
       PREMIUM_TYPE,
       MODAL_PREMIUM_RM,
       COMMISSION_RM,
       DIRECT_OVERRIDING_RM,
       INDIRECT_OVERRIDING_RM,
       PRODUCTION_BONUS_10P,
       AH_PRIZES_AWARDS_1P,
       MORT_LOAN_REF_RM,
       MISC_RM,
       YEAR1_PERS_BONUS_5P_RM,
       YEAR2_PERS_BONUS_5P_RM,
       --TOTAL_PAYMENT_RM,
       YEAR1_PERS_BONUS_5P,
       DIRECT_OR_RATE_P,
       INDIRECT_OR_RATE_P,
       --TOTAL_COMM_OR_APB_RM,
       --AGENCY_COMM_RATE_P,
       --IFA_TOTAL_COMM_RATE,
       WRITING_AGT_CODE,
       W_AGENT_KEY,
       W_POSITION_SEQ,
       W_MANAGERSEQ,
       W_EFFECTIVESTARTDATE,
       W_POSITIONTITLE,
       PLANNER_NAME,
       LIFE,
       PA,
       CREDIT_LIFE,
       P_LINES,
       MISCELLANEOUS,
       CREATE_DATE)
      SELECT V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             COM.LASTNAME,
             COM.POSITIONNAME,
             AOSD.BUSINESS_LINE LOB,
             AOSD.COVERAGE_ID COVERAGE_ID,
             AOSD.POLICY_ISSUE_DATE POLICY_DATE,
             AOSD.DUE_DATE PAID_TO_DATE,
             AOSD.POLICY_INSURED CLIENT_NAME,
             AOSD.POLICY_INSURED_NRIC IC_NUMBER,
             AOSD.POLICY_NO POLICY_NUMBER,
             AOSD.BUSINESS_LINE TYPE,
             AOSD.POLICY_YEAR + 1 POLICY_YEAR,
             AOSD.PRODUCTID PLAN_NAME,
             CASE
               WHEN AOSD.PREMIUM_MODE IN ('00', '99', '12') THEN
                'A'
               WHEN AOSD.PREMIUM_MODE = '01' THEN
                'M'
               WHEN AOSD.PREMIUM_MODE = '03' THEN
                'Q'
               WHEN AOSD.PREMIUM_MODE = '06' THEN
                'SA'
               ELSE
                ''
             END PLAN_MODE,
             AOSD.PREMIUM_TYPE PREMIUM_TYPE,
             AOSD.COMMISSIONABLE_PREMIUM MODAL_PREMIUM_RM,
             CASE
               WHEN AOSD.EARNING_CODE = 'Basic Commission' THEN
                AOSD.VALUE
               ELSE
                0
             END COMMISSION_RM,
             CASE
               WHEN AOSD.EARNING_CODE = 'Direct O/R Commission' THEN
                AOSD.VALUE
               ELSE
                0
             END DIRECT_OVERRIDING_RM,
             CASE
               WHEN AOSD.EARNING_CODE = 'Indirect O/R Commission' THEN
                AOSD.VALUE
               ELSE
                0
             END INDIRECT_OVERRIDING_RM,
             CASE
               WHEN AOSD.DESCRIPTION = 'MGR PRODUCTION BONUS-DGI' AND
                    AOSD.EARNING_CODE = C_EARNING_CODE(28) THEN
                AOSD.VALUE
               ELSE
                0
             END PRODUCTION_BONUS_10P,
             CASE
               WHEN AOSD.DESCRIPTION = 'MGR P. BONUS-ADJ -DGI' AND
                    AOSD.EARNING_CODE = C_EARNING_CODE(28) THEN
                AOSD.VALUE
               ELSE
                0
             END AH_PRIZES_AWARDS_1P,
             CASE
               WHEN AOSD.DESCRIPTION IN ('MORTGAGE LOAN 2', 'MORTGAGE LOAN') AND
                    AOSD.EARNING_CODE = C_EARNING_CODE(28) THEN
                AOSD.VALUE
               ELSE
                0
             END MORT_LOAN_REF_RM,
             CASE
               WHEN AOSD.DESCRIPTION NOT IN ('1ST YR DGI PERSIST BONUS',
                                             '2ST YR DGI PERSIST BONUS',
                                             'AGT P. BONUS-ADJ -DGI',
                                             'AGT PROD. BONUS -DGI',
                                             'MGR PRODUCTION BONUS-DGI',
                                             'MGR P. BONUS-ADJ -DGI',
                                             'MORTGAGE LOAN 2',
                                             'MORTGAGE LOAN') AND
                    AOSD.EARNING_CODE = C_EARNING_CODE(28) THEN
                AOSD.VALUE
               ELSE
                0
             END MISC_RM,
             CASE
               WHEN AOSD.DESCRIPTION = '1ST YR DGI PERSIST BONUS' AND
                    AOSD.EARNING_CODE = C_EARNING_CODE(28) THEN
                AOSD.VALUE
               ELSE
                0
             END YEAR1_PERS_BONUS_5P_RM,
             CASE
               WHEN AOSD.DESCRIPTION = '2ST YR DGI PERSIST BONUS' AND
                    AOSD.EARNING_CODE = C_EARNING_CODE(28) THEN
                AOSD.VALUE
               ELSE
                0
             END YEAR2_PERS_BONUS_5P_RM,
             --0 TOTAL_PAYMENT_RM,
             --(COMMISSION_RM + DIRECT_OVERRIDING_RM + INDIRECT_OVERRIDING_RM + PRODUCTION_BONUS_10P + AH_PRIZES_AWARDS_1P +
             --MORT_LOAN_REF_RM + MISC_RM)
             --0 YEAR1_PERS_BONUS_5P,
             CASE
               WHEN AOSD.DESCRIPTION = '1ST YR DGI PERSIST BONUS' AND
                    AOSD.EARNING_CODE = C_EARNING_CODE(28) THEN
                AOSD.RATE
               ELSE
                0
             END YEAR1_PERS_BONUS_5P,
             --0, --AOSD.RATE DIRECT_OR_RATE_P,
             CASE
               WHEN AOSD.EARNING_CODE = 'Direct O/R Commission' THEN
                AOSD.RATE
               ELSE
                0
             END DIRECT_OR_RATE_P,
             --0, --AOSD.RATE INDIRECT_OR_RATE_P,
             CASE
               WHEN AOSD.EARNING_CODE = 'Indirect O/R Commission' THEN
                AOSD.RATE
               ELSE
                0
             END INDIRECT_OR_RATE_P,
             --0 TOTAL_COMM_OR_APB_RM,
             --(COMMISSION_RM + DIRECT_OVERRIDING_RM + INDIRECT_OVERRIDING_RM + PRODUCTION_BONUS_10P + AH_PRIZES_AWARDS_1P),
             --0 AGENCY_COMM_RATE_P,
             --COMMISSION_RM / MODAL_PREMIUM_RM * 100 AGENCY_COMM_RATE_P,
             --0 IFA_TOTAL_COMM_RATE,
             --TOTAL_COMM_OR_APB_RM / MODAL_PREMIUM_RM * 100 IFA_TOTAL_COMM_RATE,

             AOSD.WRITING_AGT_CODE,
             --AOSD.PRODUCERCODE, --changed by corey
             AOSD.PAKEY,
             AOSD.POSITIONSEQ,
             AOSD.MANAGERSEQ,
             AOSD.EFFECTIVESTARTDATE,
             AOSD.POSITIONTITLE,
             --AOSD.PRODUCERNAME       PLANNER_NAME,
             (SELECT K.PREFIX || K.FIRSTNAME || K.MIDDLENAME || K.LASTNAME || K.SUFFIX
                FROM PADIMENSION K
               WHERE K.REMOVEDATE > SYSDATE
                 AND K.PARTICIPANTID = AOSD.WRITING_AGT_CODE
                 AND ROWNUM = 1) PLANNER_NAME,
             0 LIFE,
             0 PA,
             0 CREDIT_LIFE,
             0 P_LINES,
             0 MISCELLANEOUS,
             SYSDATE
        FROM AIA_OLD_SCHEME_DTL AOSD,PADIMENSION COM
       WHERE /*AOSD.POSITIONTITLE = 'IFA-FA Company'*/
           AOSD.MANAGERSEQ = COM.POSITIONSEQ
           AND COM.REMOVEDATE = C_REMOVEDATE
           AND AOSD.POSITIONTITLE IN(  'Broker-Agent',
                                    'Broker-Leader',
                                    'IFA-FA Leader',
                                    'IFA-FAR')
            -- AND AOSD.EARNING_CODE != C_EARNING_CODE(28); ------
         AND AOSD.EARNING_CODE NOT IN (C_EARNING_CODE(41), C_EARNING_CODE(42));
          /*  ------Old Scheme APF
          C_EARNING_CODE(41) := 'Beginning Balance-APF';
          C_EARNING_CODE(42) := 'Ending Balance-APF';*/

    UPDATE AIA_IFA T
       SET (T.PAKEY,
            T.EFFECTIVESTARTDATE,
            T.EFFECTIVEENDDATE,
            T.POSITIONSEQ,
            T.MANAGERSEQ,
            T.POSITIONNAME,
            T.POSITIONTITLE) =
           (SELECT PAD.PAKEY,
                   PAD.EFFECTIVESTARTDATE,
                   PAD.EFFECTIVEENDDATE,
                   PAD.POSITIONSEQ,
                   PAD.MANAGERSEQ,
                   PAD.POSITIONNAME,
                   PAD.POSITIONTITLE
              FROM PADIMENSION PAD
             WHERE PAD.POSITIONSEQ = T.W_POSITION_SEQ -- T.W_MANAGERSEQ  changed by Corey 20140304
               AND T.W_EFFECTIVESTARTDATE BETWEEN PAD.EFFECTIVESTARTDATE AND
                   PAD.EFFECTIVEENDDATE - 1
               AND ROWNUM = 1)
     WHERE T.PERIODKEY = V_PERIODKEY
       AND T.TRANSACTIONFACTKEY IS NULL; ------JUST FOR OLD SCHEME

     /*  -- UPDATE COMPANY_NAME/COMPANY_CODE
      UPDATE AIA_IFA T
      SET (T.COMPANY_NAME,T.COMPANY_CODE)=
      (SELECT PAR.PREFIX || PAR.FIRSTNAME || PAR.MIDDLENAME || PAR.LASTNAME || PAR.SUFFIX,
              COM.NAME
        FROM CS_POSITION FAR,CS_POSITION COM,CS_PARTICIPANT PAR
        WHERE FAR.NAME = T.POSITIONNAME
        AND FAR.MANAGERSEQ = COM.RULEELEMENTOWNERSEQ
        AND COM.PAYEESEQ = PAR.PAYEESEQ
        AND PAR.REMOVEDATE = C_REMOVEDATE
        AND COM.REMOVEDATE = C_REMOVEDATE
        AND FAR.REMOVEDATE = C_REMOVEDATE
        AND V_PERIODENDDATE BETWEEN FAR.EFFECTIVESTARTDATE AND FAR.EFFECTIVEENDDATE - 1
        AND V_PERIODENDDATE BETWEEN PAR.EFFECTIVESTARTDATE AND PAR.EFFECTIVEENDDATE - 1
        AND V_PERIODENDDATE BETWEEN COM.EFFECTIVESTARTDATE AND COM.EFFECTIVEENDDATE - 1
        AND ROWNUM = 1)
        WHERE T.PERIODKEY = V_PERIODKEY
        AND T.W_AGENT_KEY IS NOT NULL; ------JUST FOR OLD SCHEME
*/
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  PROCEDURE AIA_UNPAID_OVERRIDING_PROC IS

    /*V_POSITIONSEQ        NUMBER;
    V_EFFECTIVEDATE      DATE;
    V_UM                 VARCHAR2(40);
    V_DM                 VARCHAR2(40);
    V_MEASUREMENTFACTKEY NUMBER;
    V_MEAUSREMENTCOUNT   NUMBER;
    V_COMMISSION_TYPE    VARCHAR2(255);
    V_DEPOSIT_VALUE      NUMBER;*/

  BEGIN

    DELETE FROM AIA_UNPAID_OVERRIDING AUO
     WHERE AUO.CALENDARNAME = V_CALENDARNAME
       AND AUO.PERIODNAME = V_PERIODNAME;

    INSERT INTO AIA_UNPAID_OVERRIDING
      (TRANSACTIONFACTKEY,
       EVENTTYPE,
       CREDITFACTKEY,
       CREDITRULETYPE,
       --MEASUREMENTFACTKEY,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       PRM_TYPE,
       LOB,
       COMMISSION_TYPE,
       COVERAGE_ID,
       PRD_END_DATE,
       POLICY,
       ISSUE_DATE,
       DUE_DATE,
       TRAN_DATE,
       DUR,
       PREM_MODE,
       PLAN,
       PREMIUM,
       SHARE_PCT,
       OR_PCT,
       OVERRIDE,
       UNPAID_REASON,
       CREATE_DATE)
      SELECT TXF.TRANSACTIONFACTKEY,
             TXDM.EVENTTYPE,
             CRDF.CREDITFACTKEY,
             CRDD.CREDITRULETYPE,
             --MEAF.MEASUREMENTFACTKEY,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             TXD.TRANSACTIONGENERICATTRIBUTE2 PRM_TYPE,
             (TXD.TRANSACTIONGENERICATTRIBUTE4) LOB,
             --EARD.EARNINGCODE                 COMMISSION_TYPE,
             CRDT.GENERICATTRIBUTE8           COMMISSION_TYPE,
             TXD.TRANSACTIONGENERICATTRIBUTE6 COVERAGE_ID,
             V_PERIODENDDATE                  PRD_END_DATE,
             --SUBSTR(TXF.ORDERID, 11, 8) POLICY,
             TXD.TRANSACTIONGENERICATTRIBUTE20 POLICY,
             TXD.TRANSACTIONGENERICDATE2       ISSUE_DATE,
             TXD.TRANSACTIONGENERICDATE4       DUE_DATE, --PTD
             TIMD.CALENDARDATE                 TRAN_DATE,
             TXD.TRANSACTIONGENERICNUMBER1     DUR,
             --TXD.TRANSACTIONGENERICATTRIBUTE1 PREM_MODE,
             CASE
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 IN ('00', '99', '12') THEN
                'A'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '01' THEN
                'M'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '03' THEN
                'Q'
               WHEN TXD.TRANSACTIONGENERICATTRIBUTE1 = '06' THEN
                'SA'
               ELSE
                ''
             END PREM_MODE,
             TXD.PRODUCTID PLAN,
             TXD.TRANSACTIONGENERICNUMBER6 PREMIUM,
             --TXD.TRANSACTIONGENERICNUMBER5    SHARE_PCT, -------
             DECODE(TXD.TRANSACTIONGENERICNUMBER5,
                    1,
                    NULL,
                    TXD.TRANSACTIONGENERICNUMBER5) * 100 SHARE_PCT,
             --0 OR_PCT, --TBD
             CRDT.GENERICNUMBER4 * 100 OR_PCT,
             --0 OVERRIDE, --TBD
             CRDF.VALUE OVERRIDE,
             --NULL       UNPAID_REASON
             'manager terminated' UNPAID_REASON,
             SYSDATE
        FROM PADIMENSION          PAD,
             TRANSACTIONFACT      TXF,
             TRANSACTIONDETAIL    TXD,
             TRANSACTIONDIMENSION TXDM,
             CREDITFACT           CRDF,
             CREDITDETAIL         CRDT,
             CREDITRULEDIMENSION  CRDD,
             CREDITDIMENSION      CRDM,
             --PERIODDIMENSION      PERD,
             TIMEDIMENSION TIMD
       WHERE TXF.TRANSACTIONDETAILKEY = TXD.TRANSACTIONDETAILKEY
         AND TXF.TRANSACTIONKEY = TXDM.TRANSACTIONKEY
         AND TXF.TRANSACTIONFACTKEY = CRDF.TRANSACTIONFACTKEY
         AND CRDF.PAKEY = PAD.PAKEY
         AND CRDF.PERIODKEY = V_PERIODKEY
         AND CRDF.CREDITRULEKEY = CRDD.CREDITRULEKEY
            --AND CRDD.REMOVEDATE = C_REMOVEDATE
         AND PAD.REMOVEDATE = C_REMOVEDATE
         AND TXF.ACCOUNTINGTIMEKEY = TIMD.TIMEKEY
         AND CRDF.CREDITDETAILKEY = CRDT.CREDITDETAILKEY
         AND PAD.POSITIONTITLE = 'Tied Agency-AIA'
         AND TXDM.EVENTTYPE LIKE '%Premiums'
         AND CRDD.CREDITRULETYPE = 'Rollup Transaction Credit Rule'
         AND CRDF.CREDITKEY = CRDM.CREDITKEY;
    COMMIT;

    UPDATE AIA_UNPAID_OVERRIDING T
       SET (T.WRITING_AGT_CODE,
            T.W_AGENT_KEY,
            T.W_POSITION_SEQ,
            T.W_MANAGERSEQ,
            T.W_EFFECTIVESTARTDATE,
            T.W_POSITIONTITLE) =
           (SELECT PAD.PARTICIPANTID,
                   PAD.PAKEY,
                   PAD.POSITIONSEQ,
                   PAD.MANAGERSEQ,
                   PAD.EFFECTIVESTARTDATE,
                   PAD.POSITIONTITLE
              FROM CREDITFACT CRDF, CREDITRULEDIMENSION CRDD, PADIMENSION PAD
             WHERE CRDF.CREDITRULEKEY = CRDD.CREDITRULEKEY
               AND CRDD.CREDITRULETYPE = 'Direct Transaction Credit Rule'
               AND CRDF.TRANSACTIONFACTKEY = T.TRANSACTIONFACTKEY
               AND CRDF.PAKEY = PAD.PAKEY
               AND PAD.REMOVEDATE = C_REMOVEDATE
                  --AND CRDD.REMOVEDATE = C_REMOVEDATE
               AND PAD.POSITIONTITLE != 'Tied Agency-Agency'
               AND ROWNUM = 1)
     WHERE T.PERIODKEY = V_PERIODKEY;

    UPDATE AIA_UNPAID_OVERRIDING T
       SET (T.UM, T.DM) =
           (SELECT T.MANAGER, T.GRANDMANAGER
              FROM AIA_PAYEE_INFOR T
             WHERE T.PAKEY = T.W_AGENT_KEY
               AND ROWNUM = 1)
     WHERE T.PERIODKEY = V_PERIODKEY
       AND T.TRANSACTIONFACTKEY IS NOT NULL; ------just for new scheme

    UPDATE AIA_UNPAID_OVERRIDING AUO
       SET (AUO.PAKEY,
            AUO.EFFECTIVESTARTDATE,
            AUO.EFFECTIVEENDDATE,
            AUO.POSITIONSEQ,
            AUO.MANAGERSEQ,
            AUO.POSITIONNAME,
            AUO.POSITIONTITLE,
            --AUO.OFFICE,
            AUO.STATUS,
            AUO.NAME,
            AUO.CODE,
            AUO.IC_NUMBER,
            AUO.REGION) =
           (SELECT PAD.PAKEY,
                   PAD.EFFECTIVESTARTDATE,
                   PAD.EFFECTIVEENDDATE,
                   PAD.POSITIONSEQ,
                   PAD.MANAGERSEQ,
                   PAD.POSITIONNAME,
                   PAD.POSITIONTITLE,
                   --PROD.ADDRESS1,
                   PROD.PRODUCERSTATUS,
                   PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME ||
                   PAD.SUFFIX NAME,
                   PAD.PARTICIPANTID CODE,
                   PROD.NATIONALPRODUCERID,
                   PAD.PARTICIPANTGENERICATTRIBUTE4
              FROM PADIMENSION PAD, PRODUCERDIMENSION PROD
             WHERE PROD.REMOVEDATE = C_REMOVEDATE
               AND PROD.PRODUCERKEY = PAD.PRODUCERKEY
               AND PAD.REMOVEDATE = C_REMOVEDATE
               AND PAD.POSITIONSEQ = AUO.W_MANAGERSEQ
               AND AUO.PERIODSTARTDATE BETWEEN PAD.EFFECTIVESTARTDATE AND
                   PAD.EFFECTIVEENDDATE - 1)
     WHERE AUO.PERIODKEY = V_PERIODKEY;
    ------
    DELETE FROM AIA_UNPAID_OVERRIDING AUO WHERE AUO.NAME IS NULL;

    ---------update Agency

    UPDATE AIA_UNPAID_OVERRIDING AUO
       SET (AUO.AGENCY_CODE, AUO.AGENCY_NAME, AUO.CONT_UNIT) =
           (SELECT PAD2.PARTICIPANTID,
                   PAD2.PREFIX || PAD2.FIRSTNAME || PAD2.MIDDLENAME || PAD2.LASTNAME ||
                   PAD2.SUFFIX,
                   PAD2.PARTICIPANTID
              FROM PADIMENSION PAD1, PAROLL PAR, PADIMENSION PAD2
             WHERE PAD1.POSITIONSEQ = DECODE(AUO.POSITIONTITLE,
                                             'Tied Agency-Agent',
                                             AUO.MANAGERSEQ,
                                             AUO.POSITIONSEQ)
               AND PAD1.REMOVEDATE = C_REMOVEDATE
               AND PAD1.EFFECTIVESTARTDATE < AUO.EFFECTIVEENDDATE
               AND PAD1.EFFECTIVEENDDATE > AUO.EFFECTIVESTARTDATE
               AND PAR.REMOVEDATE = C_REMOVEDATE
               AND PAR.EFFECTIVESTARTDATE < AUO.EFFECTIVEENDDATE
               AND PAR.EFFECTIVEENDDATE > AUO.EFFECTIVESTARTDATE
               AND PAR.ROLLTYPE = 'Assigned_Roll'
               AND PAR.FROMPAKEY = PAD1.PAKEY
               AND PAR.TOPAKEY = PAD2.PAKEY
               AND PAD2.REMOVEDATE = C_REMOVEDATE
               AND ROWNUM = 1)
     WHERE AUO.PERIODKEY = V_PERIODKEY;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  PROCEDURE AIA_E13_PROC IS

    /*V_MEASUREMENTFACTKEY NUMBER;
    V_MEAUSREMENTCOUNT   NUMBER;
    V_COMMISSION_TYPE    VARCHAR2(255);
    V_DEPOSIT_VALUE      NUMBER;*/

  BEGIN

    DELETE FROM AIA_FINANCE_E13 T
     WHERE T.CALENDARNAME = V_CALENDARNAME
       AND T.PERIODNAME = V_PERIODNAME;

    DELETE FROM AIA_FINANCE_E13_TOTAL T
     WHERE T.CALENDARNAME = V_CALENDARNAME
       AND T.PERIODNAME = V_PERIODNAME;

    DELETE FROM AIA_FINANCE_E13_BALANCE T
     WHERE T.CALENDARNAME = V_CALENDARNAME
       AND T.PERIODNAME = V_PERIODNAME;
    COMMIT;

    INSERT INTO AIA_FINANCE_E13
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       TRANSACTIONFACTKEY,
       EVENTTYPE,
       CREDITFACTKEY,
       CREDITRULETYPE,
       CREDITTYPE,
       --MEASUREMENTFACTKEY,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       LINE_OF_BUSINESS,
       COMPANY_CODE,
       COMMISSION_TYPE,
       TRANSACTION_DATE,
       AGENT_STATUS,
       UNIT_CODE,
       AGENT_CODE,
       AGENT_NAME,
       BT,
       CREDIT_VALUE,
       CREATE_DATE)
      SELECT PAD.PAKEY,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             TXF.TRANSACTIONFACTKEY,
             TXDM.EVENTTYPE,
             CRDF.CREDITFACTKEY,
             CRDD.CREDITRULETYPE,
             --CRDM.CREDITTYPE,
             (SELECT T.CREDITTYPE
                FROM CREDITDIMENSION T
               WHERE T.CREDITKEY = CRDF.CREDITKEY
                 AND ROWNUM = 1),
             --MEAF.MEASUREMENTFACTKEY,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             (TXD.TRANSACTIONGENERICATTRIBUTE4) LINE_OF_BUSINESS,
             --DECODE(TXD.TRANSACTIONGENERICATTRIBUTE4, 'Takaful', '072', '016'),
             TXD.TRANSACTIONGENERICATTRIBUTE28,
             --EARD.EARNINGCODE COMMISSION_TYPE,
             CRDT.GENERICATTRIBUTE8 COMMISSION_TYPE,
             TIMD.CALENDARDATE TRANSACTION_DATE,
             PROD.PRODUCERSTATUS AGENT_STATUS,
             '' UNIT_CODE,
             PAD.PARTICIPANTID AGENT_CODE,
             PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME ||
             PAD.SUFFIX AGENT_NAME,
             (SELECT T.MAPPINGCODE
                FROM AIA_BUSINESSLINE_MAPPING T
               WHERE T.BUSINESSLINE = UPPER(TXD.TRANSACTIONGENERICATTRIBUTE4)
                 AND T.COMPANYCODE = TXD.TRANSACTIONGENERICATTRIBUTE28
                 AND ROWNUM = 1),
             CRDF.VALUE,
             SYSDATE
        FROM PADIMENSION          PAD,
             PRODUCERDIMENSION    PROD,
             TRANSACTIONFACT      TXF,
             TRANSACTIONDETAIL    TXD,
             TRANSACTIONDIMENSION TXDM,
             CREDITFACT           CRDF,
             CREDITRULEDIMENSION  CRDD,
             CREDITDETAIL         CRDT,
             --CREDITDIMENSION      CRDM,
             --PERIODDIMENSION      PERD,
             TIMEDIMENSION TIMD
       WHERE TXF.TRANSACTIONDETAILKEY = TXD.TRANSACTIONDETAILKEY
         AND TXF.TRANSACTIONKEY = TXDM.TRANSACTIONKEY
         AND TXF.TRANSACTIONFACTKEY = CRDF.TRANSACTIONFACTKEY
         AND PAD.PRODUCERKEY = PROD.PRODUCERKEY
         AND CRDF.PAKEY = PAD.PAKEY
         AND CRDF.PERIODKEY = V_PERIODKEY
         AND CRDF.CREDITRULEKEY = CRDD.CREDITRULEKEY
            --AND CRDD.REMOVEDATE = C_REMOVEDATE
            --AND PAD.REMOVEDATE = C_REMOVEDATE
            --AND PROD.REMOVEDATE = C_REMOVEDATE
         AND TXF.ACCOUNTINGTIMEKEY = TIMD.TIMEKEY
         AND PAD.POSITIONTITLE IN
             ('Tied Agency-UM', 'Tied Agency-DM', 'Tied Agency-Agent')
         AND ((TXDM.EVENTTYPE LIKE '%Commissions' AND
             CRDD.CREDITRULETYPE = 'Direct Transaction Credit Rule') OR
             (TXDM.EVENTTYPE LIKE '%Premiums' AND
             CRDD.CREDITRULETYPE = 'Rollup Transaction Credit Rule'))
         AND CRDF.CREDITDETAILKEY = CRDT.CREDITDETAILKEY
      --         AND PAD.POSITIONNAME IN ('25030','47350','66494')
      /*AND CRDF.CREDITKEY = CRDM.CREDITKEY*/
      ;
    --------old scheme
    AIA_E13_OLD_PROC;
    ------delete commission type is blank
    DELETE FROM AIA_FINANCE_E13 T WHERE T.COMMISSION_TYPE IS NULL;
    COMMIT;

    UPDATE AIA_FINANCE_E13 AFE
    ------for new cheme FYP RYP and MISC
       SET AFE.FIRST_YEAR_COMM   = DECODE(AFE.CREDITTYPE, 'FYC', AFE.CREDIT_VALUE, 0),
           AFE.RENEWAL_YEAR_COMM = DECODE(AFE.CREDITTYPE, 'RYC', AFE.CREDIT_VALUE, 0),
           AFE.MISC              = NVL(( --SELECT SUM(NVL(DEPF.VALUE, 0)) -- changed by corey 20140221
                                       SELECT NVL(CRD.GENERICNUMBER3, 0)
                                         FROM DEPOSITFACT      DEPF,
                                               EARNINGDIMENSION EARD,
                                               CREDITFACT       CRF,
                                               CREDITDETAIL     CRD,
                                               AIA_PAYEE_INFOR  PAY
                                        WHERE EARD.EARNINGCODEID IN
                                              (C_EARNING_CODE(11),
                                               C_EARNING_CODE(12),
                                               C_EARNING_CODE(13),
                                               C_EARNING_CODE(14),
                                               C_EARNING_CODE(15),
                                               C_EARNING_CODE(16),
                                               C_EARNING_CODE(17),
                                               C_EARNING_CODE(18),
                                               C_EARNING_CODE(19),
                                               C_EARNING_CODE(20),
                                               C_EARNING_CODE(21),
                                               C_EARNING_CODE(22),
                                               C_EARNING_CODE(23),
                                               C_EARNING_CODE(24),
                                               C_EARNING_CODE(3),
                                               C_EARNING_CODE(4),
                                               C_EARNING_CODE(5))
                                          AND DEPF.EARNINGKEY = EARD.EARNINGKEY
                                          AND DEPF.PAKEY = PAY.PAKEY
                                          AND AFE.CREDITFACTKEY = CRF.CREDITFACTKEY
                                          AND CRF.CREDITDETAILKEY = CRD.CREDITDETAILKEY
                                          AND PAY.PARTICIPANTID = AFE.AGENT_CODE
                                          AND DEPF.PERIODKEY = AFE.PERIODKEY
                                          AND CRD.GENERICATTRIBUTE8 = EARD.EARNINGCODEID
                                          AND AFE.LINE_OF_BUSINESS = C_EARNING_CODE(101)),
                                       0),

           /*           AFE.NON_EARNING       = NVL((SELECT SUM(NVL(DEPF.VALUE, 0))
             FROM DEPOSITFACT      DEPF,
                  EARNINGDIMENSION EARD,
                  AIA_PAYEE_INFOR  PAY
            WHERE EARD.EARNINGCODEID IN (C_EARNING_CODE(8))
              AND DEPF.EARNINGKEY = EARD.EARNINGKEY
              AND DEPF.PAKEY = PAY.PAKEY
              AND PAY.PARTICIPANTID = AFE.AGENT_CODE
              AND DEPF.PERIODKEY = AFE.PERIODKEY
              AND AFE.LINE_OF_BUSINESS = C_EARNING_CODE(101)),
           0)*/
           AFE.NON_EARNING = NVL((SELECT NVL(CRD.GENERICNUMBER3, 0)
                                   FROM DEPOSITFACT      DEPF,
                                        EARNINGDIMENSION EARD,
                                        CREDITFACT       CRF,
                                        CREDITDETAIL     CRD,
                                        AIA_PAYEE_INFOR  PAY
                                  WHERE EARD.EARNINGCODEID IN (C_EARNING_CODE(8))
                                    AND DEPF.EARNINGKEY = EARD.EARNINGKEY
                                    AND DEPF.PAKEY = PAY.PAKEY
                                    AND AFE.CREDITFACTKEY = CRF.CREDITFACTKEY
                                    AND CRF.CREDITDETAILKEY = CRD.CREDITDETAILKEY
                                    AND PAY.PARTICIPANTID = AFE.AGENT_CODE
                                    AND DEPF.PERIODKEY = AFE.PERIODKEY
                                    AND CRD.GENERICATTRIBUTE8 = EARD.EARNINGCODEID
                                    AND AFE.LINE_OF_BUSINESS = C_EARNING_CODE(101)),
                                 0)
     WHERE AFE.PERIODKEY = V_PERIODKEY
       AND AFE.CREDITFACTKEY IS NOT NULL;

    /*       UPDATE aia_finance_e13 AFE
           SET  AFE.CHECK_AMOUNT = CASE
                                    WHEN (AFE.BEGINNING_BALANCE + AFE.FIRST_YEAR_COMM +
    --formula changed to + AFE.NON_EARNING, by Jason
                                         AFE.RENEWAL_YEAR_COMM + AFE.MISC + AFE.NON_EARNING) < 0 THEN
                                     0
                                    ELSE
                                     0 - (AFE.BEGINNING_BALANCE + AFE.FIRST_YEAR_COMM +
    --formula changed to + AFE.NON_EARNING, by Jason
                                     AFE.RENEWAL_YEAR_COMM + AFE.MISC + AFE.NON_EARNING)
                                  END
         WHERE AFE.PERIODKEY = V_PERIODKEY;*/
    -- changed by corey 20140214

    INSERT INTO AIA_FINANCE_E13_TOTAL
      (PAKEY,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       COMPANY_CODE,
       AGENT_STATUS,
       --UNIT_CODE
       AGENT_CODE,
       AGENT_NAME,
       BT,
       FIRST_YEAR_COMM,
       RENEWAL_YEAR_COMM,
       MISC,
       NON_EARNING,
       CREATE_DATE)
      SELECT AFE.PAKEY,
             AFE.PERIODKEY,
             AFE.CALENDARNAME,
             AFE.PERIODNAME,
             AFE.PERIODSTARTDATE,
             AFE.PERIODENDDATE,
             AFE.POSITIONSEQ,
             AFE.MANAGERSEQ,
             AFE.POSITIONNAME,
             AFE.POSITIONTITLE,
             AFE.COMPANY_CODE,
             AFE.AGENT_STATUS,
             AFE.AGENT_CODE,
             AFE.AGENT_NAME,
             AFE.BT,
             SUM(NVL(AFE.FIRST_YEAR_COMM, 0)),
             SUM(NVL(AFE.RENEWAL_YEAR_COMM, 0)),
             SUM(NVL(AFE.MISC, 0)),
             SUM(NVL(AFE.NON_EARNING, 0)),
             SYSDATE
        FROM AIA_FINANCE_E13 AFE
       WHERE AFE.PERIODKEY = V_PERIODKEY
       GROUP BY AFE.PAKEY,
                AFE.PERIODKEY,
                AFE.CALENDARNAME,
                AFE.PERIODNAME,
                AFE.PERIODSTARTDATE,
                AFE.PERIODENDDATE,
                AFE.POSITIONSEQ,
                AFE.MANAGERSEQ,
                AFE.POSITIONNAME,
                AFE.POSITIONTITLE,
                AFE.COMPANY_CODE,
                AFE.AGENT_STATUS,
                AFE.AGENT_CODE,
                AFE.AGENT_NAME,
                AFE.BT;
    ------update beginning balance
    UPDATE AIA_FINANCE_E13_TOTAL AFET
       SET AFET.BEGINNING_BALANCE = NVL((SELECT SUM(NVL(T.ENDING_BALANCE, 0))
                                          FROM AIA_FINANCE_E13_TOTAL T
                                         WHERE T.PERIODKEY = V_PRIOR_PERIODKEY
                                           AND T.AGENT_CODE = AFET.AGENT_CODE),
                                        0)
     WHERE AFET.PERIODKEY = V_PERIODKEY;

    ------update check amount
    UPDATE AIA_FINANCE_E13_TOTAL AFET
       SET AFET.CHECK_AMOUNT =
           (SELECT CASE
                     WHEN (AFET.BEGINNING_BALANCE + AFET.FIRST_YEAR_COMM +
                          AFET.RENEWAL_YEAR_COMM + AFET.MISC + AFET.NON_EARNING) >= 50 THEN
                      (AFET.BEGINNING_BALANCE + AFET.FIRST_YEAR_COMM +
                      AFET.RENEWAL_YEAR_COMM + AFET.MISC + AFET.NON_EARNING)
                     ELSE
                      0
                   END
              FROM DUAL)

     WHERE AFET.PERIODKEY = V_PERIODKEY;

    ------update ending balance
    UPDATE AIA_FINANCE_E13_TOTAL AFET
       SET AFET.ENDING_BALANCE = AFET.BEGINNING_BALANCE + AFET.FIRST_YEAR_COMM +
                                 AFET.RENEWAL_YEAR_COMM + AFET.MISC + AFET.NON_EARNING -
                                 AFET.CHECK_AMOUNT
     WHERE AFET.PERIODKEY = V_PERIODKEY;

    ---------update UNIT
    UPDATE AIA_FINANCE_E13_TOTAL AFET
       SET (AFET.UNIT_CODE) =
           (SELECT PAD2.PARTICIPANTID
              FROM PADIMENSION PAD1, PAROLL PAR, PADIMENSION PAD2
             WHERE PAD1.POSITIONSEQ = DECODE(AFET.POSITIONTITLE,
                                             'Tied Agency-Agent',
                                             AFET.MANAGERSEQ,
                                             AFET.POSITIONSEQ)
                  --   AND PAD1.REMOVEDATE = C_REMOVEDATE
                  /*               AND PAD1.EFFECTIVESTARTDATE < V_PERIODENDDATE
                  AND PAD1.EFFECTIVEENDDATE > V_PERIODSTARTDATE*/
               AND PAR.ROLLTYPE = 'Assigned_Roll'
                  --AND PAR.REMOVEDATE = C_REMOVEDATE
               AND PAR.FROMPAKEY = PAD1.PAKEY
               AND PAR.TOPAKEY = PAD2.PAKEY
               AND PAD1.PAKEY = (SELECT MAX(T.PAKEY)
                                   FROM PADIMENSION T
                                  WHERE T.POSITIONSEQ = PAD1.POSITIONSEQ
                                    AND T.CREATEDATE < V_PERIODENDDATE)
                  --AND PAD2.REMOVEDATE = C_REMOVEDATE
               AND ROWNUM = 1)
     WHERE AFET.PERIODKEY = V_PERIODKEY;

    ----------insert Balance
    INSERT INTO AIA_FINANCE_E13_BALANCE
      (PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       BALANCE_NAME,
       BALANCE_VALE,
       COMPANY_CODE)
      SELECT AFET.PERIODKEY,
             AFET.CALENDARNAME,
             AFET.PERIODNAME,
             AFET.PERIODSTARTDATE,
             AFET.PERIODENDDATE,
             'BEGINNING BALANCE - ' || (SELECT CASE
                                                 WHEN ABM.BUSINESSLINE = 'EB' THEN
                                                  'GROUP'
                                                 WHEN ABM.BUSINESSLINE = 'PA' THEN
                                                  'GI'
                                                 ELSE
                                                  ABM.BUSINESSLINE
                                               END
                                          FROM AIA_BUSINESSLINE_MAPPING ABM
                                         WHERE ABM.MAPPINGCODE = AFET.BT
                                           AND ABM.COMPANYCODE = AFET.COMPANY_CODE
                                           AND ROWNUM = 1),
             SUM(AFET.BEGINNING_BALANCE),
             AFET.COMPANY_CODE
        FROM AIA_FINANCE_E13_TOTAL AFET
       WHERE AFET.PERIODKEY = V_PERIODKEY
       GROUP BY AFET.PERIODKEY,
                AFET.CALENDARNAME,
                AFET.PERIODNAME,
                AFET.PERIODSTARTDATE,
                AFET.PERIODENDDATE,
                AFET.BT,
                AFET.COMPANY_CODE
      UNION -- changed by corey 20140226
      SELECT AFET.PERIODKEY,
             AFET.CALENDARNAME,
             AFET.PERIODNAME,
             AFET.PERIODSTARTDATE,
             AFET.PERIODENDDATE,
             'TOTAL CHECKS - ' || (SELECT CASE
                                            WHEN ABM.BUSINESSLINE = 'EB' THEN
                                             'GROUP'
                                            WHEN ABM.BUSINESSLINE = 'PA' THEN
                                             'GI'
                                            ELSE
                                             ABM.BUSINESSLINE
                                          END
                                     FROM AIA_BUSINESSLINE_MAPPING ABM
                                    WHERE ABM.MAPPINGCODE = AFET.BT
                                      AND ABM.COMPANYCODE = AFET.COMPANY_CODE
                                      AND ROWNUM = 1),
             SUM(AFET.CHECK_AMOUNT),
             AFET.COMPANY_CODE
        FROM AIA_FINANCE_E13_TOTAL AFET
       WHERE AFET.PERIODKEY = V_PERIODKEY
       GROUP BY AFET.PERIODKEY,
                AFET.CALENDARNAME,
                AFET.PERIODNAME,
                AFET.PERIODSTARTDATE,
                AFET.PERIODENDDATE,
                AFET.BT,
                AFET.COMPANY_CODE
      UNION
      SELECT AFET.PERIODKEY,
             AFET.CALENDARNAME,
             AFET.PERIODNAME,
             AFET.PERIODSTARTDATE,
             AFET.PERIODENDDATE,
             /*'BEGINNING BALANCE - ' || AFE.LINE_OF_BUSINESS*/
             'ENDING BALANCE - ' || (SELECT CASE
                                              WHEN ABM.BUSINESSLINE = 'EB' THEN
                                               'GROUP'
                                              WHEN ABM.BUSINESSLINE = 'PA' THEN
                                               'GI'
                                              ELSE
                                               ABM.BUSINESSLINE
                                            END
                                       FROM AIA_BUSINESSLINE_MAPPING ABM
                                      WHERE ABM.MAPPINGCODE = AFET.BT
                                        AND ABM.COMPANYCODE = AFET.COMPANY_CODE
                                        AND ROWNUM = 1),
             SUM(AFET.ENDING_BALANCE),
             AFET.COMPANY_CODE
        FROM AIA_FINANCE_E13_TOTAL AFET
       WHERE AFET.PERIODKEY = V_PERIODKEY
       GROUP BY AFET.PERIODKEY,
                AFET.CALENDARNAME,
                AFET.PERIODNAME,
                AFET.PERIODSTARTDATE,
                AFET.PERIODENDDATE,
                AFET.BT,
                AFET.COMPANY_CODE;

    INSERT INTO AIA_FINANCE_E13_BALANCE
      (PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       BALANCE_NAME,
       BALANCE_VALE,
       COMPANY_CODE)
      SELECT AFE.PERIODKEY,
             AFE.CALENDARNAME,
             AFE.PERIODNAME,
             AFE.PERIODSTARTDATE,
             AFE.PERIODENDDATE,
             'FIRST YEAR EARNINGS',
             SUM(AFE.FIRST_YEAR_COMM),
             AFE.COMPANY_CODE
        FROM AIA_FINANCE_E13 AFE
       WHERE AFE.PERIODKEY = V_PERIODKEY
       GROUP BY AFE.PERIODKEY,
                AFE.CALENDARNAME,
                AFE.PERIODNAME,
                AFE.PERIODSTARTDATE,
                AFE.PERIODENDDATE,
                AFE.COMPANY_CODE;
    INSERT INTO AIA_FINANCE_E13_BALANCE
      (PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       BALANCE_NAME,
       BALANCE_VALE,
       COMPANY_CODE)
      SELECT AFE.PERIODKEY,
             AFE.CALENDARNAME,
             AFE.PERIODNAME,
             AFE.PERIODSTARTDATE,
             AFE.PERIODENDDATE,
             'RENEWAL EARNINGS',
             SUM(AFE.RENEWAL_YEAR_COMM),
             AFE.COMPANY_CODE
        FROM AIA_FINANCE_E13 AFE
       WHERE AFE.PERIODKEY = V_PERIODKEY
       GROUP BY AFE.PERIODKEY,
                AFE.CALENDARNAME,
                AFE.PERIODNAME,
                AFE.PERIODSTARTDATE,
                AFE.PERIODENDDATE,
                AFE.COMPANY_CODE;
    INSERT INTO AIA_FINANCE_E13_BALANCE
      (PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       BALANCE_NAME,
       BALANCE_VALE,
       COMPANY_CODE)
      SELECT AFE.PERIODKEY,
             AFE.CALENDARNAME,
             AFE.PERIODNAME,
             AFE.PERIODSTARTDATE,
             AFE.PERIODENDDATE,
             'MISC. EARNINGS',
             SUM(AFE.MISC),
             AFE.COMPANY_CODE
        FROM AIA_FINANCE_E13 AFE
       WHERE AFE.PERIODKEY = V_PERIODKEY
       GROUP BY AFE.PERIODKEY,
                AFE.CALENDARNAME,
                AFE.PERIODNAME,
                AFE.PERIODSTARTDATE,
                AFE.PERIODENDDATE,
                AFE.COMPANY_CODE;
    INSERT INTO AIA_FINANCE_E13_BALANCE
      (PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       BALANCE_NAME,
       BALANCE_VALE,
       COMPANY_CODE)
      SELECT AFE.PERIODKEY,
             AFE.CALENDARNAME,
             AFE.PERIODNAME,
             AFE.PERIODSTARTDATE,
             AFE.PERIODENDDATE,
             'NON EARNINGS',
             SUM(AFE.NON_EARNING),
             AFE.COMPANY_CODE
        FROM AIA_FINANCE_E13 AFE
       WHERE AFE.PERIODKEY = V_PERIODKEY
       GROUP BY AFE.PERIODKEY,
                AFE.CALENDARNAME,
                AFE.PERIODNAME,
                AFE.PERIODSTARTDATE,
                AFE.PERIODENDDATE,
                AFE.COMPANY_CODE;

    UPDATE AIA_FINANCE_E13 AFE
       SET AFE.CREATE_DATE = SYSDATE
     WHERE AFE.PERIODKEY = V_PERIODKEY;
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('E13 ERROR');
      NULL;

  END;

  PROCEDURE AIA_E13_OLD_PROC IS
  BEGIN
    INSERT INTO AIA_FINANCE_E13
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       CREDITTYPE,
       --MEASUREMENTFACTKEY,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       LINE_OF_BUSINESS,
       COMPANY_CODE,
       AGENT_STATUS,
       UNIT_CODE,
       AGENT_CODE,
       AGENT_NAME,
       BT,
       TRANSACTION_DATE,
       FIRST_YEAR_COMM,
       RENEWAL_YEAR_COMM,
       MISC,
       NON_EARNING,
       CREDIT_VALUE,
       COMMISSION_TYPE,
       DEPOSIT_VALUE,
       CREATE_DATE)
      SELECT AOSD.PAKEY,
             AOSD.EFFECTIVESTARTDATE,
             AOSD.EFFECTIVEENDDATE,
             --CRDM.CREDITTYPE,
             '',
             --MEAF.MEASUREMENTFACTKEY,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             AOSD.POSITIONSEQ,
             AOSD.MANAGERSEQ,
             AOSD.POSITIONNAME,
             AOSD.POSITIONTITLE,
             AOSD.BUSINESS_LINE LINE_OF_BUSINESS,
             AOSD.COMPANY_CODE,
             AOSD.STATUS_CODE AGENT_STATUS,
             '' UNIT_CODE,
             AOSD.PRODUCERCODE AGENT_CODE,
             AOSD.PRODUCERNAME AGENT_NAME,
             (SELECT T.MAPPINGCODE
                FROM AIA_BUSINESSLINE_MAPPING T
               WHERE T.BUSINESSLINE = UPPER(AOSD.BUSINESS_LINE)
                 AND T.COMPANYCODE = AOSD.COMPANY_CODE
                 AND ROWNUM = 1),
             AOSD.ACCOUNTING_DATE,
             CASE
               WHEN AOSD.TAX_IND = 'Y' AND AOSD.EARNING_CODE = C_EARNING_CODE(1) AND
                    AOSD.POLICY_YEAR IN (1, 997) THEN
                AOSD.VALUE
               ELSE
                0
             END FIRST_YEAR,
             CASE
               WHEN AOSD.TAX_IND = 'Y' AND AOSD.EARNING_CODE = C_EARNING_CODE(1) AND
                    (AOSD.POLICY_YEAR BETWEEN 2 AND 6 OR AOSD.POLICY_YEAR = 998) THEN
                AOSD.VALUE
               ELSE
                0
             END RENEWAL_YEAR,
             CASE
               WHEN AOSD.TAX_IND = 'Y' AND AOSD.EARNING_CODE = C_EARNING_CODE(28) AND
                    AOSD.DESCRIPTION NOT IN
                    (C_EARNING_CODE(301),
                     C_EARNING_CODE(302),
                     C_EARNING_CODE(303),
                     C_EARNING_CODE(304),
                     C_EARNING_CODE(305),
                     C_EARNING_CODE(306),
                     C_EARNING_CODE(307)) THEN
                AOSD.VALUE
               ELSE
                0
             END MISC,
             CASE
               WHEN AOSD.TAX_IND = 'N' OR AOSD.TAX_IND IS NULL THEN
                AOSD.VALUE
               ELSE
                0
             END NON_EARNING,
             AOSD.VALUE,
             AOSD.EARNING_CODE,
             AOSD.VALUE,
             SYSDATE
        FROM AIA_OLD_SCHEME_DTL AOSD
       WHERE AOSD.POSITIONTITLE IN
             ('Tied Agency-UM', 'Tied Agency-DM', 'Tied Agency-Agent')
         AND AOSD.EARNING_CODE NOT IN (C_EARNING_CODE(28),
                                       C_EARNING_CODE(3),
                                       C_EARNING_CODE(4),
                                       C_EARNING_CODE(5)); ------MORE EARNING CODES
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  PROCEDURE AIA_E90_PROC IS
  BEGIN

    DELETE FROM AIA_FINANCE_E90_COMMOR T;
    DELETE FROM AIA_FINANCE_E90_BONUS T;
    DELETE FROM AIA_FINANCE_E90_TOTAL T
     WHERE T.CALENDARNAME = V_CALENDARNAME
       AND T.PERIODNAME = V_PERIODNAME;
    DELETE FROM AIA_FINANCE_E90_SUM T
     WHERE T.CALENDARNAME = V_CALENDARNAME
       AND T.PERIODNAME = V_PERIODNAME;

    INSERT INTO AIA_FINANCE_E90_COMMOR
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       TRANSACTIONFACTKEY,
       EVENTTYPE,
       CREDITFACTKEY,
       CREDITRULETYPE,
       --MEASUREMENTFACTKEY,
       CREDITTYPE,
       GLPREMIUM,
       PARCODE,
       BUSINESSLINE,
       CHANNELCODE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       COMPANY_CODE,
       BATCH_NUMBER,
       VOUCHER_NUMBER,
       TRANSACTION_NUMBER,
       --ACCOUNT_NUMBER,
       TRANSACTION_DATE,
       REPORTING_SOURCE,
       AMOUNT,
       CURRENCY_CODE,
       POLICY_NUMBER,
       SUSPENSE_CTL_NO,
       AGENT_NUMBER,
       COLUMN_PAR_CODE,
       COLLECTION_STATION)
      SELECT PAD.PAKEY,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             TXF.TRANSACTIONFACTKEY,
             TXDM.EVENTTYPE,
             CRDF.CREDITFACTKEY,
             CRDD.CREDITRULETYPE,
             --MEAF.MEASUREMENTFACTKEY,
             CRDM.CREDITTYPE,
             TXD.TRANSACTIONGENERICATTRIBUTE12,
             TXD.TRANSACTIONGENERICATTRIBUTE3,
             CASE
               WHEN UPPER(TXD.TRANSACTIONGENERICATTRIBUTE4) IN
                    (C_EARNING_CODE(101), C_EARNING_CODE(102)) AND
                    TXD.TRANSACTIONGENERICATTRIBUTE3 = 'V' THEN
                UPPER(TXD.TRANSACTIONGENERICATTRIBUTE4) || '_ILE'
               ELSE
                UPPER(TXD.TRANSACTIONGENERICATTRIBUTE4)
             END,
             TXDM.CHANNEL,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             TXD.TRANSACTIONGENERICATTRIBUTE28 COMPANY_CODE,
             'AASM' BATCH_NUMBER,
             'AA00001' VOUCHER_NUMBER, --increament 1 by every 70
             '01' TRANSACTION_NUMBER, --increament 1 and reset when 70
             --DEPOSITDETAIL.GENERICATTRIBUTE1 ACCOUNT_NUMBER,
             TIMD.CALENDARDATE TRANSACTION_DATE, -- TRANSACTIONFACT.COMPTIMEKEY
             TXDM.DATASOURCE REPORTING_SOURCE,
             TXF.VALUE AMOUNT,
             '025' CURRENCY_CODE,
             --SUBSTR(TXF.ORDERID, 11, 8) POLICY_NUMBER,
             TXD.TRANSACTIONGENERICATTRIBUTE20 POLICY,
             '' SUSPENSE_CONTROL_NUMBER, --TBC
             PAD.PARTICIPANTID AGENT_NUMBER,
             --TXD.PRODUCTDESCRIPTION COLUMN_PAR_CODE,
             (SELECT T.MAPPINGCODE
                FROM AIA_PARCODE_MAPPING T
               WHERE T.PRODUCTDESCRIPTION = TXD.PRODUCTDESCRIPTION
                 AND ROWNUM = 1) COLUMN_PAR_CODE,
             '' COLLECTION_STATION --TBC
        FROM PADIMENSION          PAD,
             PRODUCERDIMENSION    PROD,
             TRANSACTIONFACT      TXF,
             TRANSACTIONDETAIL    TXD,
             TRANSACTIONDIMENSION TXDM,
             CREDITFACT           CRDF,
             CREDITRULEDIMENSION  CRDD,
             CREDITDIMENSION      CRDM,
             TIMEDIMENSION        TIMD
       WHERE TXF.TRANSACTIONDETAILKEY = TXD.TRANSACTIONDETAILKEY
         AND TXF.TRANSACTIONKEY = TXDM.TRANSACTIONKEY
         AND TXF.TRANSACTIONFACTKEY = CRDF.TRANSACTIONFACTKEY
         AND PAD.PRODUCERKEY = PROD.PRODUCERKEY
         AND CRDF.PAKEY = PAD.PAKEY
         AND CRDF.PERIODKEY = V_PERIODKEY
         AND CRDF.CREDITRULEKEY = CRDD.CREDITRULEKEY
         AND CRDF.CREDITKEY = CRDM.CREDITKEY
            --AND CRDD.REMOVEDATE = C_REMOVEDATE
            --AND PAD.REMOVEDATE = C_REMOVEDATE
            --AND PROD.REMOVEDATE = C_REMOVEDATE
         AND TXF.ACCOUNTINGTIMEKEY = TIMD.TIMEKEY
         AND PAD.POSITIONTITLE IN
             ('Tied Agency-UM', 'Tied Agency-DM', 'Tied Agency-Agent');

    INSERT INTO AIA_FINANCE_E90_TOTAL
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       CREDITFACTKEY,
       CREDITTYPE,
       PREMIUMTYPE,
       PNV,
       BUSINESSLINE,
       --DEPOSITNAME,
       ACCOUNTNUMBER,
       ACCOUNTTYPE,
       POLICYTYPE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       COMPANY_CODE,
       BATCH_NUMBER,
       VOUCHER_NUMBER,
       TRANSACTION_NUMBER,
       ACCOUNT_NUMBER,
       TRANSACTION_DATE,
       REPORTING_SOURCE,
       AMOUNT,
       CURRENCY_CODE,
       POLICY_NUMBER,
       SUSPENSE_CTL_NO,
       AGENT_NUMBER,
       UNIT_CODE,
       COLUMN_PAR_CODE,
       COLLECTION_STATION)
      SELECT AFEC.PAKEY,
             AFEC.EFFECTIVESTARTDATE,
             AFEC.EFFECTIVEENDDATE,
             AFEC.CREDITFACTKEY,
             AFEC.CREDITTYPE,
             AFEC.GLPREMIUM,
             AFEC.PARCODE,
             AFEC.BUSINESSLINE,
             (SELECT T.ACCOUNTNUMBER
                FROM AIA_MALAYSIA_ACCOUNT_NUMBER T
               WHERE T.ACCOUNTTYPE = 'expense'
                 AND T.GLPREMIUM = AFEC.GLPREMIUM
                 AND T.BUSINESSLINE = AFEC.BUSINESSLINE
                 AND T.CHANNELCODE = AFEC.CHANNELCODE
                 AND T.CATEGORYTREE = 'Account Codes'
                 AND ROWNUM = 1),
             'expense',
             'commor',
             AFEC.PERIODKEY,
             AFEC.CALENDARNAME,
             AFEC.PERIODNAME,
             AFEC.PERIODSTARTDATE,
             AFEC.PERIODENDDATE,
             AFEC.POSITIONSEQ,
             AFEC.MANAGERSEQ,
             AFEC.POSITIONNAME,
             AFEC.POSITIONTITLE,
             AFEC.COMPANY_CODE,
             AFEC.BATCH_NUMBER,
             AFEC.VOUCHER_NUMBER,
             AFEC.TRANSACTION_NUMBER,
             AFEC.ACCOUNT_NUMBER,
             AFEC.TRANSACTION_DATE,
             AFEC.REPORTING_SOURCE,
             AFEC.AMOUNT,
             AFEC.CURRENCY_CODE,
             AFEC.POLICY_NUMBER,
             AFEC.SUSPENSE_CTL_NO,
             AFEC.AGENT_NUMBER,
             AFEC.UNIT_CODE,
             AFEC.COLUMN_PAR_CODE,
             AFEC.COLLECTION_STATION
        FROM AIA_FINANCE_E90_COMMOR AFEC
       WHERE AFEC.PERIODKEY = V_PERIODKEY;
    INSERT INTO AIA_FINANCE_E90_TOTAL
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       CREDITFACTKEY,
       CREDITTYPE,
       PREMIUMTYPE,
       PNV,
       BUSINESSLINE,
       --DEPOSITNAME,
       ACCOUNTNUMBER,
       ACCOUNTTYPE,
       POLICYTYPE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       COMPANY_CODE,
       BATCH_NUMBER,
       VOUCHER_NUMBER,
       TRANSACTION_NUMBER,
       ACCOUNT_NUMBER,
       TRANSACTION_DATE,
       REPORTING_SOURCE,
       AMOUNT,
       CURRENCY_CODE,
       POLICY_NUMBER,
       SUSPENSE_CTL_NO,
       AGENT_NUMBER,
       UNIT_CODE,
       COLUMN_PAR_CODE,
       COLLECTION_STATION)
      SELECT AFEC.PAKEY,
             AFEC.EFFECTIVESTARTDATE,
             AFEC.EFFECTIVEENDDATE,
             AFEC.CREDITFACTKEY,
             AFEC.CREDITTYPE,
             AFEC.GLPREMIUM,
             AFEC.PARCODE,
             AFEC.BUSINESSLINE,
             (SELECT T.ACCOUNTNUMBER
                FROM AIA_MALAYSIA_ACCOUNT_NUMBER T
               WHERE T.ACCOUNTTYPE = 'agtbalance'
                 AND T.CATEGORYTREE = 'Agent Balance Account'
                 AND T.CATEGORYNAME = AFEC.BUSINESSLINE
                 AND ROWNUM = 1),
             'agtbalance',
             'commor',
             AFEC.PERIODKEY,
             AFEC.CALENDARNAME,
             AFEC.PERIODNAME,
             AFEC.PERIODSTARTDATE,
             AFEC.PERIODENDDATE,
             AFEC.POSITIONSEQ,
             AFEC.MANAGERSEQ,
             AFEC.POSITIONNAME,
             AFEC.POSITIONTITLE,
             AFEC.COMPANY_CODE,
             AFEC.BATCH_NUMBER,
             AFEC.VOUCHER_NUMBER,
             AFEC.TRANSACTION_NUMBER,
             AFEC.ACCOUNT_NUMBER,
             AFEC.TRANSACTION_DATE,
             AFEC.REPORTING_SOURCE,
             AFEC.AMOUNT,
             AFEC.CURRENCY_CODE,
             AFEC.POLICY_NUMBER,
             AFEC.SUSPENSE_CTL_NO,
             AFEC.AGENT_NUMBER,
             AFEC.UNIT_CODE,
             AFEC.COLUMN_PAR_CODE,
             AFEC.COLLECTION_STATION
        FROM AIA_FINANCE_E90_COMMOR AFEC
       WHERE AFEC.PERIODKEY = V_PERIODKEY;

    INSERT INTO AIA_FINANCE_E90_BONUS
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       DEPOSITFACTKEY,
       DEPOSITNAME,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       COMPANY_CODE,
       BATCH_NUMBER,
       VOUCHER_NUMBER,
       TRANSACTION_NUMBER,
       --ACCOUNT_NUMBER,
       TRANSACTION_DATE,
       REPORTING_SOURCE,
       AMOUNT,
       CURRENCY_CODE,
       POLICY_NUMBER,
       SUSPENSE_CTL_NO,
       AGENT_NUMBER,
       COLUMN_PAR_CODE,
       COLLECTION_STATION)
      SELECT PAD.PAKEY,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             DEPF.DEPOSITFACTKEY,
             DEPD.DEPOSITNAME,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             NULL, --TXD.TRANSACTIONGENERICATTRIBUTE28 COMPANY_CODE,
             'AASM' BATCH_NUMBER,
             'AA00001' VOUCHER_NUMBER, --increament 1 by every 70
             '01' TRANSACTION_NUMBER, --increament 1 and reset when 70
             --DEPOSITDETAIL.GENERICATTRIBUTE1 ACCOUNT_NUMBER,
             V_PERIODENDDATE - 1, --TIMD.CALENDARDATE TRANSACTION_DATE, -- TRANSACTIONFACT.COMPTIMEKEY
             NULL, --TXDM.DATASOURCE REPORTING_SOURCE,
             DEPF.VALUE, --TXF.VALUE AMOUNT,
             '025' CURRENCY_CODE,
             NULL, --SUBSTR(TXF.ORDERID, 11, 8) POLICY_NUMBER,
             '' SUSPENSE_CONTROL_NUMBER, --TBC
             PAD.PARTICIPANTID AGENT_NUMBER,
             NULL, --TXD.PRODUCTDESCRIPTION COLUMN_PAR_CODE,
             '' COLLECTION_STATION --TBC
        FROM PADIMENSION       PAD,
             PRODUCERDIMENSION PROD,
             DEPOSITFACT       DEPF,
             DEPOSITDIMENSION  DEPD
       WHERE PAD.PRODUCERKEY = PROD.PRODUCERKEY
         AND DEPF.PAKEY = PAD.PAKEY
         AND DEPF.PERIODKEY = V_PERIODKEY
         AND DEPF.DEPOSITKEY = DEPD.DEPOSITKEY
            --AND PAD.REMOVEDATE = C_REMOVEDATE
            --AND PROD.REMOVEDATE = C_REMOVEDATE
         AND PAD.POSITIONTITLE IN
             ('Tied Agency-UM', 'Tied Agency-DM', 'Tied Agency-Agent');

    INSERT INTO AIA_FINANCE_E90_TOTAL
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       --CREDITTYPE,
       --PREMIUMTYPE,
       --PNV,
       --BUSINESSLINE,
       DEPOSITFACTKEY,
       DEPOSITNAME,
       ACCOUNTNUMBER,
       ACCOUNTTYPE,
       POLICYTYPE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       COMPANY_CODE,
       BATCH_NUMBER,
       VOUCHER_NUMBER,
       TRANSACTION_NUMBER,
       ACCOUNT_NUMBER,
       TRANSACTION_DATE,
       REPORTING_SOURCE,
       AMOUNT,
       CURRENCY_CODE,
       POLICY_NUMBER,
       SUSPENSE_CTL_NO,
       AGENT_NUMBER,
       UNIT_CODE,
       COLUMN_PAR_CODE,
       COLLECTION_STATION)
      SELECT AFEB.PAKEY,
             AFEB.EFFECTIVESTARTDATE,
             AFEB.EFFECTIVEENDDATE,
             AFEB.DEPOSITFACTKEY,
             AFEB.DEPOSITNAME,
             (SELECT T.ACCOUNTNUMBER
                FROM AIA_MALAYSIA_ACCOUNT_NUMBER T
               WHERE T.ACCOUNTTYPE = 'expense'
                 AND T.CATEGORYTREE = 'Bonus Expense Account'
                 AND T.CATEGORYNAME = AFEB.DEPOSITNAME
                 AND ROWNUM = 1),
             'expense',
             'bonus',
             AFEB.PERIODKEY,
             AFEB.CALENDARNAME,
             AFEB.PERIODNAME,
             AFEB.PERIODSTARTDATE,
             AFEB.PERIODENDDATE,
             AFEB.POSITIONSEQ,
             AFEB.MANAGERSEQ,
             AFEB.POSITIONNAME,
             AFEB.POSITIONTITLE,
             AFEB.COMPANY_CODE,
             AFEB.BATCH_NUMBER,
             AFEB.VOUCHER_NUMBER,
             AFEB.TRANSACTION_NUMBER,
             AFEB.ACCOUNT_NUMBER,
             AFEB.TRANSACTION_DATE,
             AFEB.REPORTING_SOURCE,
             AFEB.AMOUNT,
             AFEB.CURRENCY_CODE,
             AFEB.POLICY_NUMBER,
             AFEB.SUSPENSE_CTL_NO,
             AFEB.AGENT_NUMBER,
             AFEB.UNIT_CODE,
             AFEB.COLUMN_PAR_CODE,
             AFEB.COLLECTION_STATION
        FROM AIA_FINANCE_E90_BONUS AFEB
       WHERE AFEB.PERIODKEY = V_PERIODKEY;
    INSERT INTO AIA_FINANCE_E90_TOTAL
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       --CREDITTYPE,
       --PREMIUMTYPE,
       --PNV,
       --BUSINESSLINE,
       DEPOSITFACTKEY,
       DEPOSITNAME,
       ACCOUNTNUMBER,
       ACCOUNTTYPE,
       POLICYTYPE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       COMPANY_CODE,
       BATCH_NUMBER,
       VOUCHER_NUMBER,
       TRANSACTION_NUMBER,
       ACCOUNT_NUMBER,
       TRANSACTION_DATE,
       REPORTING_SOURCE,
       AMOUNT,
       CURRENCY_CODE,
       POLICY_NUMBER,
       SUSPENSE_CTL_NO,
       AGENT_NUMBER,
       UNIT_CODE,
       COLUMN_PAR_CODE,
       COLLECTION_STATION)
      SELECT AFEB.PAKEY,
             AFEB.EFFECTIVESTARTDATE,
             AFEB.EFFECTIVEENDDATE,
             AFEB.DEPOSITFACTKEY,
             AFEB.DEPOSITNAME,
             (SELECT T.ACCOUNTNUMBER
                FROM AIA_MALAYSIA_ACCOUNT_NUMBER T
               WHERE T.ACCOUNTTYPE = 'agtbalance'
                 AND T.CATEGORYTREE = 'Agent Balance Account'
                 AND T.CATEGORYNAME = AFEB.DEPOSITNAME
                 AND ROWNUM = 1),
             'agtbalance',
             'bonus',
             AFEB.PERIODKEY,
             AFEB.CALENDARNAME,
             AFEB.PERIODNAME,
             AFEB.PERIODSTARTDATE,
             AFEB.PERIODENDDATE,
             AFEB.POSITIONSEQ,
             AFEB.MANAGERSEQ,
             AFEB.POSITIONNAME,
             AFEB.POSITIONTITLE,
             AFEB.COMPANY_CODE,
             AFEB.BATCH_NUMBER,
             AFEB.VOUCHER_NUMBER,
             AFEB.TRANSACTION_NUMBER,
             AFEB.ACCOUNT_NUMBER,
             AFEB.TRANSACTION_DATE,
             AFEB.REPORTING_SOURCE,
             AFEB.AMOUNT,
             AFEB.CURRENCY_CODE,
             AFEB.POLICY_NUMBER,
             AFEB.SUSPENSE_CTL_NO,
             AFEB.AGENT_NUMBER,
             AFEB.UNIT_CODE,
             AFEB.COLUMN_PAR_CODE,
             AFEB.COLLECTION_STATION
        FROM AIA_FINANCE_E90_BONUS AFEB
       WHERE AFEB.PERIODKEY = V_PERIODKEY;

    INSERT INTO AIA_FINANCE_E90_SUM
      (PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       TOTAL_DEBIT,
       TOTAL_CREDIT,
       TOTAL_SUM)
      SELECT V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             SUM(CASE
                   WHEN T.ACCOUNTTYPE = 'expense' THEN
                    T.AMOUNT
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.ACCOUNTTYPE = 'agtbalance' THEN
                    T.AMOUNT
                   ELSE
                    0
                 END),
             SUM(CASE
                   WHEN T.ACCOUNTTYPE = 'expense' THEN
                    T.AMOUNT
                   ELSE
                    0
                 END) - SUM(CASE
                              WHEN T.ACCOUNTTYPE = 'agtbalance' THEN
                               T.AMOUNT
                              ELSE
                               0
                            END)
        FROM AIA_FINANCE_E90_TOTAL T
       WHERE T.PERIODKEY = V_PERIODKEY
       GROUP BY T.PERIODKEY,
                T.CALENDARNAME,
                T.PERIODNAME,
                T.PERIODSTARTDATE,
                T.PERIODENDDATE;

    COMMIT;
    AIA_E90_OLD_PROC;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  PROCEDURE AIA_E90_OLD_PROC IS
  BEGIN
    INSERT INTO AIA_FINANCE_E90_TOTAL
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       --CREDITFACTKEY,
       --CREDITTYPE,
       PREMIUMTYPE,
       PNV,
       BUSINESSLINE,
       --DEPOSITNAME,
       ACCOUNTNUMBER,
       ACCOUNTTYPE,
       POLICYTYPE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       COMPANY_CODE,
       BATCH_NUMBER,
       VOUCHER_NUMBER,
       TRANSACTION_NUMBER,
       ACCOUNT_NUMBER,
       TRANSACTION_DATE,
       REPORTING_SOURCE,
       AMOUNT,
       CURRENCY_CODE,
       POLICY_NUMBER,
       SUSPENSE_CTL_NO,
       AGENT_NUMBER,
       UNIT_CODE,
       COLUMN_PAR_CODE,
       COLLECTION_STATION)
      SELECT AOSD.PAKEY,
             AOSD.EFFECTIVESTARTDATE,
             AOSD.EFFECTIVEENDDATE,
             --AFEC.CREDITFACTKEY,
             --AFEC.CREDITTYPE,
             '', --GLPREMIUM TYPE,
             '', --AFEC.PNV,
             AOSD.BUSINESS_LINE,
             NULL,
             'expense',
             'commor',
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             AOSD.POSITIONSEQ,
             AOSD.MANAGERSEQ,
             AOSD.POSITIONNAME,
             AOSD.POSITIONTITLE,
             AOSD.COMPANY_CODE,
             'AASM', --AFEC.BATCH_NUMBER,
             'AA00001', --AFEC.VOUCHER_NUMBER,
             '01', --AFEC.TRANSACTION_NUMBER,
             '', --AFEC.ACCOUNT_NUMBER,
             AOSD.ACCOUNTING_DATE, --AFEC.TRANSACTION_DATE,
             AOSD.DATASOURCE, --AFEC.REPORTING_SOURCE,
             AOSD.VALUE, --AFEC.AMOUNT,
             '025', --AFEC.CURRENCY_CODE,
             AOSD.POLICY_NO, --AFEC.POLICY_NUMBER,
             '', --AFEC.SUSPENSE_CTL_NO,
             AOSD.PRODUCERCODE, --AFEC.AGENT_NUMBER,
             '', --AFEC.UNIT_CODE,
             '', --AFEC.COLUMN_PAR_CODE,
             '' --AFEC.COLLECTION_STATION
        FROM AIA_OLD_SCHEME_DTL AOSD
       WHERE AOSD.PERIODKEY = V_PERIODKEY
         AND AOSD.POSITIONTITLE IN
             ('Tied Agency-UM', 'Tied Agency-DM', 'Tied Agency-Agent');
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  /*
    PROCEDURE AIA_TAKAFUL_BAL_PAYMENT_PROC IS
    BEGIN
      DELETE FROM AIA_TAKAFUL_BALANCE_PAYMENT T
       WHERE T.CALENDARNAME = V_CALENDARNAME
         AND T.PERIODNAME = V_PERIODNAME;
      COMMIT;

      INSERT INTO AIA_TAKAFUL_BALANCE_PAYMENT
        (PRODUCERSEQ,
         PRODUCERCODE,
         PRODUCERNAME,
         PERIODSEQ,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         BUSINESSLINE,
  --       BEGINNINGBALANCE,
         EARNING,
         OVERTHRESHOLD,
         PAYMENT,
        -- ENDINGBALANCE,
         CURRENCYCODE,
         CREATEDDATE
        )
       SELECT PAD.PAKEY PRODUCERSEQ,
               PAD.PARTICIPANTID PRODUCERCODE,
               PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME || PAD.SUFFIX PRODUCERNAME,
               V_PERIODKEY,
               V_CALENDARNAME,
               V_PERIODNAME,
               V_PERIODSTARTDATE,
               V_PERIODENDDATE,
               CRDT.GENERICATTRIBUTE7 BUSINESSLINE,
               SUM(CRDT.GENERICNUMBER3) EARNING,
               CASE
                 WHEN PAYF.VALUE>0 THEN 1
                   ELSE 0
                END OVERTHRESHOLD,
               PAYF.VALUE PAYMENT,
               'MYR',
                SYSDATE
         FROM PADIMENSION          PAD,
             PRODUCERDIMENSION    PROD,
             CREDITFACT           CRDF,
             CREDITRULEDIMENSION  CRDD,
             CREDITDETAIL         CRDT,
             CREDITDIMENSION      CRDM,
             PAYMENTFACT          PAYF
         WHERE  PAD.PRODUCERKEY = PROD.PRODUCERKEY
         AND CRDF.PAKEY = PAD.PAKEY
         AND CRDF.PERIODKEY = V_PERIODKEY
         AND CRDF.CREDITRULEKEY = CRDD.CREDITRULEKEY
         AND PAD.REMOVEDATE = TO_DATE('2200-1-1', 'YYYY-MM-DD')
         AND PROD.REMOVEDATE = TO_DATE('2200-1-1', 'YYYY-MM-DD')
         AND PAD.POSITIONTITLE IN ('Tied Agency-UM', 'Tied Agency-DM', 'Tied Agency-Agent')
         AND CRDF.CREDITDETAILKEY = CRDT.CREDITDETAILKEY
         AND CRDF.CREDITKEY = CRDM.CREDITKEY
         AND CRDT.GENERICATTRIBUTE7 = 'TAKAFUL'
         AND CRDT.GENERICATTRIBUTE8 IS NOT NULL
         AND CRDM.CREDITTYPE IN ('FYC',
                                 'RYC',
                                 'FYC Unpaid Payout',
                                 'RYC Unpaid Payout',
                                 'FYP DO',
                                 'FYP DO PayOut',
                                 'FYP IO',
                                 'FYP IO PayOut',
                                 'FYP PO',
                                 'FYP PO PayOut',
                                 'FYP SDO',
                                 'FYP SDO PayOut',
                                 'FYP SO',
                                 'FYP SO PayOut',
                                 'RYP DO',
                                 'RYP DO PayOut',
                                 'RYP IO',
                                 'RYP IO PayOut',
                                 'RYP PO',
                                 'RYP PO PayOut',
                                 'RYP SDO',
                                 'RYP SDO PayOut',
                                 'RYP SO',
                                 'RYP SO PayOut')
       AND PAYF.PAKEY = PAD.PAKEY
       AND PAYF.PERIODKEY = CRDF.PERIODKEY
       GROUP BY PAD.PAKEY,
                PAD.PARTICIPANTID,
                PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME || PAD.SUFFIX,
                CRDT.GENERICATTRIBUTE7,
                CRDF.PERIODKEY,
                PAYF.VALUE;

       COMMIT;
       -- update beginningbalance
      UPDATE   AIA_TAKAFUL_BALANCE_PAYMENT ATBF
      SET ATBF.BEGINNINGBALANCE = NVL((
          SELECT NVL(T.ENDINGBALANCE,0)
          FROM AIA_TAKAFUL_BALANCE_PAYMENT T
          WHERE T.PERIODSEQ = V_PRIOR_PERIODKEY
          AND T.PRODUCERCODE = ATBF.PRODUCERCODE
      ),0)
      WHERE  ATBF.PERIODSEQ = V_PERIODKEY;

      -----update ending balance and check amount
      --equals "beginning balance + earning - payment"

      UPDATE AIA_TAKAFUL_BALANCE_PAYMENT ATBP
         SET ATBP.Endingbalance = ATBP.BEGINNINGBALANCE + ATBP.EARNING - PAYMENT;

      COMMIT;

    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('AIA_TAKAFUL_BAL_PAYMENT_PROC OCCUR ERROR !');
        NULL;

    END;
  */
  PROCEDURE AIA_AGT_COMPENSATION_PROC IS
  BEGIN

    DELETE FROM AIA_AGT_COMPENSATION T
     WHERE T.CALENDARNAME = V_CALENDARNAME
       AND T.PERIODNAME = V_PERIODNAME;

    INSERT INTO AIA_AGT_COMPENSATION
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       REGION,
       --ZONE,
       --BRANCH,
       AGENT_NAME,
       STATUS,
       AGENT_CODE,
       --RANK,
       --UNIT_CODE,
       --AGENCY_NAME,
       AGENT_CONTRACT_DATE --,
       --UM_APPOINTMENT_DATE,
       --DM_APPOINTMENT_DATE,
       --UM_NAME,
       --UM_CODE,
       --DM_NAME,
       --DM_CODE
       )
      SELECT PAD.PAKEY,
             PAD.EFFECTIVESTARTDATE,
             PAD.EFFECTIVEENDDATE,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             PAD.POSITIONSEQ,
             PAD.MANAGERSEQ,
             PAD.POSITIONNAME,
             PAD.POSITIONTITLE,
             PAD.PARTICIPANTGENERICATTRIBUTE4, --REGIN
             PAD.PREFIX || PAD.FIRSTNAME || PAD.MIDDLENAME || PAD.LASTNAME ||
             PAD.SUFFIX AGENT_NAME,
             PROD.PRODUCERSTATUS,
             PAD.PARTICIPANTID,
             PAD.HIREDATE
        FROM PADIMENSION PAD, PRODUCERDIMENSION PROD
       WHERE PAD.PRODUCERKEY = PROD.PRODUCERKEY
         AND PAD.REMOVEDATE = C_REMOVEDATE
         AND PROD.REMOVEDATE = C_REMOVEDATE
            /**************************/
            --     AND PAD.POSITIONNAME IN ('39391', '39333', '33628', '34309', '47300','35790')

            /**************************/
         AND PAD.POSITIONTITLE IN
             ('Tied Agency-Agent', 'Tied Agency-DM', 'Tied Agency-UM')
         AND V_PERIODENDDATE - 1 BETWEEN PAD.EFFECTIVESTARTDATE AND
             PAD.EFFECTIVEENDDATE - 1;

    ------Miscellaneous Benefit Payment
    INSERT INTO AIA_AGT_COMPENSATION_MISC
      (PAKEY,
       EFFECTIVESTARTDATE,
       EFFECTIVEENDDATE,
       PERIODKEY,
       CALENDARNAME,
       PERIODNAME,
       PERIODSTARTDATE,
       PERIODENDDATE,
       POSITIONSEQ,
       MANAGERSEQ,
       POSITIONNAME,
       POSITIONTITLE,
       DESCRIPTION,
       TOTAL_PREMIUM,
       AMOUNT)
      (SELECT AAC.PAKEY,
              AAC.EFFECTIVESTARTDATE,
              AAC.EFFECTIVEENDDATE,
              AAC.PERIODKEY,
              AAC.CALENDARNAME,
              AAC.PERIODNAME,
              AAC.PERIODSTARTDATE,
              AAC.PERIODENDDATE,
              AAC.POSITIONSEQ,
              AAC.MANAGERSEQ,
              AAC.POSITIONNAME,
              AAC.POSITIONTITLE,
              TXDT.COMMENTS,
              0,
              TXF.VALUE
         FROM TRANSACTIONFACT      TXF,
              TRANSACTIONDETAIL    TXDT,
              TRANSACTIONDIMENSION TXD,
              CREDITFACT           CRDF,
              AIA_AGT_COMPENSATION AAC
        WHERE TXF.TRANSACTIONDETAILKEY = TXDT.TRANSACTIONDETAILKEY
          AND TXF.TRANSACTIONKEY = TXD.TRANSACTIONKEY
          AND CRDF.TRANSACTIONFACTKEY = TXF.TRANSACTIONFACTKEY
          AND TXD.ORIGINID = 'manual'
          AND CRDF.PERIODKEY = V_PERIODKEY
          AND CRDF.PAKEY = AAC.PAKEY
          AND AAC.PERIODKEY = V_PERIODKEY);

    ---------update Agency UM DM

    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.UNIT_CODE, AAC.AGENCY_NAME) =
           (SELECT PAD2.PARTICIPANTID,
                   PAD2.PREFIX || PAD2.FIRSTNAME || PAD2.MIDDLENAME || PAD2.LASTNAME ||
                   PAD2.SUFFIX
              FROM PADIMENSION PAD1, PAROLL PAR, PADIMENSION PAD2
             WHERE PAD1.POSITIONSEQ = AAC.MANAGERSEQ
               AND PAD1.REMOVEDATE = C_REMOVEDATE
               AND PAD1.EFFECTIVESTARTDATE < AAC.EFFECTIVEENDDATE
               AND PAD1.EFFECTIVEENDDATE > AAC.EFFECTIVESTARTDATE
               AND PAR.REMOVEDATE = C_REMOVEDATE
               AND PAR.EFFECTIVESTARTDATE < AAC.EFFECTIVEENDDATE
               AND PAR.EFFECTIVEENDDATE > AAC.EFFECTIVESTARTDATE
               AND PAR.ROLLTYPE = 'Assigned_Roll'
               AND PAR.FROMPAKEY = PAD1.PAKEY
               AND PAR.TOPAKEY = PAD2.PAKEY
               AND PAD2.REMOVEDATE = C_REMOVEDATE
               AND ROWNUM = 1),
           (AAC.UM_CODE, AAC.UM_NAME, AAC.UM_APPOINTMENT_DATE) =
           (SELECT PAD1.PARTICIPANTID,
                   PAD1.PREFIX || PAD1.FIRSTNAME || PAD1.MIDDLENAME || PAD1.LASTNAME ||
                   PAD1.SUFFIX,
                   PAD1.HIREDATE
              FROM PADIMENSION PAD1
             WHERE PAD1.POSITIONSEQ = AAC.MANAGERSEQ
               AND PAD1.REMOVEDATE = C_REMOVEDATE
               AND PAD1.EFFECTIVESTARTDATE < AAC.EFFECTIVEENDDATE
               AND PAD1.EFFECTIVEENDDATE > AAC.EFFECTIVESTARTDATE
               AND PAD1.POSITIONTITLE = 'Tied Agency-UM'
               AND ROWNUM = 1),
           (AAC.DM_CODE, AAC.DM_NAME, AAC.DM_APPOINTMENT_DATE) =
           (SELECT PAD1.PARTICIPANTID,
                   PAD1.PREFIX || PAD1.FIRSTNAME || PAD1.MIDDLENAME || PAD1.LASTNAME ||
                   PAD1.SUFFIX,
                   PAD1.HIREDATE
              FROM PADIMENSION PAD1
             WHERE PAD1.POSITIONSEQ = AAC.MANAGERSEQ
               AND PAD1.REMOVEDATE = C_REMOVEDATE
               AND PAD1.EFFECTIVESTARTDATE < AAC.EFFECTIVEENDDATE
               AND PAD1.EFFECTIVEENDDATE > AAC.EFFECTIVESTARTDATE
               AND PAD1.POSITIONTITLE = 'Tied Agency-DM'
               AND ROWNUM = 1
            UNION
            SELECT PAD1.PARTICIPANTID,
                   PAD1.PREFIX || PAD1.FIRSTNAME || PAD1.MIDDLENAME || PAD1.LASTNAME ||
                   PAD1.SUFFIX,
                   PAD1.HIREDATE
              FROM PADIMENSION PAD1, PADIMENSION PAD
             WHERE PAD1.POSITIONSEQ = PAD.MANAGERSEQ
               AND PAD1.REMOVEDATE = C_REMOVEDATE
               AND PAD1.EFFECTIVESTARTDATE < AAC.EFFECTIVEENDDATE
               AND PAD1.EFFECTIVEENDDATE > AAC.EFFECTIVESTARTDATE
               AND PAD1.POSITIONTITLE = 'Tied Agency-DM'
               AND PAD.POSITIONSEQ = AAC.MANAGERSEQ
               AND PAD.REMOVEDATE = C_REMOVEDATE
               AND PAD.EFFECTIVESTARTDATE < AAC.EFFECTIVEENDDATE
               AND PAD.EFFECTIVEENDDATE > AAC.EFFECTIVESTARTDATE
               AND PAD.POSITIONTITLE = 'Tied Agency-UM'
               AND ROWNUM = 1)

     WHERE AAC.POSITIONTITLE = 'Tied Agency-Agent'
       AND AAC.PERIODKEY = V_PERIODKEY;

    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.UNIT_CODE, AAC.AGENCY_NAME) =
           (SELECT PAD2.PARTICIPANTID,
                   PAD2.PREFIX || PAD2.FIRSTNAME || PAD2.MIDDLENAME || PAD2.LASTNAME ||
                   PAD2.SUFFIX
              FROM PAROLL PAR, PADIMENSION PAD2
             WHERE PAR.REMOVEDATE = C_REMOVEDATE
               AND PAR.EFFECTIVESTARTDATE < AAC.EFFECTIVEENDDATE
               AND PAR.EFFECTIVEENDDATE > AAC.EFFECTIVESTARTDATE
               AND PAR.ROLLTYPE = 'Assigned_Roll'
               AND PAR.FROMPAKEY = AAC.PAKEY
               AND PAR.TOPAKEY = PAD2.PAKEY
               AND PAD2.REMOVEDATE = C_REMOVEDATE
               AND ROWNUM = 1),
           (AAC.UM_CODE, AAC.UM_NAME, AAC.UM_APPOINTMENT_DATE) =
           (SELECT AAC.AGENT_CODE, AAC.AGENT_NAME, AAC.AGENT_CONTRACT_DATE FROM DUAL),
           (AAC.DM_CODE, AAC.DM_NAME, AAC.DM_APPOINTMENT_DATE) =
           (SELECT PAD1.PARTICIPANTID,
                   PAD1.PREFIX || PAD1.FIRSTNAME || PAD1.MIDDLENAME || PAD1.LASTNAME ||
                   PAD1.SUFFIX,
                   PAD1.HIREDATE
              FROM PADIMENSION PAD1
             WHERE PAD1.POSITIONSEQ = AAC.MANAGERSEQ
               AND PAD1.REMOVEDATE = C_REMOVEDATE
               AND PAD1.EFFECTIVESTARTDATE < AAC.EFFECTIVEENDDATE
               AND PAD1.EFFECTIVEENDDATE > AAC.EFFECTIVESTARTDATE
               AND PAD1.POSITIONTITLE = 'Tied Agency-DM'
               AND AAC.POSITIONTITLE = 'Tied Agency-UM'
               AND ROWNUM = 1
            UNION
            SELECT AAC.AGENT_CODE, AAC.AGENT_NAME, AAC.AGENT_CONTRACT_DATE
              FROM DUAL
             WHERE AAC.POSITIONTITLE = 'Tied Agency-DM')

     WHERE AAC.POSITIONTITLE != 'Tied Agency-Agent'
       AND AAC.PERIODKEY = V_PERIODKEY;

    --------update Rank Report To
    UPDATE AIA_AGT_COMPENSATION AAC
       SET AAC.RANK =
           (SELECT CASE
                     WHEN AAC.POSITIONTITLE = 'Tied Agency-DM' THEN
                      NULL
                     ELSE
                      PAD.PARTICIPANTID
                   END
              FROM PADIMENSION PAD
             WHERE PAD.POSITIONSEQ = AAC.MANAGERSEQ
               AND LEAST(V_PERIODENDDATE, AAC.EFFECTIVEENDDATE) - 1 BETWEEN
                   PAD.EFFECTIVESTARTDATE AND PAD.EFFECTIVEENDDATE - 1
               AND PAD.REMOVEDATE = C_REMOVEDATE
               AND ROWNUM = 1)
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    --------update Persistency and Compensation

    --------update Compensation Regular Premium
    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.LIFE_PSON_1ST_YEAR_RP,
            AAC.LIFE_UNIT_1ST_YEAR_RP,
            AAC.LIFE_GRP_1ST_YEAR_RP,
            AAC.TAKAFUL_PSON_1ST_YEAR_RP,
            AAC.TAKAFUL_UNIT_1ST_YEAR_RP,
            AAC.TAKAFUL_GRP_1ST_YEAR_RP,
            AAC.LIFE_PSON_2ND_YEAR_RP,
            AAC.LIFE_UNIT_2ND_YEAR_RP,
            AAC.LIFE_GRP_2ND_YEAR_RP,
            AAC.TAKAFUL_PSON_2ND_YEAR_RP,
            AAC.TAKAFUL_UNIT_2ND_YEAR_RP,
            AAC.TAKAFUL_GRP_2ND_YEAR_RP,
            AAC.LIFE_PSON_3RD_YEAR_RP,
            AAC.LIFE_UNIT_3RD_YEAR_RP,
            AAC.LIFE_GRP_3RD_YEAR_RP,
            AAC.TAKAFUL_PSON_3RD_YEAR_RP,
            AAC.TAKAFUL_UNIT_3RD_YEAR_RP,
            AAC.TAKAFUL_GRP_3RD_YEAR_RP,
            AAC.LIFE_PSON_4TH_YEAR_RP,
            AAC.LIFE_UNIT_4TH_YEAR_RP,
            AAC.LIFE_GRP_4TH_YEAR_RP,
            AAC.TAKAFUL_PSON_4TH_YEAR_RP,
            AAC.TAKAFUL_UNIT_4TH_YEAR_RP,
            AAC.TAKAFUL_GRP_4TH_YEAR_RP,
            AAC.LIFE_PSON_5TH_YEAR_RP,
            AAC.LIFE_UNIT_5TH_YEAR_RP,
            AAC.LIFE_GRP_5TH_YEAR_RP,
            AAC.TAKAFUL_PSON_5TH_YEAR_RP,
            AAC.TAKAFUL_UNIT_5TH_YEAR_RP,
            AAC.TAKAFUL_GRP_5TH_YEAR_RP,
            AAC.LIFE_PSON_6TH_YEAR_RP,
            AAC.LIFE_UNIT_6TH_YEAR_RP,
            AAC.LIFE_GRP_6TH_YEAR_RP,
            AAC.TAKAFUL_PSON_6TH_YEAR_RP,
            AAC.TAKAFUL_UNIT_6TH_YEAR_RP,
            AAC.TAKAFUL_GRP_6TH_YEAR_RP,
            AAC.LIFE_PSON_7_20TH_YEAR_RP,
            AAC.LIFE_UNIT_7_20TH_YEAR_RP,
            AAC.LIFE_GRP_7_20TH_YEAR_RP,
            AAC.TAKAFUL_PSON_7_20TH_YEAR_RP,
            AAC.TAKAFUL_UNIT_7_20TH_YEAR_RP,
            AAC.TAKAFUL_GRP_7_20TH_YEAR_RP) =
           (SELECT NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 1 AND
                                  CRDD.CREDITTYPE = 'First Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 1 AND
                                  CRDD.CREDITTYPE = 'First Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 1 AND
                                  (CRDD.CREDITTYPE = 'First Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'First Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 1 AND
                                  CRDD.CREDITTYPE = 'First Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 1 AND
                                  CRDD.CREDITTYPE = 'First Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 1 AND
                                  (CRDD.CREDITTYPE = 'First Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'First Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 2 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 2 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 2 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 2 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 2 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 2 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),

                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 3 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 3 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 3 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 3 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 3 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 3 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),

                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 4 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 4 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 4 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 4 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 4 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 4 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),

                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 5 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 5 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 5 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 5 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 5 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 5 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),

                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 6 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 6 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 6 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 6 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 6 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 = 6 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),

                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 >= 7 AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 <= 20 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 >= 7 AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 <= 20 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 >= 7 AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 <= 20 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 >= 7 AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 <= 20 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 >= 7 AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 <= 20 AND
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums DO' THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 >= 7 AND
                                  TXDT.TRANSACTIONGENERICNUMBER1 <= 20 AND
                                  (CRDD.CREDITTYPE = 'Renewal Year Premiums DO' OR
                                  CRDD.CREDITTYPE = 'Renewal Year Premiums IO') THEN
                              TXF.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM TRANSACTIONFACT      TXF,
                   TRANSACTIONDETAIL    TXDT,
                   TRANSACTIONDIMENSION TXD,
                   CREDITFACT           CRDF,
                   CREDITDETAIL         CRDT,
                   CREDITDIMENSION      CRDD,
                   CREDITRULEDIMENSION  CRDR
             WHERE CRDF.TRANSACTIONFACTKEY = TXF.TRANSACTIONFACTKEY
               AND CRDF.CREDITDETAILKEY = CRDT.CREDITDETAILKEY
               AND CRDF.CREDITRULEKEY = CRDR.CREDITRULEKEY
               AND CRDF.CREDITKEY = CRDD.CREDITKEY
               AND TXF.TRANSACTIONDETAILKEY = TXDT.TRANSACTIONDETAILKEY
               AND TXF.TRANSACTIONKEY = TXD.TRANSACTIONKEY
                  ------
               AND CRDF.PERIODKEY = V_PERIODKEY
               AND TXDT.TRANSACTIONGENERICATTRIBUTE3 = 'Regular Premium'
               AND CRDF.PAKEY = AAC.PAKEY)
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    --------Direct Overriding
    --------Indirect Overriding
    --------Parallel Overriding
    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.DIRECT_OR_TTL_PREM, AAC.INDIRECT_OR_TTL_PREM, AAC.PARALLEL_OR_TTL_PREM) =
           (SELECT NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums DO', 'Renewal Year Premiums DO') THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums IO', 'Renewal Year Premiums IO') THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums PO', 'Renewal Year Premiums PO') THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CREDITFACT          CRDF,
                   CREDITDETAIL        CRDT,
                   CREDITDIMENSION     CRDD,
                   CREDITRULEDIMENSION CRDR
             WHERE CRDF.CREDITDETAILKEY = CRDT.CREDITDETAILKEY
               AND CRDF.CREDITKEY = CRDD.CREDITKEY
               AND CRDF.CREDITRULEKEY = CRDR.CREDITRULEKEY
                  ------
               AND CRDF.PERIODKEY = V_PERIODKEY
               AND CRDF.PAKEY = AAC.PAKEY)
     WHERE AAC.PERIODKEY = V_PERIODKEY;
    ------update other channel DO/IO/PO
    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.GI_DIRECT_OR_TTL_PREM,
            AAC.GI_INDIRECT_OR_TTL_PREM,
            AAC.EB_DIRECT_OR_TTL_PREM,
            AAC.EB_INDIRECT_OR_TTL_PREM,
            AAC.MTAGE_DIRECT_OR_TTL_PREM,
            AAC.MTAGE_INDIRECT_OR_TTL_PREM,
            AAC.TAKAFUL_DIRECT_OR_TTL_PREM,
            AAC.TAKAFUL_INDIRECT_OR_TTL_PREM,
            AAC.TAKAFUL_PARALLEL_OR_TTL_PREM,
            AAC.PRS_DIRECT_OR_TTL_PREM,
            AAC.PRS_INDIRECT_OR_TTL_PREM) =
           (SELECT NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums DO', 'Renewal Year Premiums DO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'General Insurance' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums IO', 'Renewal Year Premiums IO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'General Insurance' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums DO', 'Renewal Year Premiums DO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Employee Benefits' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums IO', 'Renewal Year Premiums IO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Employee Benefits' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums DO', 'Renewal Year Premiums DO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Mortgage' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums IO', 'Renewal Year Premiums IO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Mortgage' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),

                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums DO', 'Renewal Year Premiums DO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums IO', 'Renewal Year Premiums IO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums PO', 'Renewal Year Premiums PO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'Takaful' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums DO', 'Renewal Year Premiums DO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'PRS' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDD.CREDITTYPE IN
                                  ('First Year Premiums IO', 'Renewal Year Premiums IO') AND
                                  TXDT.TRANSACTIONGENERICATTRIBUTE4 = 'PRS' THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM TRANSACTIONFACT      TXF,
                   TRANSACTIONDETAIL    TXDT,
                   TRANSACTIONDIMENSION TXD,
                   CREDITFACT           CRDF,
                   CREDITDETAIL         CRDT,
                   CREDITDIMENSION      CRDD,
                   CREDITRULEDIMENSION  CRDR
             WHERE CRDF.TRANSACTIONFACTKEY = TXF.TRANSACTIONFACTKEY
               AND CRDF.CREDITDETAILKEY = CRDT.CREDITDETAILKEY
               AND CRDF.CREDITRULEKEY = CRDR.CREDITRULEKEY
               AND CRDF.CREDITKEY = CRDD.CREDITKEY
               AND TXF.TRANSACTIONDETAILKEY = TXDT.TRANSACTIONDETAILKEY
               AND TXF.TRANSACTIONKEY = TXD.TRANSACTIONKEY
                  ------
               AND CRDF.PERIODKEY = V_PERIODKEY
               AND CRDF.PAKEY = AAC.PAKEY)
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.DIRECT_OR_AMOUNT,
            AAC.INDIRECT_OR_AMOUNT,
            AAC.PARALLEL_OR_AMOUNT,
            ------other channel Amount
            AAC.GI_DIRECT_OR_AMOUNT,
            AAC.GI_INDIRECT_OR_AMOUNT,
            AAC.EB_DIRECT_OR_AMOUNT,
            AAC.EB_INDIRECT_OR_AMOUNT,
            AAC.MTAGE_DIRECT_OR_AMOUNT,
            AAC.MTAGE_INDIRECT_OR_AMOUNT,
            AAC.TAKAFUL_DIRECT_OR_AMOUNT,
            AAC.TAKAFUL_INDIRECT_OR_AMOUNT,
            AAC.TAKAFUL_PARALLEL_OR_AMOUNT,
            AAC.PRS_DIRECT_OR_AMOUNT,
            AAC.PRS_INDIRECT_OR_AMOUNT) =
           (SELECT NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Direct_Override_Tied_Agency' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Indirect_Override_Tied_Agency' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Parallel_Override_Tied_Agency' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   ------other channel Amount
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Direct_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'General Insurance' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Indirect_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'General Insurance' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Direct_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'Employee Benefits' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Indirect_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'Employee Benefits' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Direct_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'Mortgage' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Indirect_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'Mortgage' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Direct_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'Takaful' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Indirect_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'Takaful' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Parallel_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'Takaful' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Direct_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'PRS' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN DEPD.DEPOSITNAME = 'DP_Indirect_Override_Tied_Agency' AND
                                  DEPD.EARNINGCODEID = 'PRS' THEN
                              DEPF.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM DEPOSITFACT DEPF, DEPOSITDETAIL DEPT, DEPOSITDIMENSION DEPD
             WHERE DEPF.DEPOSITDETAILKEY = DEPT.DEPOSITDETAILKEY
               AND DEPF.DEPOSITKEY = DEPD.DEPOSITKEY
                  ------
               AND DEPF.PERIODKEY = V_PERIODKEY
               AND DEPF.PAKEY = AAC.PAKEY)
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    --------update Persistency  ANP
    UPDATE AIA_AGT_COMPENSATION AAC
       SET ( ------Persistency
            AAC.PSON_Y1_BCP_BNM_PSIST,
            AAC.PSON_Y1_BAP_BNM_PSIST,
            --AAC.PSON_Y1_BR_BNM_PSIST,
            AAC.PSON_Y2_BCP_BNM_PSIST,
            AAC.PSON_Y2_BAP_BNM_PSIST,
            --AAC.PSON_Y2_BR_BNM_PSIST,
            AAC.UNIT_Y1_BCP_BNM_PSIST,
            AAC.UNIT_Y1_BAP_BNM_PSIST,
            --AAC.UNIT_Y1_BR_BNM_PSIST,
            AAC.UNIT_Y2_BCP_BNM_PSIST,
            AAC.UNIT_Y2_BAP_BNM_PSIST,
            --AAC.UNIT_Y2_BR_BNM_PSIST,
            AAC.GRP_Y1_BCP_BNM_PSIST,
            AAC.GRP_Y1_BAP_BNM_PSIST,
            --AAC.GRP_Y1_BR_BNM_PSIST,
            AAC.GRP_Y2_BCP_BNM_PSIST,
            AAC.GRP_Y2_BAP_BNM_PSIST,
            --AAC.GRP_Y2_BR_BNM_PSIST,
            AAC.PSON_Y0_BCP_DGI_PSIST,
            AAC.PSON_Y0_BAP_DGI_PSIST,
            --AAC.PSON_Y0_BR_DGI_PSIST,
            AAC.PSON_Y1_BCP_DGI_PSIST,
            AAC.PSON_Y1_BAP_DGI_PSIST,
            --AAC.PSON_Y1_BR_DGI_PSIST,
            AAC.PSON_Y2_BCP_DGI_PSIST,
            AAC.PSON_Y2_BAP_DGI_PSIST,
            --AAC.PSON_Y2_BR_DGI_PSIST,
            AAC.UNIT_Y1_BCP_DGI_PSIST,
            AAC.UNIT_Y1_BAP_DGI_PSIST,
            --AAC.UNIT_Y1_BR_DGI_PSIST,
            AAC.UNIT_Y2_BCP_DGI_PSIST,
            AAC.UNIT_Y2_BAP_DGI_PSIST,
            --AAC.UNIT_Y2_BR_DGI_PSIST,
            AAC.GRP_Y1_BCP_DGI_PSIST,
            AAC.GRP_Y1_BAP_DGI_PSIST,
            --AAC.GRP_Y1_BR_DGI_PSIST,
            AAC.GRP_Y2_BCP_DGI_PSIST,
            AAC.GRP_Y2_BAP_DGI_PSIST,
            --AAC.GRP_Y2_BR_DGI_PSIST,

            ------ANP
            /*AAC.LIFE_PSON_COMPENSATION_ANP,
            AAC.LIFE_UNIT_COMPENSATION_ANP,
            AAC.LIFE_GRP_COMPENSATION_ANP,
            AAC.TAKAFUL_PSON_COMPENSATION_ANP,
            AAC.TAKAFUL_UNIT_COMPENSATION_ANP,
            AAC.TAKAFUL_GRP_COMPENSATION_ANP,*/
            --AAC.TOTAL_PSON_COMPENSATION_ANP,
            --AAC.TOTAL_UNIT_COMPENSATION_ANP,
            --AAC.TOTAL_GRP_COMPENSATION_ANP

            ------Benefits Payout
            AAC.APB_DGI_1YEAR_TTL_PREM,
            AAC.APB_DGI_2YEAR_TTL_PREM,
            AAC.YEAR1_APB_TOTAL_PREMIUM,
            AAC.YEAR2_APB_TTL_PREM,
            AAC.YEAR3_APB_TTL_PREM,
            AAC.P1_ACB_TTL_PREM,
            --AAC.INTRDU_BONUS_TTL_PREM,
            AAC.NEW_UM_SUP_P5_TTL_PREM,
            AAC.MPB_TTL_PREM,
            AAC.MIPB_TTL_PREM,
            AAC.MIPF_TTL_PREM,
            AAC.PREMIER_AM_BB_P2P1_TTL_PREM --,
            --AAC.BREAKAWAY_BENEFIT_TTL_PREM
            ) =
           (SELECT
            ---1---personal
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_Second_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_Second_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             ---1---unit
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             ---1---group
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             ---2---personal
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_DGI_Current_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_DGI_Current_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_DGI_Second_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_DGI_Second_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             ---2---unit
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             ---2---group
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Expected_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_BNM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             /*------ANP
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'SM_Compensation_Life_ANP' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'SM_Compensation_Life_ANP' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'SM_Compensation_Life_ANP' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'SM_Compensation_Takaful_ANP' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'SM_Compensation_Takaful_ANP' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'SM_Compensation_Takaful_ANP' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),*/

             ------Benefits Payout
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_DGI_First_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_DGI_Second_Year_Received_Premium' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_FY_Personal_Sales' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_RY2_Personal_Sales' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_RY3_Personal_Sales' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'SM_FY_RY2' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             ------
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_FY_Personal_Sales' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_Manager_Sales' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_Manager_Indirect_Sales' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'PM_Manager_Indirect_Sales' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0),
             NVL(SUM(CASE
                       WHEN MEAD.MEASUREMENTNAME = 'SM_FY_RY2' THEN
                        MEAF.VALUE
                       ELSE
                        0
                     END),
                 0)
            ------

              FROM MEASUREMENTFACT      MEAF,
                   MEASUREMENTDETAIL    MEADT,
                   MEASUREMENTDIMENSION MEAD
             WHERE MEAF.MEASUREMENTDETAILKEY = MEADT.MEASUREMENTDETAILKEY
               AND MEAF.MEASUREMENTKEY = MEAD.MEASUREMENTKEY
                  ------
               AND MEAF.PERIODKEY = V_PERIODKEY
               AND MEAF.PAKEY = AAC.PAKEY)
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    --------update ANP
    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.LIFE_PSON_COMPENSATION_ANP,
            AAC.TAKAFUL_PSON_COMPENSATION_ANP,
            AAC.TOTAL_PSON_COMPENSATION_ANP,
            AAC.LIFE_UNIT_COMPENSATION_ANP,
            AAC.TAKAFUL_UNIT_COMPENSATION_ANP,
            AAC.TOTAL_UNIT_COMPENSATION_ANP,
            AAC.LIFE_GRP_COMPENSATION_ANP,
            AAC.TAKAFUL_GRP_COMPENSATION_ANP,
            AAC.TOTAL_GRP_COMPENSATION_ANP) =
           /*
           C_EARNING_CODE(601) := 'ANP';
           C_EARNING_CODE(602) := 'ANP Unit';
           C_EARNING_CODE(603) := 'ANP Group';

           C_EARNING_CODE(101) := 'LIFE';
           C_EARNING_CODE(102) := 'TAKAFUL';

           */

           (SELECT NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(601) AND
                                  TXD.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(601) AND
                                  TXD.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(102) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(601) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(602) AND
                                  TXD.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(602) AND
                                  TXD.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(102) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(602) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(603) AND
                                  TXD.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(101) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(603) AND
                                  TXD.TRANSACTIONGENERICATTRIBUTE4 = C_EARNING_CODE(102) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN CRDM.CREDITTYPE = C_EARNING_CODE(603) THEN
                              CRDF.VALUE
                             ELSE
                              0
                           END),
                       0)
              FROM CREDITFACT        CRDF,
                   CREDITDIMENSION   CRDM,
                   CREDITDETAIL      CRDD,
                   TRANSACTIONFACT   TXF,
                   TRANSACTIONDETAIL TXD,
                   AIA_PAYEE_INFOR   PAY
             WHERE CRDF.CREDITKEY = CRDM.CREDITKEY
               AND CRDF.CREDITDETAILKEY = CRDD.CREDITDETAILKEY
               AND CRDF.PERIODKEY = AAC.PERIODKEY
               AND CRDF.PAKEY = PAY.PAKEY
               AND PAY.PARTICIPANTID = AAC.AGENT_CODE
               AND CRDF.TRANSACTIONFACTKEY = TXF.TRANSACTIONFACTKEY
               AND TXF.TRANSACTIONDETAILKEY = TXD.TRANSACTIONDETAILKEY
               AND CRDM.CREDITTYPE IN
                   (C_EARNING_CODE(601), C_EARNING_CODE(602), C_EARNING_CODE(603))
               AND TXD.TRANSACTIONGENERICATTRIBUTE4 IN
                   (C_EARNING_CODE(101), C_EARNING_CODE(102)))
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    --------update Benefits Payout:(Percentage and Amount)
    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.APB_DGI_1YEAR_PCNT,
            AAC.APB_DGI_1YEAR_AMOUNT,
            AAC.APB_DGI_2YEAR_PCNT,
            AAC.APB_DGI_2YEAR_AMOUNT,
            AAC.YEAR1_APB_PCNT,
            AAC.YEAR1_APB_AMOUNT,
            AAC.YEAR2_APB_PCNT,
            AAC.YEAR2_APB_AMOUNT,
            AAC.YEAR3_APB_PCNT,
            AAC.YEAR3_APB_AMOUNT,
            AAC.P1_ACB_PCNT,
            AAC.P1_ACB_AMOUNT,
            AAC.INTRDU_BONUS_PCNT,
            AAC.INTRDU_BONUS_AMOUNT,
            AAC.NEW_UM_SUP_P5_PCNT,
            AAC.NEW_UM_SUP_P5_AMOUNT,
            AAC.MPB_PCNT,
            AAC.MPB_AMOUNT,
            AAC.MIPB_PCNTS,
            AAC.MIPB_AMOUNT,
            AAC.MIPF_PCNT,
            AAC.MIPF_AMOUNT,
            AAC.PREMIER_AM_BB_P2P1_PCNTS,
            AAC.PREMIER_AM_BB_P2P1_AMOUNT,
            AAC.BREAKAWAY_BENEFIT_PCNT,
            AAC.BREAKAWAY_BENEFIT_AMOUNT) =
           (SELECT 0.05 * 100, --APB_DGI_1YEAR_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_DGI_First_Year_Persistency_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   0.05 * 100, --APB_DGI_2YEAR_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_DGI_Second_Year_Persistency_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_FY_Agent_Production_Bonus' THEN
                              INCDT.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0) * 100, --YEAR1_APB_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_FY_Agent_Production_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_RY2_Agent_Production_Bonus' THEN
                              INCDT.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0) * 100, --YEAR2_APB_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_RY2_Agent_Production_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_RY3_Agent_Production_Bonus' THEN
                              INCDT.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0) * 100, --YEAR3_APB_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_RY3_Agent_Production_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_4Apps_Club_Bonus' THEN
                              INCDT.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0) * 100, --P1_ACB_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_4Apps_Club_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NULL, --INTRDU_BONUS_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_Introducer_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   0.05 * 100, --NEW_UM_SUP_P5_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_New_UM_Start_Up_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_Manager_Production_Bonus' THEN
                              INCDT.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0) * 100, --MPB_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_Manager_Production_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_Manager_Indirect_Production_Bonus' THEN
                              INCDT.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0) * 100, --MIPB_PCNTS
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_Manager_Indirect_Production_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_Manager_Indirect Provident_Fund' THEN
                              INCDT.GENERICNUMBER1
                             ELSE
                              0
                           END),
                       0) * 100, --MIPF_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_Manager_Indirect Provident_Fund' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   0.03 * 100, --PREMIER_AM_BB_P2P1_PCNTS
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_4Apps_Club_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NULL, --BREAKAWAY_BENEFIT_PCNT
                   NVL(SUM(CASE
                             WHEN INCD.INCENTIVENAME = 'IT_4Apps_Club_Bonus' THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0)

              FROM INCENTIVEFACT INCF, INCENTIVEDETAIL INCDT, INCENTIVEDIMENSION INCD
             WHERE INCF.INCENTIVEDETAILKEY = INCDT.INCENTIVEDETAILKEY
               AND INCF.INCENTIVEKEY = INCD.INCENTIVEKEY
                  ------
               AND INCF.PERIODKEY = V_PERIODKEY
               AND INCF.PAKEY = AAC.PAKEY)
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    --------update Benefit Payment History
    UPDATE AIA_AGT_COMPENSATION AAC
       SET (AAC.YEAR1_APB_QUARTER1,
            AAC.YEAR1_APB_QUARTER2,
            AAC.YEAR1_APB_QUARTER3,
            AAC.YEAR1_APB_QUARTER4) =
           (SELECT NVL(SUM(CASE
                             WHEN PERD.PERIODSTARTDATE <=
                                  ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), -1) AND
                                  PERD.PERIODENDDATE <=
                                  ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), 2) THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PERD.PERIODSTARTDATE <=
                                  ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), 2) AND
                                  PERD.PERIODENDDATE <=
                                  ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), 5) THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PERD.PERIODSTARTDATE <=
                                  ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), 5) AND
                                  PERD.PERIODENDDATE <=
                                  ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), 8) THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0),
                   NVL(SUM(CASE
                             WHEN PERD.PERIODSTARTDATE <=
                                  ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), 8) AND
                                  PERD.PERIODENDDATE <=
                                  ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), 11) THEN
                              INCF.EARNING
                             ELSE
                              0
                           END),
                       0)

              FROM INCENTIVEFACT      INCF,
                   INCENTIVEDETAIL    INCDT,
                   INCENTIVEDIMENSION INCD,
                   PERIODDIMENSION    PERD
             WHERE INCF.INCENTIVEDETAILKEY = INCDT.INCENTIVEDETAILKEY
               AND INCF.INCENTIVEKEY = INCD.INCENTIVEKEY
                  ------
               AND INCF.PAKEY = AAC.PAKEY
               AND PERD.PERIODSTARTDATE >=
                   ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), -1)
               AND PERD.PERIODENDDATE <=
                   ADD_MONTHS(TRUNC(ADD_MONTHS(V_PERIODSTARTDATE, 1), 'YEAR'), 11)
               AND PERD.CALENDARNAME = V_CALENDARNAME
               AND PERD.PERIODTYPE = V_PERIODTYPE
               AND PERD.REMOVEDATE = C_REMOVEDATE
               AND INCF.PERIODKEY = PERD.PERIODKEY
               AND INCD.INCENTIVENAME = 'IT_FY_Agent_Production_Bonus')
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    --------update Total Field
    UPDATE AIA_AGT_COMPENSATION AAC
       SET ( ------Regular Premium
            AAC.TOTAL_LIFE_PSON_RENEWAL_RP,
            AAC.TOTAL_LIFE_UNIT_RENEWAL_RP,
            AAC.TOTAL_LIFE_GRP_RENEWAL_RP,
            AAC.TOTAL_TAKAFUL_PSON_RENEWAL_RP,
            AAC.TOTAL_TAKAFUL_UNIT_RENEWAL_RP,
            AAC.TOTAL_TAKAFUL_GRP_RENEWAL_RP,
            AAC.TOTAL_LT_PSON_1ST_RP,
            AAC.TOTAL_LT_UNIT_1ST_RP,
            AAC.TOTAL_LT_GRP_1ST_RP,
            AAC.TOTAL_LT_PSON_2_20TH_RP,
            AAC.TOTAL_LT_UNIT_2_20TH_RP,
            AAC.TOTAL_LT_GRP_2_20TH_RP,
            AAC.TOTAL_LT_PSON_2ND_RP,
            AAC.TOTAL_LT_UNIT_2ND_RP,
            AAC.TOTAL_LT_GRP_2ND_RP,
            AAC.TOTAL_LT_PSON_3RD_RP,
            AAC.TOTAL_LT_UNIT_3RD_RP,
            AAC.TOTAL_LT_GRP_3RD_RP,
            AAC.TOTAL_LT_PSON_4TH_RP,
            AAC.TOTAL_LT_UNIT_4TH_RP,
            AAC.TOTAL_LT_GRP_4TH_RP,
            AAC.TOTAL_LT_PSON_5TH_RP,
            AAC.TOTAL_LT_UNIT_5TH_RP,
            AAC.TOTAL_LT_GRP_5TH_RP,
            AAC.TOTAL_LT_PSON_6TH_RP,
            AAC.TOTAL_LT_UNIT_6TH_RP,
            AAC.TOTAL_LT_GRP_6TH_RP,
            AAC.TOTAL_LT_PSON_7_20TH_RP,
            AAC.TOTAL_LT_UNIT_7_20TH_RP,
            AAC.TOTAL_LT_GRP_7_20TH_RP,
            ------ANP
            AAC.TOTAL_PSON_COMPENSATION_ANP,
            AAC.TOTAL_UNIT_COMPENSATION_ANP,
            AAC.TOTAL_GRP_COMPENSATION_ANP,
            ------Persistency
            AAC.PSON_Y1_BR_BNM_PSIST,
            AAC.PSON_Y2_BR_BNM_PSIST,
            AAC.UNIT_Y1_BR_BNM_PSIST,
            AAC.UNIT_Y2_BR_BNM_PSIST,
            AAC.GRP_Y1_BR_BNM_PSIST,
            AAC.GRP_Y2_BR_BNM_PSIST,
            AAC.PSON_Y0_BR_DGI_PSIST,
            AAC.PSON_Y1_BR_DGI_PSIST,
            AAC.PSON_Y2_BR_DGI_PSIST,
            AAC.UNIT_Y1_BR_DGI_PSIST,
            AAC.UNIT_Y2_BR_DGI_PSIST,
            AAC.GRP_Y1_BR_DGI_PSIST,
            AAC.GRP_Y2_BR_DGI_PSIST) =
           (SELECT ------Regular Premium
             (AAC.LIFE_PSON_2ND_YEAR_RP + AAC.LIFE_PSON_3RD_YEAR_RP +
             AAC.LIFE_PSON_4TH_YEAR_RP + AAC.LIFE_PSON_5TH_YEAR_RP +
             AAC.LIFE_PSON_6TH_YEAR_RP + AAC.LIFE_PSON_7_20TH_YEAR_RP),
             (AAC.LIFE_UNIT_2ND_YEAR_RP + AAC.LIFE_UNIT_3RD_YEAR_RP +
             AAC.LIFE_UNIT_4TH_YEAR_RP + AAC.LIFE_UNIT_5TH_YEAR_RP +
             AAC.LIFE_UNIT_6TH_YEAR_RP + AAC.LIFE_UNIT_7_20TH_YEAR_RP),
             (AAC.LIFE_GRP_2ND_YEAR_RP + AAC.LIFE_GRP_3RD_YEAR_RP +
             AAC.LIFE_GRP_4TH_YEAR_RP + AAC.LIFE_GRP_5TH_YEAR_RP +
             AAC.LIFE_GRP_6TH_YEAR_RP + AAC.LIFE_GRP_7_20TH_YEAR_RP),

             (AAC.TAKAFUL_PSON_2ND_YEAR_RP + AAC.TAKAFUL_PSON_3RD_YEAR_RP +
             AAC.TAKAFUL_PSON_4TH_YEAR_RP + AAC.TAKAFUL_PSON_5TH_YEAR_RP +
             AAC.TAKAFUL_PSON_6TH_YEAR_RP + AAC.TAKAFUL_PSON_7_20TH_YEAR_RP),
             (AAC.TAKAFUL_UNIT_2ND_YEAR_RP + AAC.TAKAFUL_UNIT_3RD_YEAR_RP +
             AAC.TAKAFUL_UNIT_4TH_YEAR_RP + AAC.TAKAFUL_UNIT_5TH_YEAR_RP +
             AAC.TAKAFUL_UNIT_6TH_YEAR_RP + AAC.TAKAFUL_UNIT_7_20TH_YEAR_RP),
             (AAC.TAKAFUL_GRP_2ND_YEAR_RP + AAC.TAKAFUL_GRP_3RD_YEAR_RP +
             AAC.TAKAFUL_GRP_4TH_YEAR_RP + AAC.TAKAFUL_GRP_5TH_YEAR_RP +
             AAC.TAKAFUL_GRP_6TH_YEAR_RP + AAC.TAKAFUL_GRP_7_20TH_YEAR_RP),

             (AAC.LIFE_PSON_1ST_YEAR_RP + AAC.TAKAFUL_PSON_1ST_YEAR_RP),
             (AAC.LIFE_UNIT_1ST_YEAR_RP + AAC.TAKAFUL_UNIT_1ST_YEAR_RP),
             (AAC.LIFE_GRP_1ST_YEAR_RP + AAC.TAKAFUL_GRP_1ST_YEAR_RP),

             (AAC.LIFE_PSON_2ND_YEAR_RP + AAC.TAKAFUL_PSON_2ND_YEAR_RP +
             AAC.LIFE_PSON_3RD_YEAR_RP + AAC.TAKAFUL_PSON_3RD_YEAR_RP +
             AAC.LIFE_PSON_4TH_YEAR_RP + AAC.TAKAFUL_PSON_4TH_YEAR_RP +
             AAC.LIFE_PSON_5TH_YEAR_RP + AAC.TAKAFUL_PSON_5TH_YEAR_RP +
             AAC.LIFE_PSON_6TH_YEAR_RP + AAC.TAKAFUL_PSON_6TH_YEAR_RP +
             AAC.LIFE_PSON_7_20TH_YEAR_RP + AAC.TAKAFUL_PSON_7_20TH_YEAR_RP),

             (AAC.LIFE_UNIT_2ND_YEAR_RP + AAC.TAKAFUL_UNIT_2ND_YEAR_RP +
             AAC.LIFE_UNIT_3RD_YEAR_RP + AAC.TAKAFUL_UNIT_3RD_YEAR_RP +
             AAC.LIFE_UNIT_4TH_YEAR_RP + AAC.TAKAFUL_UNIT_4TH_YEAR_RP +
             AAC.LIFE_UNIT_5TH_YEAR_RP + AAC.TAKAFUL_UNIT_5TH_YEAR_RP +
             AAC.LIFE_UNIT_6TH_YEAR_RP + AAC.TAKAFUL_UNIT_6TH_YEAR_RP +
             AAC.LIFE_UNIT_7_20TH_YEAR_RP + AAC.TAKAFUL_UNIT_7_20TH_YEAR_RP),

             (AAC.LIFE_GRP_2ND_YEAR_RP + AAC.TAKAFUL_GRP_2ND_YEAR_RP +
             AAC.LIFE_GRP_3RD_YEAR_RP + AAC.TAKAFUL_GRP_3RD_YEAR_RP +
             AAC.LIFE_GRP_4TH_YEAR_RP + AAC.TAKAFUL_GRP_4TH_YEAR_RP +
             AAC.LIFE_GRP_5TH_YEAR_RP + AAC.TAKAFUL_GRP_5TH_YEAR_RP +
             AAC.LIFE_GRP_6TH_YEAR_RP + AAC.TAKAFUL_GRP_6TH_YEAR_RP +
             AAC.LIFE_GRP_7_20TH_YEAR_RP + AAC.TAKAFUL_GRP_7_20TH_YEAR_RP),

             (AAC.LIFE_PSON_2ND_YEAR_RP + AAC.TAKAFUL_PSON_2ND_YEAR_RP),
             (AAC.LIFE_UNIT_2ND_YEAR_RP + AAC.TAKAFUL_UNIT_2ND_YEAR_RP),
             (AAC.LIFE_GRP_2ND_YEAR_RP + AAC.TAKAFUL_GRP_2ND_YEAR_RP),

             (AAC.LIFE_PSON_3RD_YEAR_RP + AAC.TAKAFUL_PSON_3RD_YEAR_RP),
             (AAC.LIFE_UNIT_3RD_YEAR_RP + AAC.TAKAFUL_UNIT_3RD_YEAR_RP),
             (AAC.LIFE_GRP_3RD_YEAR_RP + AAC.TAKAFUL_GRP_3RD_YEAR_RP),

             (AAC.LIFE_PSON_4TH_YEAR_RP + AAC.TAKAFUL_PSON_4TH_YEAR_RP),
             (AAC.LIFE_UNIT_4TH_YEAR_RP + AAC.TAKAFUL_UNIT_4TH_YEAR_RP),
             (AAC.LIFE_GRP_4TH_YEAR_RP + AAC.TAKAFUL_GRP_4TH_YEAR_RP),

             (AAC.LIFE_PSON_5TH_YEAR_RP + AAC.TAKAFUL_PSON_5TH_YEAR_RP),
             (AAC.LIFE_UNIT_5TH_YEAR_RP + AAC.TAKAFUL_UNIT_5TH_YEAR_RP),
             (AAC.LIFE_GRP_5TH_YEAR_RP + AAC.TAKAFUL_GRP_5TH_YEAR_RP),

             (AAC.LIFE_PSON_6TH_YEAR_RP + AAC.TAKAFUL_PSON_6TH_YEAR_RP),
             (AAC.LIFE_UNIT_6TH_YEAR_RP + AAC.TAKAFUL_UNIT_6TH_YEAR_RP),
             (AAC.LIFE_GRP_6TH_YEAR_RP + AAC.TAKAFUL_GRP_6TH_YEAR_RP),

             (AAC.LIFE_PSON_7_20TH_YEAR_RP + AAC.TAKAFUL_PSON_7_20TH_YEAR_RP),
             (AAC.LIFE_UNIT_7_20TH_YEAR_RP + AAC.TAKAFUL_UNIT_7_20TH_YEAR_RP),
             (AAC.LIFE_GRP_7_20TH_YEAR_RP + AAC.TAKAFUL_GRP_7_20TH_YEAR_RP),

             ------ANP
             (AAC.LIFE_PSON_COMPENSATION_ANP + AAC.TAKAFUL_PSON_COMPENSATION_ANP),
             (AAC.LIFE_UNIT_COMPENSATION_ANP + AAC.TAKAFUL_UNIT_COMPENSATION_ANP),
             (AAC.LIFE_GRP_COMPENSATION_ANP + AAC.TAKAFUL_GRP_COMPENSATION_ANP),

             ------Persistency
             DECODE(AAC.PSON_Y1_BAP_BNM_PSIST,
                    0,
                    NULL,
                    AAC.PSON_Y1_BCP_BNM_PSIST / AAC.PSON_Y1_BAP_BNM_PSIST * 100),
             DECODE(AAC.PSON_Y2_BAP_BNM_PSIST,
                    0,
                    NULL,
                    AAC.PSON_Y2_BCP_BNM_PSIST / AAC.PSON_Y2_BAP_BNM_PSIST * 100),
             DECODE(AAC.UNIT_Y1_BAP_BNM_PSIST,
                    0,
                    NULL,
                    AAC.UNIT_Y1_BCP_BNM_PSIST / AAC.UNIT_Y1_BAP_BNM_PSIST * 100),
             DECODE(AAC.UNIT_Y2_BAP_BNM_PSIST,
                    0,
                    NULL,
                    AAC.UNIT_Y2_BCP_BNM_PSIST / AAC.UNIT_Y2_BAP_BNM_PSIST * 100),
             DECODE(AAC.GRP_Y1_BAP_BNM_PSIST,
                    0,
                    NULL,
                    AAC.GRP_Y1_BCP_BNM_PSIST / AAC.GRP_Y1_BAP_BNM_PSIST * 100),
             DECODE(AAC.GRP_Y2_BAP_BNM_PSIST,
                    0,
                    NULL,
                    AAC.GRP_Y2_BCP_BNM_PSIST / AAC.GRP_Y2_BAP_BNM_PSIST * 100),
             DECODE(AAC.PSON_Y0_BAP_DGI_PSIST,
                    0,
                    NULL,
                    AAC.PSON_Y0_BCP_DGI_PSIST / AAC.PSON_Y0_BAP_DGI_PSIST * 100),
             DECODE(AAC.PSON_Y1_BAP_DGI_PSIST,
                    0,
                    NULL,
                    AAC.PSON_Y1_BCP_DGI_PSIST / AAC.PSON_Y1_BAP_DGI_PSIST * 100),
             DECODE(AAC.PSON_Y2_BAP_DGI_PSIST,
                    0,
                    NULL,
                    AAC.PSON_Y2_BCP_DGI_PSIST / AAC.PSON_Y2_BAP_DGI_PSIST * 100),
             DECODE(AAC.UNIT_Y1_BAP_DGI_PSIST,
                    0,
                    NULL,
                    AAC.UNIT_Y1_BCP_DGI_PSIST / AAC.UNIT_Y1_BAP_DGI_PSIST * 100),
             DECODE(AAC.UNIT_Y2_BAP_DGI_PSIST,
                    0,
                    NULL,
                    AAC.UNIT_Y2_BCP_DGI_PSIST / AAC.UNIT_Y2_BAP_DGI_PSIST * 100),
             DECODE(AAC.GRP_Y1_BAP_DGI_PSIST,
                    0,
                    NULL,
                    AAC.GRP_Y1_BCP_DGI_PSIST / AAC.GRP_Y1_BAP_DGI_PSIST * 100),
             DECODE(AAC.GRP_Y2_BAP_DGI_PSIST,
                    0,
                    NULL,
                    AAC.GRP_Y2_BCP_DGI_PSIST / AAC.GRP_Y2_BAP_DGI_PSIST * 100)

              FROM DUAL)
     WHERE AAC.PERIODKEY = V_PERIODKEY;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Compensation Error !');
      NULL;
  END;

--added by zhubin for PRS report on the condition that agent has no payment
  PROCEDURE GetManager(P_MANAGERSEQ IN NUMBER,
                       P_PERIODENDDATE IN DATE,
                       V_MANAGERNAME OUT VARCHAR2,
                       V_MANAGERCODE OUT VARCHAR2
                       )
    is
    C_REMOVEDATE DATE := TO_DATE('2200-1-1', 'YYYY-MM-DD');
  begin
    select posa.name,
           par.PREFIX || par.FIRSTNAME || par.MIDDLENAME|| par.LASTNAME || par.SUFFIX
    into
           V_MANAGERCODE,
           V_MANAGERNAME
   from cs_participant  par,
        cs_position     posa
   where par.payeeseq = posa.payeeseq
   and par.removedate = C_REMOVEDATE
   and posa.removedate = C_REMOVEDATE
   and par.effectivestartdate <= P_PERIODENDDATE - 1
   and par.effectiveenddate > P_PERIODENDDATE -1
   and posa.effectivestartdate <= P_PERIODENDDATE - 1
   and posa.effectiveenddate > P_PERIODENDDATE - 1
   and posa.ruleelementownerseq = P_MANAGERSEQ
   AND ROWNUM = 1;
  end GetManager;

  PROCEDURE GetAgency(P_AGENTCODE IN Varchar2,
                                      P_PERIODENDDATE IN DATE,
                                      V_AGENCYNAME OUT VARCHAR2,
                                      V_AGENCYCODE OUT VARCHAR2)

  is

   V_TITLE VARCHAR2(255);
   V_MANAGERSEQ NUMBER;
   V_FROM_DM NUMBER;
   -- V_AGENCYNAME VARCHAR2(255);
   -- V_AGENCYCODE VARCHAR2(255);
   C_REMOVEDATE DATE := TO_DATE('2200-1-1', 'YYYY-MM-DD');
  begin

    SELECT T.POSITIONTITLE INTO V_TITLE
           --T.MANAGERSEQ INTO V_MANAGERSEQ
    FROM AIA_PAYEE_INFOR T
    WHERE T.REMOVEDATE > SYSDATE
    AND T.EFFECTIVESTARTDATE <= P_PERIODENDDATE - 1
    AND T.EFFECTIVEENDDATE > P_PERIODENDDATE -1
    AND T.PARTICIPANTID = P_AGENTCODE;

    -- FIND THE FROM_DM FOR ALC
    IF V_TITLE = 'Tied Agency-ALC' THEN
      SELECT POSR.CHILDPOSITIONSEQ INTO V_FROM_DM
      FROM
             CS_POSITION POS,
             CS_POSITIONRELATION POSR,
             CS_POSITIONRELATIONTYPE POSRT
       WHERE POS.RULEELEMENTOWNERSEQ = POSR.PARENTPOSITIONSEQ
       AND   POSRT.DATATYPESEQ = POSR.POSITIONRELATIONTYPESEQ
       AND   POS.REMOVEDATE = C_REMOVEDATE
       AND   POSR.REMOVEDATE = C_REMOVEDATE
       AND   POSRT.REMOVEDATE = C_REMOVEDATE
       AND   POS.EFFECTIVESTARTDATE <= P_PERIODENDDATE - 1
       AND   POS.EFFECTIVEENDDATE > P_PERIODENDDATE - 1
       AND   POSR.EFFECTIVESTARTDATE <= P_PERIODENDDATE - 1
       AND   POSR.EFFECTIVEENDDATE > P_PERIODENDDATE - 1
       AND   POS.NAME = P_AGENTCODE
       AND   POSRT.NAME = 'ALC_Roll';
    END IF;

    IF V_TITLE LIKE '%Tied Agency%' THEN
    select posa.name ,
           par.PREFIX || par.FIRSTNAME || par.MIDDLENAME|| par.LASTNAME || par.SUFFIX
           INTO
                V_AGENCYCODE,
                V_AGENCYNAME
           from cs_participant par,
                cs_position    posa,
                aia_payee_infor aas
           where par.payeeseq = posa.payeeseq
           and par.removedate = C_REMOVEDATE
           and posa.removedate = C_REMOVEDATE
           and par.effectivestartdate <= P_PERIODENDDATE - 1
           and par.effectiveenddate > P_PERIODENDDATE - 1
           and posa.effectivestartdate <= P_PERIODENDDATE - 1
           and posa.effectiveenddate > P_PERIODENDDATE - 1
           and posa.ruleelementownerseq IN
           --query the postionseq of unit code
          (select max(cspr.childpositionseq)
           from cs_position  csp,
           cs_positionrelation cspr
           where cspr.parentpositionseq =
           csp.ruleelementownerseq
           and cspr.positionrelationtypeseq =
             (--query the Assigned_Roll relationSEQ
              select relt.datatypeseq
              from cs_positionrelationtype relt
              where relt.name ='Assigned_Roll'
              and relt.removedate = C_REMOVEDATE)
           and csp.removedate = C_REMOVEDATE
           and cspr.removedate =C_REMOVEDATE
           and csp.effectivestartdate <= P_PERIODENDDATE - 1
           and csp.effectiveenddate > P_PERIODENDDATE - 1
           and cspr.effectivestartdate <= P_PERIODENDDATE - 1
           and cspr.effectiveenddate > P_PERIODENDDATE - 1
           and csp.ruleelementownerseq =
             DECODE(AAS.POSITIONTITLE,
                    'Tied Agency-Agent',
                    AAS.MANAGERSEQ,
                    'Tied Agency-ALC',
                    V_FROM_DM,
                    AAS.POSITIONSEQ))
            and AAS.Removedate = C_REMOVEDATE
            --and AAS.Positiontitle like '%Tied Agency%'
            AND AAS.Participantid = P_AGENTCODE;
            --Result := V_AGENCYCODE||'#_#'||V_AGENCYNAME;
      END IF;

      IF V_TITLE IN('Broker-Agent',
                    'Broker-Leader',
                    'IFA-FA Leader',
                    'IFA-FAR')  THEN
        SELECT T.MANAGERSEQ INTO V_MANAGERSEQ
          FROM AIA_PAYEE_INFOR T
        WHERE T.PARTICIPANTID = P_AGENTCODE
        AND T.REMOVEDATE = C_REMOVEDATE
        AND T.EFFECTIVESTARTDATE <= P_PERIODENDDATE - 1
        AND T.EFFECTIVEENDDATE > P_PERIODENDDATE - 1;

        GetManager(V_MANAGERSEQ, P_PERIODENDDATE, V_AGENCYNAME, V_AGENCYCODE);
      END IF;

  end GetAgency;

  PROCEDURE AIA_PRS_PROC IS
    V_AGENCYCODE VARCHAR2(255);
    V_AGENCYNAME VARCHAR2(255);
    V_REPORT_TO VARCHAR2(255);
    V_MANAGERNAME VARCHAR2(255);
    V_MANAGERCODE VARCHAR2(255);
    V_RECORD_NO NUMBER;
    --V_MANAGERSEQ NUMBER;
    V_AGENT_RECORD AIA_PAYEE_INFOR%ROWTYPE;
  BEGIN
    --get the max record no. of stmt_total
    SELECT MAX(T.RECORDNO) INTO V_RECORD_NO
    FROM AIA_AGT_STMT_TOTAL T;

    -- find the agent who has prs but not has stmt
    For P_AGENT in (
      SELECT DISTINCT PAYEE_ID FROM AIA_OLD_AGT_STATEMENT_DTL OLD
      WHERE OLD.BUSINESS_LINE = 'PRS'
      AND OLD.COMPENSATION_DATE >= V_PERIODSTARTDATE
      AND OLD.COMPENSATION_DATE < V_PERIODENDDATE
      AND OLD.PAYEE_ID NOT IN (
        SELECT STMT.CODE FROM AIA_AGT_STMT_TOTAL STMT
        WHERE STMT.PERIODNAME = V_PERIODNAME)) LOOP
      V_RECORD_NO := V_RECORD_NO + 1;

      --STORE THE AGENT INFO IN THE V_AGENT_RECORD
      SELECT * INTO V_AGENT_RECORD
      FROM AIA_PAYEE_INFOR T
      WHERE T.PARTICIPANTID = P_AGENT.PAYEE_ID
      AND T.REMOVEDATE = C_REMOVEDATE
      AND T.EFFECTIVESTARTDATE <= V_PERIODENDDATE - 1
      AND T.EFFECTIVEENDDATE > V_PERIODENDDATE - 1;

      --GET THE AGENCY OF AGENT
      GetAgency(P_AGENT.PAYEE_ID, V_PERIODENDDATE, V_AGENCYNAME, V_AGENCYCODE);

      --GET THE MANAGER OF AGENT
      GetManager(P_AGENT.PAYEE_ID, V_PERIODENDDATE, V_MANAGERNAME, V_MANAGERCODE);

      IF V_AGENT_RECORD.POSITIONTITLE != 'Tied Agency-DM' THEN
        V_REPORT_TO := V_MANAGERCODE;
      END IF;
       
      --  DATA INTO AIA_AGENT_ID
      INSERT INTO AIA_AGENT_ID
        (RECORDNO,
         PERIODKEY,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         PRODUCERCODE,
         CREATE_DATE)
      SELECT V_RECORD_NO,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             P_AGENT.PAYEE_ID,
             SYSDATE
             FROM DUAL;

      -- INSERT INTO STMT
      INSERT INTO AIA_AGT_STMT
        (PAKEY,
         PERIODKEY,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         POSITIONSEQ,
         MANAGERSEQ,
         POSITIONNAME,
         POSITIONTITLE,
         RANK_REPORT_TO,
         AGENCY_CODE,
         AGENCY_NAME,
         STATUS,
         NAME,
         CODE,
         CREATE_DATE
         )
      SELECT V_AGENT_RECORD.PAKEY,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             V_AGENT_RECORD.POSITIONSEQ,
             V_AGENT_RECORD.MANAGERSEQ,
             V_AGENT_RECORD.POSITIONNAME,
             V_AGENT_RECORD.POSITIONTITLE,
             V_REPORT_TO,
             V_AGENCYCODE,
             V_AGENCYNAME,
             V_AGENT_RECORD.PRODUCERSTATUS,
             V_AGENT_RECORD.LASTNAME,
             V_AGENT_RECORD.POSITIONNAME,
             SYSDATE FROM DUAL;

      --insert stmt_total
      INSERT INTO AIA_AGT_STMT_TOTAL
        (RECORDNO,
         PAKEY,
         PERIODKEY,
         CALENDARNAME,
         PERIODNAME,
         PERIODSTARTDATE,
         PERIODENDDATE,
         POSITIONSEQ,
         MANAGERSEQ,
         POSITIONNAME,
         POSITIONTITLE,
         STATUS,
         NAME,
         CODE,
         FIRST_YEAR_CURR,
         RENEWAL_CURR,
         MISC_CURR,
         TOTAL_CURR,
         FIRST_YEAR_YTD,
         RENEWAL_YTD,
         MISC_YTD,
         TOTAL_YTD,
         CREATE_DATE)
      SELECT V_RECORD_NO,
             V_AGENT_RECORD.PAKEY,
             V_PERIODKEY,
             V_CALENDARNAME,
             V_PERIODNAME,
             V_PERIODSTARTDATE,
             V_PERIODENDDATE,
             V_AGENT_RECORD.POSITIONSEQ,
             V_AGENT_RECORD.MANAGERSEQ,
             V_AGENT_RECORD.POSITIONNAME,
             V_AGENT_RECORD.POSITIONTITLE,
             V_AGENT_RECORD.PRODUCERSTATUS,
             V_AGENT_RECORD.LASTNAME,
             V_AGENT_RECORD.POSITIONNAME,
             0,
             0,
             0,
             0,
             0,
             0,
             0,
             0,
             SYSDATE FROM DUAL;
    END LOOP;
    COMMIT;
  END;
--added by zhubin

  PROCEDURE AIA_MALAYSIA_REPORT_PROC IS
  BEGIN

    AIA_AGENT_INFORMATION;
 --   AIA_CREDIT_INFOR;
    AIA_OLD_SCHEME_DATA;
 --Phase 1a
    AIA_AGT_STMT_PROC;
    AIA_IFA_PROC;
    AIA_UNPAID_OVERRIDING_PROC;
    --Phase 1b
    AIA_E13_PROC;
    AIA_E90_PROC;
    --Takaful
    --    AIA_TAKAFUL_BAL_PAYMENT_PROC;
    --Phase 1c
/*    --AIA_AGT_COMPENSATION_PROC;*/

    ------
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;


BEGIN

      SELECT PD.CALENDARNAME, PD.PERIODTYPE, PD.PERIODNAME, PD.PERIODKEY, PD.PERIODSTARTDATE, PD.PERIODENDDATE
     INTO V_CALENDARNAME, V_PERIODTYPE, V_PERIODNAME, V_PERIODKEY, V_PERIODSTARTDATE, V_PERIODENDDATE
     FROM ETLHISTORY ETLH, PERIODDIMENSION PD
    WHERE ETLH.ETLHISTORYKEY = (SELECT MAX(ETLHISTORYKEY) FROM ETLHISTORY)
      AND ETLH.RETURNCODE = 1
      AND PD.PERIODSEQ = ETLH.PERIODSEQ
      AND PD.REMOVEDATE = TO_DATE('2200-1-1', 'YYYY-MM-DD');
/*
SELECT PD.CALENDARNAME,
         PD.PERIODTYPE,
         PD.PERIODNAME,
         PD.PERIODKEY,
         PD.PERIODSTARTDATE,
         PD.PERIODENDDATE
    INTO V_CALENDARNAME,
         V_PERIODTYPE,
         V_PERIODNAME,
         V_PERIODKEY,
         V_PERIODSTARTDATE,
         V_PERIODENDDATE
    FROM PERIODDIMENSION PD
   WHERE PD.REMOVEDATE = TO_DATE('2200-1-1', 'YYYY-MM-DD')
     AND PD.CALENDARNAME = 'AIA MY Fiscal Calendar'
     AND PD.PERIODNAME = 'May 2014B';
*/
  ------get prior period key
  SELECT PD.PERIODKEY
    INTO V_PRIOR_PERIODKEY
    FROM PERIODDIMENSION PD
   WHERE PD.REMOVEDATE = C_REMOVEDATE
     AND PD.CALENDARNAME = V_CALENDARNAME
     AND PD.PERIODENDDATE = V_PERIODSTARTDATE
     AND PD.PERIODTYPE = V_PERIODTYPE;

  C_EARNING_CODE(1) := 'Basic Commission';
  C_EARNING_CODE(2) := 'Agent Provident Fund (APF)';
  C_EARNING_CODE(3) := 'Direct O/R Commission';
  C_EARNING_CODE(4) := 'Indirect O/R Commission';
  C_EARNING_CODE(5) := 'Parallel O/R Commission';
  C_EARNING_CODE(6) := 'Share Direct O/R Commission';
  C_EARNING_CODE(7) := 'Share Indirect O/R Commission';
  C_EARNING_CODE(8) := 'Mortgage Deduction';

  ------MISC
  C_EARNING_CODE(11) := 'Activity Bonus';
  C_EARNING_CODE(12) := 'Agent Production Bonus';
  C_EARNING_CODE(13) := 'Breakaway Bonus';
  C_EARNING_CODE(14) := 'Introducer Bonus';
  C_EARNING_CODE(15) := 'Leader Production Bonus';
  C_EARNING_CODE(16) := 'Manager Indirect Production Bonus';
  C_EARNING_CODE(17) := 'Manager Indirect Provident Fund';
  C_EARNING_CODE(18) := 'Manager Production Bonus';
  C_EARNING_CODE(19) := 'Manager Provident Bonus';
  C_EARNING_CODE(20) := 'Persistency Bonus';
  C_EARNING_CODE(21) := 'Personal Production Bonus';
  C_EARNING_CODE(22) := 'Spin Off Bonus';
  C_EARNING_CODE(23) := 'UM Startup';

  ------Manual Adjustment
  C_EARNING_CODE(25) := 'Payment Adjustment';
  C_EARNING_CODE(26) := 'BIK-Prizes and Awards';
  C_EARNING_CODE(27) := 'BIK-Travel';

  ------E13 Misc
  ------'Direct O/R Commission'
  ------'Indirect O/R Commission'
  ------'Parallel O/R Commission'
  ------'Accident and Health'
  C_EARNING_CODE(24) := 'Accident and Health';

  ------New Scheme
  ------Agent Statement: MISC + Manual Adjustment
  ------E13: MISC + E13 Misc

  ------Old Scheme
  ------Miscellaneous
  C_EARNING_CODE(28) := 'Miscellaneous';
  C_EARNING_CODE(29) := 'MISCELLANEOUS TRANSACTIONS';

  C_EARNING_CODE(301) := 'MORTGAGE LOAN 2';
  C_EARNING_CODE(302) := 'MORTGAGE LOAN';
  C_EARNING_CODE(303) := 'CAR LOAN';
  C_EARNING_CODE(304) := 'CAR LOAN2';
  C_EARNING_CODE(305) := 'CASH LOAN';
  C_EARNING_CODE(306) := 'RENOVATION LOAN';
  C_EARNING_CODE(307) := 'COMMERCIAL LOAN';

  ------Begining Balance
  C_EARNING_CODE(31) := 'Beginning Balance-CL';
  C_EARNING_CODE(32) := 'Beginning Balance-EB';
  C_EARNING_CODE(33) := 'Beginning Balance-GI';
  C_EARNING_CODE(34) := 'Beginning Balance-Group';
  C_EARNING_CODE(35) := 'Beginning Balance-Life';
  C_EARNING_CODE(36) := 'Beginning Balance-PA';
  C_EARNING_CODE(37) := 'Beginning Balance-PL';
  C_EARNING_CODE(38) := 'Beginning Balance-SL';
  C_EARNING_CODE(39) := 'Beginning Balance-Takaful';

  ------Old Scheme APF
  C_EARNING_CODE(41) := 'Beginning Balance-APF';
  C_EARNING_CODE(42) := 'Ending Balance-APF';

  ------Business Of Line
  C_EARNING_CODE(101) := 'LIFE';
  C_EARNING_CODE(102) := 'TAKAFUL';
  C_EARNING_CODE(103) := 'GI';
  C_EARNING_CODE(104) := 'PA';
  C_EARNING_CODE(105) := 'SL';
  C_EARNING_CODE(106) := 'GROUP';
  C_EARNING_CODE(107) := 'CL';
  C_EARNING_CODE(108) := 'PL';
  C_EARNING_CODE(109) := 'MORTGAGE';
  C_EARNING_CODE(110) := 'EB';
  C_EARNING_CODE(111) := 'PRS';

  ------Premium Mode
  C_EARNING_CODE(201) := '01'; --M
  C_EARNING_CODE(202) := '03'; --Q
  C_EARNING_CODE(203) := '06'; --SA
  C_EARNING_CODE(204) := '12'; --A
  C_EARNING_CODE(205) := '00'; --A
  C_EARNING_CODE(206) := '99'; --A

  ------Agency Compensation
  ------ANP
  C_EARNING_CODE(601) := 'ANP';
  C_EARNING_CODE(602) := 'ANP Unit';
  C_EARNING_CODE(603) := 'ANP Group';

END;
