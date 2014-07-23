PROCEDURE z(P_MANAGERSEQ IN NUMBER, 
                     P_PERIODENDDATE IN DATE,
                     V_MANAGERNAME VARCHAR2(255),
                     V_MANAGERCODE VARCHAR2(255)
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