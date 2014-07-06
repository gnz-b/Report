CREATE OR REPLACE PACKAGE BODY AIAB_ISP_INTERFACE_TABLES_PKG IS
  -- add by zhubin 20140706
  /*
  以下是需求文档：
  
  Banc Bank Hierarchy

  TableName: B_BANC_BankHierarchy

  Field               Source
  COMPANY_CODE
  HEADQUARTER_CODE
  HEAD_PAYEEID
  总行                根据POS，寻找上级Title为 “总行”的Position，返回Producer.ID
  PRV_PAYEEID
  省级分行名称        根据POS，寻找上级Title为“省分行”的Position，返回Producer.Last
  BANK_PAYEEID
  分行名称            根据POS，寻找上级Title为“市分行”的Position，返回Producer.Last
  branch_PAYEEID
  支行名称            根据POS，寻找上级Title为“支行”的Position，返回Producer.Last
  subbranch_PAYEEID
  二级支行名称        根据POS，寻找上级Title为“二级支行”的Position，返回Producer.Last
  POS名称             当前日期的POS
  POSCODE
  ISNEW
  POS状态             如当前新增，返回状态为“新增”；否则当前日期的POS的状态（Active/Terminated）
  POS状态变更日期     如新增，返回新增日期；如果POS状态变更为“Terminated”，则返回POS的Termination Date（失效日期）
  开始日期            POS的上级是当前二级支行的版本起始日期
  结束日期            POS的上级是当前二级支行的版本终止日期
  
  
  
  Banc Policy AM Relationship
  
  TableName: B_BANC_PolicyAMRelationship
  
  Field       Source
  保单号      Transaction.PO Number
  保单匹配日  Tx.GD4
  POS_CODE    PAYEEID
  POS名称     根据POS，返回Producer.Last
  FA_CODE     PAYEEID
  FA名称      根据TX.GA19找到对应的Producer，返回Producer.Last
  AM_CODE     PAYEEID
  AM 名称     根据POS到AM的关系，返回Producer.Last
  
  
  Banc Internal Sales Hierarchy
  
  TableName: B_BANC_InternalSalesHierarchy
  
  Field            Source
  分公司           CHO/SH/…  COMPANY CODE 1286/2586...
  AM编号           根据AD，找到上级头衔为"AM"的participant.id
  AM姓名           根据AD，找到上级头衔为"AM"的producer.last
  AD编号           AD的participant.id
  AD姓名           AD的participant.id
  AD状态           如当前新增，返回状态为“新增”；否则当前日期的AD的状态（Active/Terminated）
  AD状态变更日期   如新增，返回新增日期；如果AD状态变更为“Terminated”，则返回POS的Termination Date（失效日期）
  开始日期         AD的上级是AM的版本起始日期
  结束日期         AD的上级是AM的版本终止日期
  
  
  
  Banc Company Code
  
  TableName: B_BANC_CompanyCode
  
  Field                Source
  POS代码              最新版本的POS的Producer ID
  POS名称              最新版本的POS的Producer.Last
  Company Code         根据POS对应的BU返回Company Code
  Original City        根据POS返回原属的City名称
  ORIGINAL_CITY_NAME
  Actual City          根据POS返回实际的City名称
  ACTUAL_CITY_NAME
  
  */

  -- 根据当前POS找到它的上级总行、省分行、市分行、支行、二级支行
  -- 并取得他们的架构各自开始的时间
  -- 取总行、省分行、市分行、支行、二级支行、pos中effectivestartdate最大的作为
  -- 架构的起始日期
  FUNCTION GET_STARTDATE(RULSEQ IN INTEGER, MANSEQ IN INTEGER) RETURN DATE AS
    V_POS_START       DATE;
    V_HEAD_START      DATE;
    V_PRV_START       DATE;
    V_BANK_START      DATE;
    V_BRANCH_START    DATE;
    V_SUBBRANCH_START DATE;
    V_RULSEQ          INTEGER;
    V_MANSEQ          INTEGER;
    V_MANASEQ_TEMP    INTEGER;
    V_RULSEQ_TEMP     INTEGER;
    V_MAX             DATE;
  BEGIN
    V_RULSEQ := RULSEQ;
    V_MANSEQ := MANSEQ;
    V_MAX    := TO_DATE('1991-12-1', 'YYYY-MM-DD');
    -- 找 POS 的上级是当前上级的最早开始日期
    SELECT NVL(STARTDATE, TO_DATE('1991-12-1', 'YYYY-MM-DD'))
      INTO V_POS_START
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ
                               AND POS2.MANAGERSEQ = V_MANSEQ
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP) --求得同一个上级的最早开始时间和最晚结束时间
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MAX < NVL(V_POS_START, TO_DATE('1991-12-1', 'YYYY-MM-DD')) THEN
      V_MAX := V_POS_START;
    END IF;
  
    -- 找 二级支行的当前上级
    V_RULSEQ_TEMP := V_MANSEQ;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(STARTDATE, TO_DATE('1991-12-1', 'YYYY-MM-DD'))
      INTO V_SUBBRANCH_START
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MAX < NVL(V_SUBBRANCH_START, TO_DATE('1991-12-1', 'YYYY-MM-DD')) THEN
      V_MAX := V_SUBBRANCH_START;
    END IF;
  
    V_RULSEQ_TEMP := V_MANASEQ_TEMP;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(STARTDATE, TO_DATE('1991-12-1', 'YYYY-MM-DD'))
      INTO V_BRANCH_START
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MAX < NVL(V_BRANCH_START, TO_DATE('1991-12-1', 'YYYY-MM-DD')) THEN
      V_MAX := V_BRANCH_START;
    END IF;
  
    V_RULSEQ_TEMP := V_MANASEQ_TEMP;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(STARTDATE, TO_DATE('1991-12-1', 'YYYY-MM-DD'))
      INTO V_BANK_START
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MAX < NVL(V_BANK_START, TO_DATE('1991-12-1', 'YYYY-MM-DD')) THEN
      V_MAX := V_BANK_START;
    END IF;
  
    V_RULSEQ_TEMP := V_MANASEQ_TEMP;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(STARTDATE, TO_DATE('1991-12-1', 'YYYY-MM-DD'))
      INTO V_PRV_START
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MAX < NVL(V_PRV_START, TO_DATE('1991-12-1', 'YYYY-MM-DD')) THEN
      V_MAX := V_PRV_START;
    END IF;
  
    V_RULSEQ_TEMP := V_MANASEQ_TEMP;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(STARTDATE, TO_DATE('1991-12-1', 'YYYY-MM-DD'))
      INTO V_HEAD_START
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MAX < NVL(V_HEAD_START, TO_DATE('1991-12-1', 'YYYY-MM-DD')) THEN
      V_MAX := V_HEAD_START;
    END IF;
    RETURN V_MAX;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN V_MAX;   -- 当找上级提前结束（没有那个上级），就会到这里来
  END GET_STARTDATE;

  -- 根据当前POS找到它的上级总行、省分行、市分行、支行、二级支行
  -- 并取得他们的架构各自结束的时间
  -- 取总行、省分行、市分行、支行、二级支行、pos中effectivestartdate最大的作为
  -- 架构的结束日期
  -- 逻辑与上面的函数几乎一样，只是这里取enddate而已
  FUNCTION GET_ENDDATE(RULSEQ IN INTEGER, MANSEQ IN INTEGER) RETURN DATE AS
    V_POS_END       DATE;
    V_HEAD_END      DATE;
    V_PRV_END       DATE;
    V_BANK_END      DATE;
    V_BRANCH_END    DATE;
    V_SUBBRANCH_END DATE;
    V_RULSEQ        INTEGER;
    V_MANSEQ        INTEGER;
    V_MANASEQ_TEMP  INTEGER;
    V_RULSEQ_TEMP   INTEGER;
    V_MIN           DATE;
  BEGIN
    V_RULSEQ := RULSEQ;
    V_MANSEQ := MANSEQ;
    V_MIN    := TO_DATE('2200-1-1', 'YYYY-MM-DD');
    SELECT NVL(ENDDATE, TO_DATE('2200-1-1', 'YYYY-MM-DD'))
      INTO V_POS_END
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ
                               AND POS2.MANAGERSEQ = V_MANSEQ
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MIN > NVL(V_POS_END, TO_DATE('2200-1-1', 'YYYY-MM-DD')) THEN
      V_MIN := V_POS_END;
    END IF;
  
    V_RULSEQ_TEMP := V_MANSEQ;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(ENDDATE, TO_DATE('2200-1-1', 'YYYY-MM-DD'))
      INTO V_SUBBRANCH_END
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MIN > NVL(V_SUBBRANCH_END, TO_DATE('2200-1-1', 'YYYY-MM-DD')) THEN
      V_MIN := V_SUBBRANCH_END;
    END IF;
  
    V_RULSEQ_TEMP := V_MANASEQ_TEMP;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(ENDDATE, TO_DATE('2200-1-1', 'YYYY-MM-DD'))
      INTO V_BRANCH_END
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MIN > NVL(V_BRANCH_END, TO_DATE('2200-1-1', 'YYYY-MM-DD')) THEN
      V_MIN := V_BRANCH_END;
    END IF;
  
    V_RULSEQ_TEMP := V_MANASEQ_TEMP;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(ENDDATE, TO_DATE('2200-1-1', 'YYYY-MM-DD'))
      INTO V_BANK_END
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MIN > NVL(V_BANK_END, TO_DATE('2200-1-1', 'YYYY-MM-DD')) THEN
      V_MIN := V_BANK_END;
    END IF;
  
    V_RULSEQ_TEMP := V_MANASEQ_TEMP;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(ENDDATE, TO_DATE('2200-1-1', 'YYYY-MM-DD'))
      INTO V_PRV_END
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MIN > NVL(V_PRV_END, TO_DATE('2200-1-1', 'YYYY-MM-DD')) THEN
      V_MIN := V_PRV_END;
    END IF;
  
    V_RULSEQ_TEMP := V_MANASEQ_TEMP;
    SELECT POS.MANAGERSEQ
      INTO V_MANASEQ_TEMP
      FROM CS_POSITION POS
     WHERE POS.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
       AND POS.REMOVEDATE > SYSDATE
       AND POS.ISLAST = 1;
    SELECT NVL(ENDDATE, TO_DATE('2200-1-1', 'YYYY-MM-DD'))
      INTO V_HEAD_END
      FROM (SELECT MIN(STARTDATE) STARTDATE, MAX(ENDDATE) ENDDATE
              FROM (SELECT SEQ,
                           STARTDATE,
                           ENDDATE,
                           SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                      FROM (SELECT POS2.RULEELEMENTOWNERSEQ SEQ,
                                   POS2.EFFECTIVESTARTDATE STARTDATE,
                                   POS2.EFFECTIVEENDDATE ENDDATE,
                                   POS2.EFFECTIVESTARTDATE -
                                   LAG(POS2.EFFECTIVEENDDATE) OVER(PARTITION BY POS2.RULEELEMENTOWNERSEQ ORDER BY POS2.EFFECTIVESTARTDATE) GRP
                              FROM CS_POSITION POS2
                             WHERE POS2.RULEELEMENTOWNERSEQ = V_RULSEQ_TEMP
                               AND POS2.MANAGERSEQ = V_MANASEQ_TEMP
                               AND POS2.REMOVEDATE > SYSDATE))
             GROUP BY SEQ, GRP)
     WHERE SYSDATE BETWEEN STARTDATE AND ENDDATE - 1;
    IF V_MIN > NVL(V_HEAD_END, TO_DATE('2200-1-1', 'YYYY-MM-DD')) THEN
      V_MIN := V_HEAD_END;
    END IF;
    RETURN V_MIN;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN V_MIN;  -- 当找上级提前结束（没有那个上级），就会到这里来
  END GET_ENDDATE;

  -- 根据POS NAME和当前日期，获得总行的CHANNEL_NAME
  FUNCTION AIAB_GET_CHANNEL_NAME(P_NAME IN VARCHAR2, P_VIEWDATE DATE)
    RETURN VARCHAR2 IS
    V_BANKNAME VARCHAR2(100) := NULL;
  BEGIN
    SELECT PEE.PAYEEID -- CHANNEL_NAME
      INTO V_BANKNAME
      FROM (SELECT POS2.POSNAME, POS2.TITLESEQ, POS2.PAYEESEQ
              FROM (SELECT POS.NAME POSNAME,
                           POS.PAYEESEQ,
                           POS.RULEELEMENTOWNERSEQ,
                           POS.MANAGERSEQ,
                           POS.TITLESEQ
                      FROM CS_POSITION POS
                     WHERE POS.REMOVEDATE =
                           TO_DATE('2200-01-01', 'YYYY-MM-DD')
                       AND P_VIEWDATE BETWEEN POS.EFFECTIVESTARTDATE AND
                           POS.EFFECTIVEENDDATE - 1) POS2
             START WITH POS2.POSNAME = P_NAME
            CONNECT BY PRIOR POS2.MANAGERSEQ = POS2.RULEELEMENTOWNERSEQ) POS3,
           CS_TITLE TIT3,
           cs_participant par3,
           cs_payee pee
     WHERE POS3.TITLESEQ = TIT3.RULEELEMENTOWNERSEQ
       AND pos3.payeeseq = par3.payeeseq
       and par3.payeeseq = pee.payeeseq
       AND TIT3.removedate = TO_DATE('2200-01-01', 'YYYY-MM-DD')
       AND par3.removedate = TO_DATE('2200-01-01', 'YYYY-MM-DD')
       AND PEE.REMOVEDATE = TO_DATE('2200-01-01', 'YYYY-MM-DD')
       AND P_VIEWDATE BETWEEN PEE.EFFECTIVESTARTDATE AND
           PEE.EFFECTIVEENDDATE - 1
       AND P_VIEWDATE BETWEEN par3.EFFECTIVESTARTDATE AND
           par3.EFFECTIVEENDDATE - 1
       AND TIT3.NAME = '总行';
    RETURN(V_BANKNAME);
  
  EXCEPTION
    WHEN NO_DATA_FOUND
     THEN
      RETURN(NULL);
  END AIAB_GET_CHANNEL_NAME;

  --B_BANC_BankHierarchy
  PROCEDURE B_BANC_BANK_HIERARCHY IS
  BEGIN
    UPDATE B_BANC_BANKHIERARCHY_TEMP BBBT
       SET BBBT.ISNEW = ''
     WHERE BBBT.ISNEW = '新增';
    COMMIT;
    FOR CUR IN ((SELECT POS.RULEELEMENTOWNERSEQ POSRULSEQ,
                        CASE
                          WHEN BU.NAME = 'Banc Shanghai' THEN
                           '0986'
                          WHEN BU.NAME = 'Banc Beijing' THEN
                           '1186'
                          WHEN BU.NAME = 'Banc Jiangsu' THEN
                           '1286'
                          WHEN BU.NAME = 'Banc Shenzhen' THEN
                           '1086'
                          WHEN BU.NAME = 'Banc Guangdong' THEN
                           '2586'
                        END AS COMPANY_CODE,
                        (SELECT PAR.FIRSTNAME
                           FROM CS_POSITION POS1, CS_PARTICIPANT PAR
                          WHERE POS1.PAYEESEQ = PAR.PAYEESEQ
                            AND POS1.REMOVEDATE > SYSDATE
                            AND POS1.ISLAST = 1
                            AND POS1.NAME =
                                AIA_GET_BANK_NAME(POS.NAME, SYSDATE)
                            AND PAR.REMOVEDATE > SYSDATE
                            AND PAR.ISLAST = 1) HEAD_CODE,
                        (SELECT PEE.PAYEEID
                           FROM CS_PAYEE PEE, CS_POSITION POS1
                          WHERE POS1.PAYEESEQ = PEE.PAYEESEQ
                            AND POS1.REMOVEDATE > SYSDATE
                            AND POS1.ISLAST = 1
                            AND POS1.NAME =
                                AIA_GET_BANK_NAME(POS.NAME, SYSDATE)
                            AND PEE.REMOVEDATE > SYSDATE
                            AND PEE.ISLAST = 1) HEAD_PAYEEID,
                        AIA_GET_BANK_NAME(POS.NAME, SYSDATE) HEADQUARTER,
                        (SELECT PEE.PAYEEID
                           FROM CS_PAYEE PEE, CS_POSITION POS1
                          WHERE POS1.PAYEESEQ = PEE.PAYEESEQ
                            AND POS1.REMOVEDATE > SYSDATE
                            AND POS1.ISLAST = 1
                            AND POS1.NAME =
                                AIAB_COM_BAL_CHECK.AIAB_SEARCH_PRVNAME(POS.RULEELEMENTOWNERSEQ,
                                                                       '省级分行')
                            AND PEE.REMOVEDATE > SYSDATE
                            AND PEE.ISLAST = 1) PRV_PAYEEID,
                        AIAB_COM_BAL_CHECK.AIAB_SEARCH_PRVNAME(POS.RULEELEMENTOWNERSEQ,
                                                               '省级分行') PRVNAME,
                        (SELECT PEE.PAYEEID
                           FROM CS_PAYEE PEE, CS_POSITION POS1
                          WHERE POS1.PAYEESEQ = PEE.PAYEESEQ
                            AND POS1.REMOVEDATE > SYSDATE
                            AND POS1.ISLAST = 1
                            AND POS1.NAME =
                                AIAB_COM_BAL_CHECK.AIAB_SEARCH_MGRNAME(POS.RULEELEMENTOWNERSEQ,
                                                                       '市分行')
                            AND PEE.REMOVEDATE > SYSDATE
                            AND PEE.ISLAST = 1) BANK_PAYEEID,
                        AIAB_COM_BAL_CHECK.AIAB_SEARCH_MGRNAME(POS.RULEELEMENTOWNERSEQ,
                                                               '市分行') BANKNAME,
                        (SELECT PEE.PAYEEID
                           FROM CS_PAYEE PEE, CS_POSITION POS1
                          WHERE POS1.PAYEESEQ = PEE.PAYEESEQ
                            AND POS1.REMOVEDATE > SYSDATE
                            AND POS1.ISLAST = 1
                            AND POS1.NAME =
                                AIAB_COM_BAL_CHECK.AIAB_SEARCH_MGRNAME(POS.RULEELEMENTOWNERSEQ,
                                                                       '支行')
                            AND PEE.REMOVEDATE > SYSDATE
                            AND PEE.ISLAST = 1) BRANCH_PAYEEID,
                        AIAB_COM_BAL_CHECK.AIAB_SEARCH_MGRNAME(POS.RULEELEMENTOWNERSEQ,
                                                               '支行') BRANCHNAME,
                        (SELECT PEE.PAYEEID
                           FROM CS_PAYEE PEE, CS_POSITION POS1
                          WHERE POS1.PAYEESEQ = PEE.PAYEESEQ
                            AND POS1.REMOVEDATE > SYSDATE
                            AND POS1.ISLAST = 1
                            AND POS1.NAME =
                                AIAB_COM_BAL_CHECK.AIAB_SEARCH_MGRNAME(POS.RULEELEMENTOWNERSEQ,
                                                                       '二级支行')
                            AND PEE.REMOVEDATE > SYSDATE
                            AND PEE.ISLAST = 1) SUBBRANCH_PAYEEID,
                        AIAB_COM_BAL_CHECK.AIAB_SEARCH_MGRNAME(POS.RULEELEMENTOWNERSEQ,
                                                               '二级支行') SUBBRANCHNAME,
                        POS.NAME POSNAME,
                        PEE.PAYEEID POSCODE,
                        '' ISNEW,
                        (SELECT STC.STATUS
                           FROM CSP_PRODUCER PDU, CSP_STATUSCODE STC
                          WHERE PDU.PAYEESEQ = POS.PAYEESEQ
                            AND PDU.STATUSCODESEQ = STC.DATATYPESEQ
                            AND PDU.REMOVEDATE > SYSDATE
                            AND STC.REMOVEDATE > SYSDATE
                            AND PDU.ISLAST = 1) STATUS,
                        (SELECT PAR.TERMINATIONDATE
                           FROM CS_PARTICIPANT PAR
                          WHERE PAR.PAYEESEQ = POS.PAYEESEQ
                            AND PAR.REMOVEDATE > SYSDATE
                            AND PAR.ISLAST = 1) CHANGED_DATE,
                        AIAB_ISP_INTERFACE_TABLES_PKG.GET_STARTDATE(POS.RULEELEMENTOWNERSEQ,
                                                                    POS.MANAGERSEQ) STARTDATE,
                        AIAB_ISP_INTERFACE_TABLES_PKG.GET_ENDDATE(POS.RULEELEMENTOWNERSEQ,
                                                                  POS.MANAGERSEQ) ENDDATE
                   FROM CS_POSITION       POS,
                        CS_TITLE          TIT,
                        CS_PROCESSINGUNIT PRU,
                        cs_businessunit   BU,
                        CS_PAYEE          PEE
                  WHERE POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
                    AND POS.PAYEESEQ = PEE.PAYEESEQ
                    AND PEE.REMOVEDATE > SYSDATE
                    AND PEE.ISLAST = 1
                    AND BU.MASK = PEE.BUSINESSUNITMAP
                    AND POS.REMOVEDATE > SYSDATE
                    AND POS.ISLAST = 1
                    AND TIT.REMOVEDATE > SYSDATE
                    AND TIT.ISLAST = 1
                    AND TIT.NAME = 'POS'
                    AND POS.PROCESSINGUNITSEQ = PRU.PROCESSINGUNITSEQ
                    AND PRU.NAME = 'PU-Banc') MINUS
                (SELECT * FROM B_BANC_BANKHIERARCHY_TEMP)) LOOP
      -- 对减一下，找出新增或有变化的数据
      UPDATE B_BANC_BANKHIERARCHY_TEMP BBBT -- 更新有变化的数据
         SET BBBT.ISNEW = '失效', BBBT.ENDDATE = CUR.STARTDATE
       WHERE BBBT.POSRULSEQ = CUR.POSRULSEQ
         AND BBBT.STARTDATE =
             (SELECT MAX(BBBT1.STARTDATE) -- 同一个SEQ有多条记录的话，必然是更新STARTDATE最晚的一条
                FROM B_BANC_BANKHIERARCHY_TEMP BBBT1
               WHERE BBBT1.POSRULSEQ = CUR.POSRULSEQ);
      -- 新增的记录插进去
      INSERT INTO B_BANC_BANKHIERARCHY_TEMP BBBT
        (BBBT.POSRULSEQ,
         BBBT.COMPANY_CODE,
         BBBT.HEADQUARTER_CODE,
         BBBT.HEAD_PAYEEID,
         BBBT.HEADQUARTER,
         BBBT.PRV_PAYEEID,
         BBBT.PRVNAME,
         BBBT.BANK_PAYEEID,
         BBBT.BANKNAME,
         BBBT.branch_PAYEEID,
         BBBT.BRANCHNAME,
         BBBT.subbranch_PAYEEID,
         BBBT.SUBBRANCHNAME,
         BBBT.POSNAME,
         BBBT.POSCODE,
         BBBT.ISNEW,
         BBBT.POS_STATUS,
         BBBT.POS_CHANGED_DATE,
         BBBT.STARTDATE,
         BBBT.ENDDATE)
      VALUES
        (CUR.POSRULSEQ,
         CUR.COMPANY_CODE,
         CUR.HEAD_CODE,
         CUR.HEAD_PAYEEID,
         CUR.HEADQUARTER,
         CUR.PRV_PAYEEID,
         CUR.PRVNAME,
         CUR.BANK_PAYEEID,
         CUR.BANKNAME,
         CUR.branch_PAYEEID,
         CUR.BRANCHNAME,
         CUR.subbranch_PAYEEID,
         CUR.SUBBRANCHNAME,
         CUR.POSNAME,
         CUR.POSCODE,
         '新增',
         CUR.STATUS,
         CUR.CHANGED_DATE,
         CUR.STARTDATE,
         CUR.ENDDATE);
    END LOOP;
    COMMIT;
    DELETE FROM B_BANC_BANKHIERARCHY;
    COMMIT;
    -- 将temp表复制到正式表
    INSERT INTO B_BANC_BANKHIERARCHY
      (COMPANY_CODE,
       HEADQUARTER_CODE,
       HEAD_PAYEEID,
       HEADQUARTER,
       PRV_PAYEEID,
       PRVNAME,
       BANK_PAYEEID,
       BANKNAME,
       branch_PAYEEID,
       BRANCHNAME,
       subbranch_PAYEEID,
       SUBBRANCHNAME,
       POSNAME,
       POSCODE,
       ISNEW,
       POS_STATUS,
       POS_CHANGED_DATE,
       STARTDATE,
       ENDDATE)
      SELECT BBBT.COMPANY_CODE,
             BBBT.HEADQUARTER_CODE,
             BBBT.HEAD_PAYEEID,
             BBBT.HEADQUARTER,
             BBBT.PRV_PAYEEID,
             BBBT.PRVNAME,
             BBBT.BANK_PAYEEID,
             BBBT.BANKNAME,
             BBBT.branch_PAYEEID,
             BBBT.BRANCHNAME,
             BBBT.subbranch_PAYEEID,
             BBBT.SUBBRANCHNAME,
             BBBT.POSNAME,
             BBBT.POSCODE,
             BBBT.ISNEW,
             BBBT.POS_STATUS,
             BBBT.POS_CHANGED_DATE,
             BBBT.STARTDATE,
             BBBT.ENDDATE
        FROM B_BANC_BANKHIERARCHY_TEMP BBBT;
    COMMIT;
  END;

  --B_BANC_PolicyAMRelationship
  PROCEDURE B_BANC_POLICY_AM_RELATIONSHIP IS
  BEGIN
    DELETE FROM B_BANC_POLICYAMRELATIONSHIP;
    COMMIT;
    INSERT INTO B_BANC_POLICYAMRELATIONSHIP
      (ponumber,
       POLICYISSUEDATE,
       POS_CODE,
       POS_NAME,
       FA_CODE,
       FA_NAME,
       AM_CODE,
       AM_NAME)
      SELECT DISTINCT TX.PONUMBER PONUMBER,
                TX.GENERICDATE3 POLICYISSUEDATE,
                PEE.PAYEEID POS_CODE,
                PAR.LASTNAME POSNAME,
                (SELECT DISTINCT PEEFA.PAYEEID
                   FROM CS_PAYEE          PEEFA,
                        CS_PARTICIPANT    PARFA,
                        CSP_PRODUCER      PROFA,
                        CSP_PRODUCERTYPE  PROTFA,
                        CS_BUSINESSUNIT   BUFA,
                        CS_PROCESSINGUNIT PUFA
                  WHERE 1 = 1
                    AND PEEFA.PAYEESEQ = PARFA.PAYEESEQ
                    AND PEEFA.PAYEESEQ = PROFA.PAYEESEQ
                    AND PROFA.PRODUCERTYPESEQ = PROTFA.DATATYPESEQ
                    AND PEEFA.BUSINESSUNITMAP = BUFA.MASK
                    AND BUFA.PROCESSINGUNITSEQ = PUFA.PROCESSINGUNITSEQ
                    AND PEEFA.REMOVEDATE > SYSDATE
                    AND PEEFA.ISLAST = 1
                    AND PARFA.REMOVEDATE > SYSDATE
                    AND PARFA.ISLAST = 1
                    AND PROFA.REMOVEDATE > SYSDATE
                    AND PROFA.ISLAST = 1
                    AND PROTFA.REMOVEDATE > SYSDATE
                    AND PROTFA.NAME = 'Banc FA'
                    AND PUFA.NAME = 'PU-Banc'
                    AND PEEFA.PAYEEID = TX.GENERICATTRIBUTE19) FA_CODE,  -- TX.GA19放的是FA的payeeid
                (SELECT DISTINCT PARFA.LASTNAME
                   FROM CS_PAYEE          PEEFA,
                        CS_PARTICIPANT    PARFA,
                        CSP_PRODUCER      PROFA,
                        CSP_PRODUCERTYPE  PROTFA,
                        CS_BUSINESSUNIT   BUFA,
                        CS_PROCESSINGUNIT PUFA
                  WHERE 1 = 1
                    AND PEEFA.PAYEESEQ = PARFA.PAYEESEQ
                    AND PEEFA.PAYEESEQ = PROFA.PAYEESEQ
                    AND PROFA.PRODUCERTYPESEQ = PROTFA.DATATYPESEQ
                    AND PEEFA.BUSINESSUNITMAP = BUFA.MASK
                    AND BUFA.PROCESSINGUNITSEQ = PUFA.PROCESSINGUNITSEQ
                    AND PEEFA.REMOVEDATE > SYSDATE
                    AND PEEFA.ISLAST = 1
                    AND PARFA.REMOVEDATE > SYSDATE
                    AND PARFA.ISLAST = 1
                    AND PROFA.REMOVEDATE > SYSDATE
                    AND PROFA.ISLAST = 1
                    AND PROTFA.REMOVEDATE > SYSDATE
                    AND PROTFA.NAME = 'Banc FA'
                    AND PUFA.NAME = 'PU-Banc'
                    AND PEEFA.PAYEEID = TX.GENERICATTRIBUTE19) FA_NAME,  -- TX.GA19放的是FA的payeeid
                (SELECT DISTINCT PEEAM.PAYEEID
                   FROM CS_POSITION       POSAM,
                        CS_PAYEE          PEEAM,
                        CS_PARTICIPANT    PARAM,
                        CS_TITLE          TITAM,
                        CS_PROCESSINGUNIT PUAM
                  WHERE 1 = 1
                    AND POSAM.PAYEESEQ = PEEAM.PAYEESEQ
                    AND PEEAM.PAYEESEQ = PARAM.PAYEESEQ
                    AND TITAM.RULEELEMENTOWNERSEQ = POSAM.TITLESEQ
                    AND POSAM.PROCESSINGUNITSEQ = PUAM.PROCESSINGUNITSEQ
                    AND POSAM.REMOVEDATE > SYSDATE
                    AND PEEAM.REMOVEDATE > SYSDATE
                    AND PARAM.REMOVEDATE > SYSDATE
                    AND TITAM.REMOVEDATE > SYSDATE
                    AND POSAM.ISLAST = 1
                    AND PEEAM.ISLAST = 1
                    AND PARAM.ISLAST = 1
                    AND TITAM.ISLAST = 1
                    AND TITAM.NAME = 'AM'
                    AND PUAM.NAME = 'PU-Banc'
                    AND POSAM.RULEELEMENTOWNERSEQ = REL.PARENTPOSITIONSEQ -- AM与POS通过REL表关联
                    AND POSAM.EFFECTIVESTARTDATE <= TX.GENERICDATE3
                    AND POSAM.EFFECTIVEENDDATE > TX.GENERICDATE3) AM_CODE,
                (SELECT DISTINCT PARAM.LASTNAME
                   FROM CS_POSITION       POSAM,
                        CS_PAYEE          PEEAM,
                        CS_PARTICIPANT    PARAM,
                        CS_TITLE          TITAM,
                        CS_PROCESSINGUNIT PUAM
                  WHERE 1 = 1
                    AND POSAM.PAYEESEQ = PEEAM.PAYEESEQ
                    AND PEEAM.PAYEESEQ = PARAM.PAYEESEQ
                    AND TITAM.RULEELEMENTOWNERSEQ = POSAM.TITLESEQ
                    AND POSAM.PROCESSINGUNITSEQ = PUAM.PROCESSINGUNITSEQ
                    AND POSAM.REMOVEDATE > SYSDATE
                    AND PEEAM.REMOVEDATE > SYSDATE
                    AND PARAM.REMOVEDATE > SYSDATE
                    AND TITAM.REMOVEDATE > SYSDATE
                    AND POSAM.ISLAST = 1
                    AND PEEAM.ISLAST = 1
                    AND PARAM.ISLAST = 1
                    AND TITAM.ISLAST = 1
                    AND TITAM.NAME = 'AM'
                    AND PUAM.NAME = 'PU-Banc'
                    AND POSAM.RULEELEMENTOWNERSEQ = REL.PARENTPOSITIONSEQ -- AM与POS通过REL表关联
                    AND POSAM.EFFECTIVESTARTDATE <= TX.GENERICDATE3
                    AND POSAM.EFFECTIVEENDDATE > TX.GENERICDATE3) AM_NAME
  FROM CS_POSITION              POS,
       CS_PARTICIPANT           PAR,
       CS_PAYEE                 PEE,
       CS_POSITIONRELATION      REL,
       CS_POSITIONRELATIONTYPE  RELT,
       CS_TITLE                 TIT,
       CS_PROCESSINGUNIT        PU,
       CS_SALESTRANSACTION      TX,
       CS_TRANSACTIONASSIGNMENT TXAS,
       CS_EVENTTYPE             ETTY
 WHERE 1 = 1
   AND POS.PAYEESEQ = PAR.PAYEESEQ
   AND POS.PAYEESEQ = PEE.PAYEESEQ
   AND REL.POSITIONRELATIONTYPESEQ = RELT.DATATYPESEQ
   AND REL.CHILDPOSITIONSEQ = POS.RULEELEMENTOWNERSEQ
   AND POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
   AND POS.PROCESSINGUNITSEQ = PU.PROCESSINGUNITSEQ
   AND POS.NAME = TXAS.POSITIONNAME
   AND TX.SALESTRANSACTIONSEQ = TXAS.SALESTRANSACTIONSEQ
   AND ETTY.DATATYPESEQ = TX.EVENTTYPESEQ
   AND POS.REMOVEDATE > SYSDATE
   AND PAR.REMOVEDATE > SYSDATE
   AND PEE.REMOVEDATE > SYSDATE
   AND REL.REMOVEDATE > SYSDATE
   AND RELT.REMOVEDATE > SYSDATE
   AND TIT.REMOVEDATE > SYSDATE
   AND ETTY.REMOVEDATE > SYSDATE
   AND POS.ISLAST = 1
   AND PAR.ISLAST = 1
   AND PEE.ISLAST = 1
   AND REL.ISLAST = 1
   AND TIT.ISLAST = 1
   AND ETTY.EVENTTYPEID = 'FYP'
   AND TIT.NAME = 'POS'
   AND PU.NAME = 'PU-Banc'
   AND RELT.NAME = 'Contract Rollup'
   AND REL.EFFECTIVESTARTDATE <= SYSDATE
   AND REL.EFFECTIVEENDDATE > SYSDATE;
    COMMIT;
  END;

  --Banc Internal Sales Hierarchy
  PROCEDURE INTERNAL_SALES_HIERARCHY IS
  BEGIN
    UPDATE B_BANC_INTERNALSALESHIERARCHY T SET T.ISNEW = '';
    COMMIT;
    MERGE INTO B_BANC_INTERNALSALESHIERARCHY BBI
    USING ((SELECT CASE
                     WHEN BRANCHCOMPANY = 'Banc Shanghai' THEN
                      '0986'
                     WHEN BRANCHCOMPANY = 'Banc Beijing' THEN
                      '1186'
                     WHEN BRANCHCOMPANY = 'Banc Jiangsu' THEN
                      '1286'
                     WHEN BRANCHCOMPANY = 'Banc Shenzhen' THEN
                      '1086'
                     WHEN BRANCHCOMPANY = 'Banc Guangdong' THEN
                      '2586'
                   END AS branchcompany_code,
                   AMCODE,
                   AMNAME,
                   ADCODE,
                   ADNAME,
                   ISNEW,
                   STATUS,
                   CHANGED_DATE,
                   STARTDATE,
                   ENDDATE
              FROM (SELECT BRANCHCOMPANY,
                           PAYEESEQ,
                           AMCODE,
                           AMNAME,
                           ADCODE,
                           ADNAME,
                           '' AS ISNEW,
                           (SELECT STC.STATUS
                              FROM CSP_PRODUCER PDU, CSP_STATUSCODE STC
                             WHERE PDU.PAYEESEQ = AMAD1.PAYEESEQ
                               AND PDU.STATUSCODESEQ = STC.DATATYPESEQ
                               AND PDU.REMOVEDATE > SYSDATE
                               AND STC.REMOVEDATE > SYSDATE
                               AND PDU.ISLAST = 1) AS STATUS,
                           (SELECT PAR.TERMINATIONDATE
                              FROM CS_PARTICIPANT PAR
                             WHERE PAR.PAYEESEQ = AMAD1.PAYEESEQ
                               AND PAR.REMOVEDATE > SYSDATE
                               AND PAR.ISLAST = 1) AS CHANGED_DATE,
                           MIN(STARTDATE) STARTDATE,
                           MAX(ENDDATE) ENDDATE
                      FROM (SELECT BRANCHCOMPANY,
                                   PAYEESEQ,
                                   AMCODE,
                                   AMNAME,
                                   ADCODE,
                                   ADNAME,
                                   STARTDATE,
                                   ENDDATE,
                                   SUM(NVL(GRP, 1)) OVER(ORDER BY ROWNUM) GRP
                              FROM (SELECT AMAD.BRANCHCOMPANY AS BRANCHCOMPANY,
                                           AMAD.PAYEESEQ AS PAYEESEQ,
                                           AMAD.AMCODE AS AMCODE,
                                           AMAD.AMNAME AS AMNAME,
                                           AMAD.ADCODE AS ADCODE,
                                           AMAD.ADNAME AS ADNAME,
                                           AMAD.STARTDATE AS STARTDATE,
                                           AMAD.ENDDATE AS ENDDATE,
                                           AMAD.STARTDATE - LAG(AMAD.ENDDATE) OVER(PARTITION BY AMAD.BRANCHCOMPANY, AMAD.PAYEESEQ, AMAD.AMCODE, AMAD.AMNAME, AMAD.ADCODE, AMAD.ADNAME ORDER BY AMAD.STARTDATE) - 1 GRP
                                      FROM (WITH AM AS (SELECT RULSEQ, -- 获得 AM 的人员信息表，考虑了AM在一段时期内有同一个上级，但是却有多个版本
                                                               BRANCHCOMPANY, -- 这时候需要将这些版本合并成一条，主要就是对effectivedate进行合并
                                                               AMCODE, -- 在求 AD 的时候也一样考虑了这些逻辑，因此就不再注释
                                                               PAYEESEQ,
                                                               AMNAME,
                                                               MANAGERSEQ,
                                                               MIN(STARTDATE) STARTDATE,
                                                               MAX(NVL(ENDDATE,
                                                                       TO_DATE('2199-12-31',
                                                                               'yyyy-mm-dd'))) ENDDATE
                                                          FROM (SELECT RULSEQ,
                                                                       BRANCHCOMPANY,
                                                                       AMCODE,
                                                                       PAYEESEQ,
                                                                       AMNAME,
                                                                       MANAGERSEQ,
                                                                       STARTDATE,
                                                                       ENDDATE,
                                                                       SUM(NVL(GRP,
                                                                               1)) OVER(ORDER BY ROWNUM) GRP -- 如果两条记录可以合并，他们的sum就相等，然后通过group by就可以合并
                                                                  FROM (SELECT CPS.RULEELEMENTOWNERSEQ AS RULSEQ,
                                                                               BU.NAME AS BRANCHCOMPANY,
                                                                               CPA.PAYEEID AS AMCODE,
                                                                               CPA.PAYEESEQ AS PAYEESEQ,
                                                                               CPS.NAME AS AMNAME,
                                                                               CPS.MANAGERSEQ AS MANAGERSEQ,
                                                                               CPS.EFFECTIVESTARTDATE AS STARTDATE,
                                                                               CPS.EFFECTIVEENDDATE - 1 AS ENDDATE,
                                                                               CPS.EFFECTIVESTARTDATE - --标记出该条记录是否可以和前一条记录合并，可以的话标记为0，否则为空
                                                                               LAG(CPS.EFFECTIVEENDDATE - 1) OVER(PARTITION BY CPS.RULEELEMENTOWNERSEQ, BU.NAME, CPA.PAYEEID, CPS.NAME, CPS.MANAGERSEQ ORDER BY CPS.EFFECTIVESTARTDATE) - 1 GRP
                                                                          FROM CS_POSITION       CPS,
                                                                               CS_TITLE          CST,
                                                                               CS_BUSINESSUNIT   BU,
                                                                               CS_PAYEE          CPA,
                                                                               CS_PROCESSINGUNIT CPRSU
                                                                         WHERE 1 = 1
                                                                           AND CPS.TITLESEQ =
                                                                               CST.RULEELEMENTOWNERSEQ
                                                                           AND CPS.PAYEESEQ =
                                                                               CPA.PAYEESEQ
                                                                           AND CPA.BUSINESSUNITMAP =
                                                                               BU.MASK
                                                                           AND BU.PROCESSINGUNITSEQ =
                                                                               CPRSU.PROCESSINGUNITSEQ
                                                                           AND CPRSU.NAME =
                                                                               'PU-Banc'
                                                                           AND CST.NAME = 'AM'
                                                                           AND CST.REMOVEDATE =
                                                                               TO_DATE('2200-01-01',
                                                                                       'yyyy-mm-dd')
                                                                           AND CPS.REMOVEDATE =
                                                                               TO_DATE('2200-01-01',
                                                                                       'yyyy-mm-dd')
                                                                           AND CPA.REMOVEDATE =
                                                                               TO_DATE('2200-01-01',
                                                                                       'yyyy-mm-dd')
                                                                           AND CST.ISLAST = 1
                                                                           AND CPA.ISLAST = 1))
                                                         GROUP BY RULSEQ,
                                                                  BRANCHCOMPANY,
                                                                  AMCODE,
                                                                  PAYEESEQ,
                                                                  AMNAME,
                                                                  MANAGERSEQ,
                                                                  GRP), AD AS (SELECT RULSEQ,
                                                                                      BRANCHCOMPANY,
                                                                                      ADCODE,
                                                                                      PAYEESEQ,
                                                                                      ADNAME,
                                                                                      MANAGERSEQ,
                                                                                      MIN(STARTDATE) STARTDATE,
                                                                                      MAX(NVL(ENDDATE,
                                                                                              TO_DATE('2199-12-31',
                                                                                                      'yyyy-mm-dd'))) ENDDATE
                                                                                 FROM (SELECT RULSEQ,
                                                                                              BRANCHCOMPANY,
                                                                                              ADCODE,
                                                                                              PAYEESEQ,
                                                                                              ADNAME,
                                                                                              MANAGERSEQ,
                                                                                              STARTDATE,
                                                                                              ENDDATE,
                                                                                              SUM(NVL(GRP,
                                                                                                      1)) OVER(ORDER BY ROWNUM) GRP
                                                                                         FROM (SELECT CPS.RULEELEMENTOWNERSEQ AS RULSEQ,
                                                                                                      BU.NAME AS BRANCHCOMPANY,
                                                                                                      CPA.PAYEEID AS ADCODE,
                                                                                                      CPA.PAYEESEQ AS PAYEESEQ,
                                                                                                      CPS.NAME AS ADNAME,
                                                                                                      CPS.MANAGERSEQ AS MANAGERSEQ,
                                                                                                      CPS.EFFECTIVESTARTDATE AS STARTDATE,
                                                                                                      CPS.EFFECTIVEENDDATE - 1 AS ENDDATE,
                                                                                                      CPS.EFFECTIVESTARTDATE -
                                                                                                      LAG(CPS.EFFECTIVEENDDATE - 1) OVER(PARTITION BY CPS.RULEELEMENTOWNERSEQ, BU.NAME, CPA.PAYEEID, CPS.NAME, CPS.MANAGERSEQ ORDER BY CPS.EFFECTIVESTARTDATE) - 1 GRP
                                                                                                 FROM CS_POSITION       CPS,
                                                                                                      CS_TITLE          CST,
                                                                                                      CS_BUSINESSUNIT   BU,
                                                                                                      CS_PAYEE          CPA,
                                                                                                      CS_PROCESSINGUNIT CPRSU
                                                                                                WHERE 1 = 1
                                                                                                  AND CPS.TITLESEQ =
                                                                                                      CST.RULEELEMENTOWNERSEQ
                                                                                                  AND CPS.PAYEESEQ =
                                                                                                      CPA.PAYEESEQ
                                                                                                  AND CPA.BUSINESSUNITMAP =
                                                                                                      BU.MASK
                                                                                                  AND BU.PROCESSINGUNITSEQ =
                                                                                                      CPRSU.PROCESSINGUNITSEQ
                                                                                                  AND CPRSU.NAME =
                                                                                                      'PU-Banc'
                                                                                                  AND CST.NAME = 'AD'
                                                                                                  AND CST.REMOVEDATE =
                                                                                                      TO_DATE('2200-01-01',
                                                                                                              'yyyy-mm-dd')
                                                                                                  AND CPS.REMOVEDATE =
                                                                                                      TO_DATE('2200-01-01',
                                                                                                              'yyyy-mm-dd')
                                                                                                  AND CPA.REMOVEDATE =
                                                                                                      TO_DATE('2200-01-01',
                                                                                                              'yyyy-mm-dd')
                                                                                                  AND CST.ISLAST = 1
                                                                                                  AND CPA.ISLAST = 1))
                                                                                GROUP BY RULSEQ,
                                                                                         BRANCHCOMPANY,
                                                                                         ADCODE,
                                                                                         PAYEESEQ,
                                                                                         ADNAME,
                                                                                         MANAGERSEQ,
                                                                                         GRP)
                                             SELECT AM.BRANCHCOMPANY,
                                                    AM.AMCODE,
                                                    AM.AMNAME,
                                                    AM.PAYEESEQ,
                                                    AD.ADCODE,
                                                    AD.ADNAME,
                                                    CASE
                                                      WHEN AM.STARTDATE >
                                                           AD.STARTDATE THEN
                                                       AM.STARTDATE
                                                      ELSE
                                                       AD.STARTDATE
                                                    END AS STARTDATE, -- AD 的职衔比 AM高，取他们两个中最晚的statdate
                                                    CASE
                                                      WHEN AM.ENDDATE <
                                                           AD.ENDDATE THEN
                                                       AM.ENDDATE
                                                      ELSE
                                                       AD.ENDDATE
                                                    END AS ENDDATE -- 取他们两个中最早的enddate
                                               FROM AM, AD
                                              WHERE AM.MANAGERSEQ = AD.RULSEQ
                                                AND AM.STARTDATE < AD.ENDDATE
                                                AND AM.ENDDATE > AD.STARTDATE -- 确保AM 和AD 两者之间有时间上的交集
                                              ORDER BY AM.BRANCHCOMPANY,
                                                       AM.AMCODE,
                                                       AM.AMNAME,
                                                       AM.PAYEESEQ,
                                                       AD.ADCODE,
                                                       AD.ADNAME,
                                                       STARTDATE,
                                                       ENDDATE) AMAD
                                    )) AMAD1
                     GROUP BY BRANCHCOMPANY,
                              PAYEESEQ,
                              AMCODE,
                              AMNAME,
                              ADCODE,
                              ADNAME,
                              GRP)) MINUS
      SELECT *
        FROM B_BANC_INTERNALSALESHIERARCHY) CHANGED
          ON (BBI.branchcompany_code = CHANGED.branchcompany_code AND
             BBI.AMCODE = CHANGED.AMCODE AND BBI.AMNAME = CHANGED.AMNAME AND
             BBI.ADCODE = CHANGED.ADCODE AND BBI.ADNAME = CHANGED.ADNAME AND
             BBI.STARTDATE = CHANGED.STARTDATE) WHEN MATCHED THEN
        UPDATE --表中有存在数据就更新
           SET BBI.ISNEW           = '新增', --将修改的数据标记为新增，因为查出来的数据包括了所有的历史数据，
               BBI.AM_STATUS       = CHANGED.STATUS, -- 因此只需要更新原表中的enddate
               BBI.AM_CHANGED_DATE = CHANGED.CHANGED_DATE,
               BBI.ENDDATE         = CHANGED.ENDDATE
      WHEN NOT MATCHED THEN
        INSERT -- 表中没有这条记录，插入表中
          (BBI.branchcompany_code,
           BBI.AMCODE,
           BBI.AMNAME,
           BBI.ADCODE,
           BBI.ADNAME,
           BBI.ISNEW,
           BBI.AM_STATUS,
           BBI.AM_CHANGED_DATE,
           BBI.STARTDATE,
           BBI.ENDDATE)
        VALUES
          (CHANGED.branchcompany_code,
           CHANGED.AMCODE,
           CHANGED.AMNAME,
           CHANGED.ADCODE,
           CHANGED.ADNAME,
           '新增',
           CHANGED.STATUS,
           CHANGED.CHANGED_DATE,
           CHANGED.STARTDATE,
           CHANGED.ENDDATE);
  
    COMMIT;
  END;

  --B_BANC_CompanyCode
  PROCEDURE B_BANC_COMPANY_CODE IS
  BEGIN
    DELETE FROM B_BANC_COMPANYCODE;
    COMMIT;
    INSERT INTO B_BANC_COMPANYCODE
      (POS_CODE,
       POS_NAME,
       COMPANY_CODE,
       ORIGINAL_CITY,
       ORIGINAL_CITY_NAME,
       ACTUAL_CITY,
       ACTUAL_CITY_NAME)
      SELECT PEE.PAYEEID POS_CODE,
             PAR.LASTNAME POS_NAME,
             CASE
               WHEN BU.NAME = 'Banc Shanghai' THEN
                '0986'
               WHEN BU.NAME = 'Banc Beijing' THEN
                '1186'
               WHEN BU.NAME = 'Banc Jiangsu' THEN
                '1286'
               WHEN BU.NAME = 'Banc Shenzhen' THEN
                '1086'
               WHEN BU.NAME = 'Banc Guangdong' THEN
                (CASE
                  WHEN (AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                            SYSDATE) = 'B7' OR
                       AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                            SYSDATE) = 'H7' OR
                       AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                            SYSDATE) = 'B4') AND
                       (PAR.GENERICATTRIBUTE6 = 'DG' OR
                       PAR.GENERICATTRIBUTE6 = 'JM') THEN
                   '2586'
                  WHEN PAR.GENERICATTRIBUTE6 = 'FS' THEN
                   '2686'
                  WHEN PAR.GENERICATTRIBUTE6 = 'JM' THEN
                   '2786'
                  WHEN PAR.GENERICATTRIBUTE6 = 'DG' THEN
                   '2886'
                  ELSE
                   '2586'
                END)
             END AS COMPANY_CODE, -- company code 的转换逻辑
             PAR.GENERICATTRIBUTE6 ORIGINAL_CITY,
             (SELECT CRL.DESCRIPTION
                FROM CS_CATEGORY CCT, CS_RULEELEMENT CRL
               WHERE CCT.RULEELEMENTSEQ = CRL.RULEELEMENTSEQ
                 AND CCT.REMOVEDATE > SYSDATE
                 AND CRL.REMOVEDATE > SYSDATE
                 AND CCT.ISLAST = 1
                 AND CRL.ISLAST = 1
                 AND CCT.NAME = PAR.GENERICATTRIBUTE6) AS ORIGINAL_CITY_NAME,
             CASE
               WHEN (AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                         SYSDATE) = 'B7' OR
                    AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                         SYSDATE) = 'H7' OR
                    AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                         SYSDATE) = 'B4') AND
                    (PAR.GENERICATTRIBUTE6 = 'DG' OR
                    PAR.GENERICATTRIBUTE6 = 'JM') THEN
                'GZ'
               ELSE
                PAR.GENERICATTRIBUTE6 -- PAR.GA6存放的是城市
             END ACTUAL_CITY, -- 实际所属城市的转换逻辑
             (SELECT CRL.DESCRIPTION
                FROM CS_CATEGORY CCT, CS_RULEELEMENT CRL
               WHERE CCT.RULEELEMENTSEQ = CRL.RULEELEMENTSEQ
                 AND CCT.REMOVEDATE > SYSDATE
                 AND CRL.REMOVEDATE > SYSDATE
                 AND CCT.ISLAST = 1
                 AND CRL.ISLAST = 1
                 AND CCT.NAME = (SELECT CASE
                                          WHEN (AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                                                    SYSDATE) = 'B7' OR
                                               AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                                                    SYSDATE) = 'H7' OR
                                               AIAB_ISP_INTERFACE_TABLES_PKG.AIAB_GET_CHANNEL_NAME(POS.NAME,
                                                                                                    SYSDATE) = 'B4') AND
                                               (PAR.GENERICATTRIBUTE6 = 'DG' OR
                                               PAR.GENERICATTRIBUTE6 = 'JM') THEN
                                           'GZ'
                                          ELSE
                                           PAR.GENERICATTRIBUTE6
                                        END ACTUAL_CITY
                                   FROM DUAL)) AS ACTUAL_CITY_NAME -- 根据城市代号找到城市名
        FROM CS_POSITION       POS,
             CS_TITLE          TIT,
             CS_BUSINESSUNIT   BU,
             CS_PROCESSINGUNIT PU,
             CS_PARTICIPANT    PAR,
             CS_PAYEE          PEE
       WHERE 1 = 1
         AND POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
         AND POS.PAYEESEQ = PEE.PAYEESEQ
         AND PEE.BUSINESSUNITMAP = BU.MASK
         AND BU.PROCESSINGUNITSEQ = PU.PROCESSINGUNITSEQ
         AND PAR.PAYEESEQ = PEE.PAYEESEQ
         AND PU.NAME = 'PU-Banc'
         AND TIT.NAME = 'POS'
         AND POS.REMOVEDATE > SYSDATE
         AND POS.EFFECTIVESTARTDATE <= SYSDATE
         AND POS.EFFECTIVEENDDATE > SYSDATE
         AND POS.ISLAST = 1
         AND TIT.ISLAST = 1
         AND TIT.REMOVEDATE > SYSDATE
         AND TIT.EFFECTIVESTARTDATE <= SYSDATE
         AND TIT.EFFECTIVEENDDATE > SYSDATE
         AND PAR.REMOVEDATE > SYSDATE
         AND PAR.EFFECTIVESTARTDATE <= SYSDATE
         AND PAR.EFFECTIVEENDDATE > SYSDATE
         AND PEE.REMOVEDATE > SYSDATE
         AND PEE.EFFECTIVESTARTDATE <= SYSDATE
         AND PEE.EFFECTIVEENDDATE > SYSDATE
         AND PEE.ISLAST = 1
         AND PAR.ISLAST = 1;
    COMMIT;
  END;

  -- 这个存储过程用来调用上面4个存储过程
  -- 更新4张接口表数据
  -- 每天都会跑这个存储过程
  PROCEDURE EXTRACT_DATA IS
  BEGIN
    B_BANC_BANK_HIERARCHY;
    B_BANC_POLICY_AM_RELATIONSHIP;
    INTERNAL_SALES_HIERARCHY;
    B_BANC_COMPANY_CODE;
    COMMIT;
  END;

END;
/
