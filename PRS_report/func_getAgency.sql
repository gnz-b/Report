create or replace function GetAgency(P_AGENTCODE Varchar2, 
                                     P_PERIODENDDATE DATE) 
return varchar2 is
   Result varchar2;
   V_TITLE VARCHAR2;
   V_MANAGERSEQ NUMBER;
   V_FROM_DM NUMBER;
   V_AGENCYNAME VARCHAR2;
   V_AGENCYCODE VARCHAR2;
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
     AND   POSRT.NAME = 'ALC_Roll'
  
  select posa.name ,
         par.PREFIX || par.FIRSTNAME || par.MIDDLENAME|| par.LASTNAME || par.SUFFIX 
         INTO 
                    V_AGENCYCODE, 
                    V_AGENCYNAME
         from cs_participant par,
              cs_position    posa,
              aia_payee_infor aas
                                                where par.payeeseq =
                                                      posa.payeeseq
                                                  and par.removedate =
                                                      C_REMOVEDATE
                                                  and posa.removedate =
                                                      C_REMOVEDATE
                                                  and par.effectivestartdate <=
                                                      V_PERIODENDDATE - 1
                                                  and par.effectiveenddate >
                                                      V_PERIODENDDATE - 1
                                                  and posa.effectivestartdate <=
                                                      V_PERIODENDDATE - 1
                                                  and posa.effectiveenddate >
                                                      V_PERIODENDDATE - 1
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
                                                              V_FROM_DM,
                                                              AAS.POSITIONSEQ))
                                                      and AAS.Removedate = C_REMOVEDATE        
                                                      and AAS.Positiontitle like '%Tied Agency%'
                                                      AND AAS.Participantid = P_AGENTCODE;
                                                      
      select posa.name,
             par.PREFIX || par.FIRSTNAME || par.MIDDLENAME|| par.LASTNAME || par.SUFFIX
             into
                        V_AGENCYCODE, 
                        V_AGENCYNAME
             from cs_participant  par,
                  cs_position     posa
                  aia_payee_infor aas
             where par.payeeseq = posa.payeeseq
             and par.removedate = C_REMOVEDATE
             and posa.removedate = C_REMOVEDATE
             and par.effectivestartdate <= V_PERIODENDDATE - 1
             and par.effectiveenddate > V_PERIODENDDATE -1
             and posa.effectivestartdate <= V_PERIODENDDATE -1
             and posa.effectiveenddate >= V_PERIODENDDATE
             and posa.ruleelementownerseq = AAS.MANAGERSEQ
             AND ROWNUM = 1
             and AAS.Removedate = C_REMOVEDATE
             and aas.effectivestartdate <= V_PERIODENDDATE - 1
             and aas.effectiveenddate > V_PERIODENDDATE - 1 
             AND AAS.POSITIONTITLE IN(  'Broker-Agent',
                                        'Broker-Leader'
                                        'IFA-FA Leader',
                                        'IFA-FAR')
             and aas.participantid = P_PERIODENDDATE                                               
       --dbms_output.put_line(V_AGENCYCODE||'-'||V_AGENCYNAME);
     
  return(Result);
end GetAgency;