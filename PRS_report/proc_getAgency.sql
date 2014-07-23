CREATE OR REPLACE PROCEDURE GetAgency(P_AGENTCODE IN Varchar2,
                                      P_PERIODENDDATE IN DATE,
                                      V_AGENCYNAME OUT VARCHAR2,
                                      V_AGENCYCODE OUT VARCHAR2)
--return varchar2
is
   --Result VARCHAR2(255);
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
