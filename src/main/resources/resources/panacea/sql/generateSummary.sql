delete from @results_schema.pnc_study_summary_path where study_id = @studyId and source_id = @sourceId;

insert into @results_schema.pnc_study_summary_path (pnc_stdy_smry_id, study_id, source_id, tx_path_parent_key, tx_stg_cmb, tx_stg_cmb_pth, tx_seq, tx_stg_cnt, tx_stg_avg_dr, tx_stg_avg_gap, tx_rslt_version, tx_avg_frm_strt)
select seq_pnc_stdy_smry.nextval, @studyId, @sourceId, null, aggregatePath.combo_ids, aggregatePath.combo_seq, aggregatePath.tx_seq, aggregatePath.patientCount, aggregatePath.averageDurationDays, aggregatePath.averageGapDays, aggregatePath.result_version, aggregatePath.avgFrmCohortStart 
from
--  (select combo_ids combo_ids, combo_seq combo_seq, tx_seq tx_seq, count(*) patientCount, avg(combo_duration) averageDurationDays, avg(gap_days) averageGapDays, result_version result_version from #_PNC_TMP_CMB_SQ_CT ptTxPath
   (select ptTxPath.combo_ids combo_ids, ptTxPath.combo_seq combo_seq, ptTxPath.tx_seq tx_seq, count(*) patientCount, avg(ptTxPath.combo_duration) averageDurationDays, avg(ptTxPath.gap_days) averageGapDays, ptTxPath.result_version result_version,
--    where result_version = 1
	avg(ptTxPath.start_date - co.cohort_start_date + 1) avgFrmCohortStart
  		from #_PNC_TMP_CMB_SQ_CT ptTxPath
  		join @ohdsi_schema.cohort co
  		on co.subject_id = ptTxPath.person_id
  		and co.cohort_definition_id = (select cohort_definition_id
    from @results_schema.panacea_study where study_id = @studyId)
    group by ptTxPath.combo_ids, ptTxPath.combo_seq, ptTxPath.tx_seq, ptTxPath.result_version) aggregatePath;

-- version = 1
merge into @results_schema.pnc_study_summary_path  m
using
  (
	select pathsum.rowid as the_rowid, parentpath.pnc_stdy_smry_id as parentKey, updateParentPath.parentPath pPath, 
    parentPath.tx_stg_cnt parentCount, pathSum.tx_stg_cnt childCount, NVL(ROUND(pathSum.tx_stg_cnt/parentPath.tx_stg_cnt * 100,2),0) percentage
    from @results_schema.pnc_study_summary_path pathSum
    join (select rowid, SUBSTR(tx_stg_cmb_pth , 0 , length(tx_stg_cmb_pth) - length(tx_stg_cmb) - 1 ) as parentPath
    from @results_schema.pnc_study_summary_path
    where study_id = @studyId and source_id = @sourceId and tx_rslt_version = 1 
    ) updateParentPath
    on updateParentPath.rowid = pathSum.rowid
    join @results_schema.pnc_study_summary_path parentPath
    on updateParentPath.parentPath = parentPath.tx_stg_cmb_pth
    and parentPath.study_id = @studyId
    and parentPath.tx_rslt_version = 1
    and parentPath.source_id = @sourceId
    where pathSum.study_id = @studyId and pathSum.source_id = @sourceId
    and pathSum.tx_rslt_version = 1 
    and parentPath.tx_rslt_version = 1 
    group by pathsum.rowid, parentpath.pnc_stdy_smry_id, updateParentPath.parentPath, parentPath.tx_stg_cnt, pathSum.tx_stg_cnt
  ) m1
  on
  (
     m.rowid = m1.the_rowid
  )
  WHEN MATCHED then update set m.tx_path_parent_key = m1.parentKey, m.tx_stg_percentage = m1.percentage;


merge into @results_schema.pnc_study_summary_path  m
using
  (
    select pathsum.rowid as the_rowid, rootCount.totalRootCount,
    rootCount.totalRootCount parentCount, pathSum.tx_stg_cnt childCount, NVL(ROUND(pathSum.tx_stg_cnt/rootCount.totalRootCount * 100,2),0) percentage
    from @results_schema.pnc_study_summary_path pathSum, (select sum(tx_stg_cnt) totalRootCount from @results_schema.pnc_study_summary_path
    where tx_path_parent_key is null and tx_rslt_version = 1
      and study_id = @studyId and source_id = @sourceId
      ) rootCount
    where tx_path_parent_key is null
    and pathSum.study_id = @studyId and pathSum.source_id = @sourceId
    and pathsum.tx_rslt_version = 1
  ) m1
  on
  (
     m.rowid = m1.the_rowid
  )
  WHEN MATCHED then update set m.tx_stg_percentage = m1.percentage;

-- version = 2
merge into @results_schema.pnc_study_summary_path  m
using
  (
	select pathsum.rowid as the_rowid, parentpath.pnc_stdy_smry_id as parentKey, updateParentPath.parentPath pPath, 
    parentPath.tx_stg_cnt parentCount, pathSum.tx_stg_cnt childCount, NVL(ROUND(pathSum.tx_stg_cnt/parentPath.tx_stg_cnt * 100,2),0) percentage
    from @results_schema.pnc_study_summary_path pathSum
    join (select rowid, SUBSTR(tx_stg_cmb_pth , 0 , length(tx_stg_cmb_pth) - length(tx_stg_cmb) - 1 ) as parentPath
    from @results_schema.pnc_study_summary_path
    where study_id = @studyId and source_id = @sourceId and tx_rslt_version = 2 
    ) updateParentPath
    on updateParentPath.rowid = pathSum.rowid
    join @results_schema.pnc_study_summary_path parentPath
    on updateParentPath.parentPath = parentPath.tx_stg_cmb_pth
    and parentPath.study_id = @studyId
    and parentPath.tx_rslt_version = 2
    and parentPath.source_id = @sourceId
    where pathSum.study_id = @studyId and pathSum.source_id = @sourceId
    and pathSum.tx_rslt_version = 2 
    and parentPath.tx_rslt_version = 2 
    group by pathsum.rowid, parentpath.pnc_stdy_smry_id, updateParentPath.parentPath, parentPath.tx_stg_cnt, pathSum.tx_stg_cnt
  ) m1
  on
  (
     m.rowid = m1.the_rowid
  )
  WHEN MATCHED then update set m.tx_path_parent_key = m1.parentKey, m.tx_stg_percentage = m1.percentage;

merge into @results_schema.pnc_study_summary_path  m
using
  (
    select pathsum.rowid as the_rowid, rootCount.totalRootCount,
    rootCount.totalRootCount parentCount, pathSum.tx_stg_cnt childCount, NVL(ROUND(pathSum.tx_stg_cnt/rootCount.totalRootCount * 100,2),0) percentage
    from @results_schema.pnc_study_summary_path pathSum, (select sum(tx_stg_cnt) totalRootCount from @results_schema.pnc_study_summary_path
    where tx_path_parent_key is null and tx_rslt_version = 2
      and study_id = @studyId and source_id = @sourceId
      ) rootCount
    where tx_path_parent_key is null
    and pathSum.study_id = @studyId and pathSum.source_id = @sourceId
    and pathsum.tx_rslt_version = 2
  ) m1
  on
  (
     m.rowid = m1.the_rowid
  )
  WHEN MATCHED then update set m.tx_stg_percentage = m1.percentage;

delete from @results_schema.pnc_study_summary where study_id = @studyId and source_id = @sourceId;

---------------collapse/merge multiple rows to concatenate strings (JSON string for conceptsArrary and conceptsName) ------
IF OBJECT_ID('tempdb..#_pnc_smry_msql_cmb', 'U') IS NOT NULL
  DROP TABLE #_pnc_smry_msql_cmb;
 
CREATE TABLE #_pnc_smry_msql_cmb
(
    pnc_tx_stg_cmb_id int,
    concept_ids varchar(500),
    conceptsArray varchar(4000),
	conceptsName varchar(4000)
-- TODO: test this (4000 should be enough for one combo)
--    conceptsArray text,
--	conceptsName text    
);

insert into #_pnc_smry_msql_cmb (pnc_tx_stg_cmb_id, concept_ids, conceptsArray, conceptsName)
select comb_id, concept_ids, conceptsArray, conceptsName 
from
(
	select comb.pnc_tx_stg_cmb_id comb_id,
    wm_concat(combMap.concept_id) concept_ids,
    '[' || wm_concat('{"innerConceptName":' || '"' || combMap.concept_name  || '"' || 
    ',"innerConceptId":' || combMap.concept_id || '}') || ']' conceptsArray,
    wm_concat(combMap.concept_name) conceptsName
    from @results_schema.pnc_tx_stage_combination comb
    join @results_schema.pnc_tx_stage_combination_map combMap 
    on comb.pnc_tx_stg_cmb_id = combmap.pnc_tx_stg_cmb_id
    where comb.study_id = @studyId
    group by comb.pnc_tx_stg_cmb_id
) studyCombo;

-----------------generate rows of JSON (based on hierarchical data, each path is a row) insert into temp table----------------------
IF OBJECT_ID('tempdb..#_pnc_indv_jsn', 'U') IS NOT NULL
  DROP TABLE #_pnc_indv_jsn;
 
CREATE TABLE #_pnc_indv_jsn
(
    rnum float,
    table_row_id int,
	rslt_version int,
	JSON varchar(4000)
);

-------------------------------version 1 insert into temp table----------------------------------------------
insert into #_pnc_indv_jsn(rnum, table_row_id, rslt_version, JSON)
select rnum, table_row_id, rslt_version, JSON 
from
(
select allRoots.rnum rnum, 1 table_row_id, 1 rslt_version,
CASE 
    WHEN rnum = 1 THEN '{"comboId": "root","children": [' || substr(JSON_SNIPPET, 2, length(JSON_SNIPPET))
    ELSE JSON_SNIPPET
END
as JSON
from 
(WITH connect_by_query as (
      select  
       individualPathNoParentConcepts.rnum                                as rnum
      ,individualPathNoParentConcepts.combo_id                            as combo_id
      ,individualPathNoParentConcepts.current_path                        as current_path
      ,individualPathNoParentConcepts.path_seq                            as path_seq
      ,individualPathNoParentConcepts.avg_duration                        as avg_duration
      ,individualPathNoParentConcepts.pt_count                            as pt_count
      ,individualPathNoParentConcepts.pt_percentage                       as pt_percentage
      ,individualPathNoParentConcepts.concept_names                       as concept_names
      ,individualPathNoParentConcepts.combo_concepts                      as combo_concepts
      ,individualPathNoParentConcepts.Lvl                                 as Lvl
    , parentConcepts.conceptsName                                         as parent_concept_names
    , parentConcepts.conceptsArray                                        as parent_combo_concepts
    from 
    (
  	SELECT 
     ROWNUM                               as rnum
    ,tx_stg_cmb                           as combo_id
    ,tx_stg_cmb_pth                       as current_path
    ,tx_seq                               as path_seq
    ,tx_stg_avg_dr                        as avg_duration
    ,tx_stg_cnt                           as pt_count
    ,tx_stg_percentage                    as pt_percentage
    ,concepts.conceptsName                as concept_names
    ,concepts.conceptsArray               as combo_concepts
    ,LEVEL                                as Lvl
    ,pnc_stdy_smry_id                     as self_id
    ,tx_path_parent_key                   as parent_id
    ,prior tx_stg_cmb                     as parent_comb
  FROM @results_schema.pnc_study_summary_path smry
  join #_pnc_smry_msql_cmb concepts
  on concepts.pnc_tx_stg_cmb_id = smry.tx_stg_cmb
  START WITH pnc_stdy_smry_id in (select pnc_stdy_smry_id from @results_schema.pnc_study_summary_path
        where 
        study_id = @studyId
        and source_id = @sourceId
        and tx_rslt_version = 1
        and tx_path_parent_key is null)
  CONNECT BY PRIOR pnc_stdy_smry_id = tx_path_parent_key
  ORDER SIBLINGS BY pnc_stdy_smry_id
  ) individualPathNoParentConcepts
  left join #_pnc_smry_msql_cmb parentConcepts
  on parentConcepts.pnc_tx_stg_cmb_id = individualPathNoParentConcepts.parent_comb
  order by rnum
)
select 
  rnum rnum,
  CASE 
    WHEN Lvl = 1 THEN ',{'
    WHEN Lvl - LAG(Lvl) OVER (order by rnum) = 1 THEN ',"children" : [{' 
    ELSE ',{' 
  END 
  || ' "comboId" : ' || combo_id || ' '
  || ' ,"conceptName" : "' || concept_names || '" '  
  || ' ,"patientCount" : ' || pt_count || ' '
  || ' ,"percentage" : "' || pt_percentage || '" '  
  || ' ,"avgDuration" : ' || avg_duration || ' '
  || ',"concepts" : ' || combo_concepts 
  || CASE WHEN Lvl > 1 THEN    
        ',"parentConcept": { "parentConceptName": "' || parent_concept_names || '", '  
        || '"parentConcepts":' || parent_combo_concepts   || '}'
     ELSE  NULL
     END 
  || CASE WHEN LEAD(Lvl, 1, 1) OVER (order by rnum) - Lvl <= 0 
     THEN '}' || rpad( ' ', 1+ (-2 * (LEAD(Lvl, 1, 1) OVER (order by rnum) - Lvl)), ']}' )
     ELSE NULL 
  END as JSON_SNIPPET
from connect_by_query
order by rnum) allRoots
union all
select rnum as rnum, table_row_id as table_row_id, 1 rslt_version, ']}' as JSON from (
	select distinct 1000000000 as rnum, 1 as table_row_id from @results_schema.pnc_study_summary_path)
--	select distinct 1/0F as rnum, 1 as table_row_id from @results_schema.pnc_study_summary_path)
--  select distinct 1000000 as rnum, 1 as table_row_id from pnc_study_summary_path)
--sql render remove "dual", so I have to trick by using a real table(pnc_study_summary_path) select 1000000  as rnum, 1 as table_row_id, to_clob(']}') as JSON from dual
) individualJsonRows;

-------------------------------------version 1 into summary table-------------------------------------
insert into @results_schema.pnc_study_summary (study_id, source_id, study_results)
select @studyId, @sourceId, JSON from (
	select individualResult.table_row_id,
		DBMS_XMLGEN.CONVERT (
     	EXTRACT(
       		xmltype('<?xml version="1.0"?><document>' ||
               XMLAGG(
                 XMLTYPE('<V>' || DBMS_XMLGEN.CONVERT(JSON)|| '</V>')
                 order by rnum).getclobval() || '</document>'),
               '/document/V/text()').getclobval(),1) AS JSON
	from (select rnum, table_row_id, rslt_version, JSON
		from #_pnc_indv_jsn t1
		where t1.rslt_version = 1
	) individualResult
	group by individualResult.table_row_id
) mergeJsonRowsTable;

------------------try unique path here-----------------
IF OBJECT_ID('tempdb..#_pnc_unq_trtmt', 'U') IS NOT NULL
  DROP TABLE #_pnc_unq_trtmt;

CREATE TABLE #_pnc_unq_trtmt
(
    rnum float,
    pnc_stdy_smry_id int,
  	rslt_version int,
    path_cmb_ids varchar(800),
    path_unique_treatment varchar(4000)
);


insert into #_pnc_unq_trtmt(rnum, pnc_stdy_smry_id, path_cmb_ids)
select rnum, pnc_stdy_smry_id, modified_path
from (
WITH t1(combo_id, current_path, pnc_stdy_smry_id, parent_key, modified_path, Lvl, depthOrder) AS (
        SELECT 
          tx_stg_cmb                            as combo_id
          ,tx_stg_cmb_pth                       as current_path
          ,pnc_stdy_smry_id                     as pnc_stdy_smry_id
          ,tx_path_parent_key                   as parent_key
          ,tx_stg_cmb                           as modified_path
          ,1                                    as Lvl
          ,pnc_stdy_smry_id||''                 as depthOrder
          FROM   @results_schema.pnc_study_summary_path
  		WHERE pnc_stdy_smry_id in (select pnc_stdy_smry_id from @results_schema.pnc_study_summary_path
        where 
	        study_id = @studyId
    	    and source_id = @sourceId
        	and tx_rslt_version = 2
	        and tx_path_parent_key is null)
        UNION ALL
        SELECT 
          t2.tx_stg_cmb                           as combo_id
          ,t2.tx_stg_cmb_pth                       as current_path
          ,t2.pnc_stdy_smry_id                     as pnc_stdy_smry_id
          ,t2.tx_path_parent_key                   as parent_key
          ,modified_path||'>'||t2.tx_stg_cmb       as modified_path
          ,lvl+1                                as Lvl
          ,depthOrder||'.'||t2.pnc_stdy_smry_id as depthOrder
        FROM    @results_schema.pnc_study_summary_path t2, t1
        WHERE  t2.tx_path_parent_key = t1.pnc_stdy_smry_id
      )
      SELECT row_number() over(order by depthOrder) as rnum, combo_id, modified_path, lvl, current_path, pnc_stdy_smry_id, parent_key, depthOrder
      FROM   t1
order by depthOrder
);

--update path_unique_treatment for current path unit concpetIds
merge into #_pnc_unq_trtmt m
using
(
WITH t1(combo_id, current_path, pnc_stdy_smry_id, parent_key, modified_path, modified_concepts, Lvl, depthOrder) AS (
        SELECT 
          tx_stg_cmb                            as combo_id
          ,tx_stg_cmb_pth                       as current_path
          ,pnc_stdy_smry_id                     as pnc_stdy_smry_id
          ,tx_path_parent_key                   as parent_key
          ,tx_stg_cmb                           as modified_path
          ,comb.concept_ids                     as modified_concepts
          ,1                                    as Lvl
          ,pnc_stdy_smry_id||''                 as depthOrder
          FROM @results_schema.pnc_study_summary_path rootPath
          join #_pnc_smry_msql_cmb comb
          on rootPath.tx_stg_cmb = comb.pnc_tx_stg_cmb_id
  		WHERE pnc_stdy_smry_id in (select pnc_stdy_smry_id from @results_schema.pnc_study_summary_path
        where 
	        study_id = @studyId
    	    and source_id = @sourceId
        	and tx_rslt_version = 2
	        and tx_path_parent_key is null)
        UNION ALL
        SELECT 
          t2.tx_stg_cmb                           as combo_id
          ,t2.tx_stg_cmb_pth                       as current_path
          ,t2.pnc_stdy_smry_id                     as pnc_stdy_smry_id
          ,t2.tx_path_parent_key                   as parent_key
          ,modified_path||'>'||t2.tx_stg_cmb       as modified_path
--this case clause simplify caltulation of duplicate concept_ids by just assert if concept_ids string already in parents ids ',id1,id2,id3,'
--may help minimize by ordering the ids in #_pnc_smry_msql_cmb.concept_ids
          ,
          CASE 
		     WHEN instr(modified_concepts, ',' || comb.concept_ids || ',') > 0 THEN modified_concepts
    		 ELSE modified_concepts||','||comb.concept_ids
		  END
												as modified_concepts
          ,lvl+1                                as Lvl
          ,depthOrder||'.'||t2.pnc_stdy_smry_id as depthOrder
        FROM (@results_schema.pnc_study_summary_path t2
        join #_pnc_smry_msql_cmb comb
        on t2.tx_stg_cmb = comb.pnc_tx_stg_cmb_id), t1
        WHERE  t2.tx_path_parent_key = t1.pnc_stdy_smry_id
      )
      SELECT row_number() over(order by depthOrder) as rnum, combo_id, modified_path, modified_concepts, lvl, current_path, pnc_stdy_smry_id, parent_key, depthOrder
      FROM   t1
order by depthOrder
) m1
on
(
  m1.pnc_stdy_smry_id = m.pnc_stdy_smry_id
)
WHEN MATCHED then update set m.path_unique_treatment = m1.modified_concepts;


IF OBJECT_ID('tempdb..#_pnc_unq_pth_id', 'U') IS NOT NULL
  DROP TABLE #_pnc_unq_pth_id;

CREATE TABLE #_pnc_unq_pth_id
(
    pnc_tx_smry_id int,
    concept_id int,
    concept_order int,
    conceptsName varchar(1000),
    conceptsArray varchar(1500)
);


--split conceptIds with "," from #_pnc_unq_trtmt per smry_id and insert order by lastPos (which is used as the order of the concepts in the path)
insert into #_pnc_unq_pth_id (pnc_tx_smry_id, concept_id, concept_order)
select smry_id, ids, lastPos from
    (WITH splitter_cte(smry_id, origin, pos, lastPos) AS (
      SELECT 
        pnc_stdy_smry_id smry_id,
        path_unique_treatment as origin,
        instr(path_unique_treatment, ',') as pos, 
        0 as lastPos
      from #_pnc_unq_trtmt
      UNION ALL
      SELECT 
        smry_id as smry_id,
        origin as origin, 
        instr(origin, ',', pos + 1) as pos, 
        pos as lastPos
      FROM splitter_cte
      WHERE pos > 0
    )
    SELECT 
      smry_id, 
      origin, 
      SUBSTR(origin, lastPos + 1,
        case when pos = 0 then 80000
        else pos - lastPos -1 end) as ids,
      pos,
      lastPos
    FROM splitter_cte
    order by smry_id, lastPos) coneptIds;


--delete duplicate concept_id per smry_id in the path if it's not the first on in the path by min(concept_order)
delete from #_pnc_unq_pth_id 
where rowid in (select conceptIds.rowid from #_pnc_unq_pth_id conceptIds, 
  (select pnc_tx_smry_id, concept_id, min(concept_order) as concept_order
    from #_pnc_unq_pth_id
    group by pnc_tx_smry_id, concept_id
  ) uniqueIds
where
  conceptIds.pnc_tx_smry_id = uniqueIds.pnc_tx_smry_id
  and conceptIds.concept_id = uniqueIds.concept_id
  and conceptIds.concept_order != uniqueIds.concept_order
);

--update conceptsArray and conceptName JSON by join concept table
merge into #_pnc_unq_pth_id m
using
(
	select path.pnc_tx_smry_id,
    '[' || wm_concat('{"innerConceptName":' || '"' || concepts.concept_name  || '"' || 
    ',"innerConceptId":' || concepts.concept_id || '}') || ']' conceptsArray,
    wm_concat(concepts.concept_name) conceptsName
    from #_pnc_unq_pth_id path
    join @cdm_schema.concept concepts
    on path.concept_id = concepts.concept_id
    group by path.pnc_tx_smry_id
) m1
on
(
  m.pnc_tx_smry_id = m1.pnc_tx_smry_id
)
WHEN MATCHED then update set m.conceptsArray = m1.conceptsArray,
 m.conceptsName = m1.conceptsName;

--delete duplicat smry_id rows (now we have smry_id with it's unique concepts conceptsArray and conceptsName)
delete from #_pnc_unq_pth_id 
where rowid in (select conceptIds.rowid from #_pnc_unq_pth_id conceptIds, 
  (select pnc_tx_smry_id, min(concept_order) as concept_order
    from #_pnc_unq_pth_id
    group by pnc_tx_smry_id
  ) uniqueIds
where
  conceptIds.pnc_tx_smry_id = uniqueIds.pnc_tx_smry_id
  and conceptIds.concept_order != uniqueIds.concept_order
);

-------------------------------version 2 insert into temp table----------------------------------------------
insert into #_pnc_indv_jsn(rnum, table_row_id, rslt_version, JSON)
select rnum, table_row_id, rslt_version, JSON 
from
(
select allRoots.rnum rnum, 1 table_row_id, 2 rslt_version,
CASE 
    WHEN rnum = 1 THEN '{"comboId": "root","children": [' || substr(JSON_SNIPPET, 2, length(JSON_SNIPPET))
    ELSE JSON_SNIPPET
END
as JSON
from 
(WITH connect_by_query as (
select  
       individualPathNoParentConcepts.rnum                                as rnum
      ,individualPathNoParentConcepts.combo_id                            as combo_id
      ,individualPathNoParentConcepts.current_path                        as current_path
      ,individualPathNoParentConcepts.path_seq                            as path_seq
      ,individualPathNoParentConcepts.avg_duration                        as avg_duration
	  ,individualPathNoParentConcepts.avg_gap                       	  as avg_gap
      ,individualPathNoParentConcepts.gap_pcnt							  as gap_pcnt
      ,individualPathNoParentConcepts.pt_count                            as pt_count
      ,individualPathNoParentConcepts.pt_percentage                       as pt_percentage
      ,individualPathNoParentConcepts.concept_names                       as concept_names
      ,individualPathNoParentConcepts.combo_concepts                      as combo_concepts
      ,individualPathNoParentConcepts.Lvl                                 as Lvl
     ,parentConcepts.conceptsName                                         as parent_concept_names
     ,parentConcepts.conceptsArray                                        as parent_combo_concepts
     ,individualPathNoParentConcepts.uniqueConceptsName					  as uniqueConceptsName
     ,individualPathNoParentConcepts.uniqueConceptsArray				  as uniqueConceptsArray
     ,individualPathNoParentConcepts.daysFromStart						  as daysFromStart
    from 
    (
  	SELECT 
     ROWNUM                               as rnum
    ,tx_stg_cmb                           as combo_id
    ,tx_stg_cmb_pth                       as current_path
    ,tx_seq                               as path_seq
    ,tx_stg_avg_dr                        as avg_duration
    ,tx_stg_avg_gap                       as avg_gap
    ,NVL(ROUND(tx_stg_avg_gap/tx_stg_avg_dr * 100,2),0)   as gap_pcnt
    ,tx_stg_cnt                           as pt_count
    ,tx_stg_percentage                    as pt_percentage
    ,concepts.conceptsName                as concept_names
    ,concepts.conceptsArray               as combo_concepts
    ,LEVEL                                as Lvl
    ,pnc_stdy_smry_id                     as self_id
    ,tx_path_parent_key                   as parent_id
    ,prior tx_stg_cmb                     as parent_comb
    ,uniqueConcepts.conceptsName		  as uniqueConceptsName
    ,uniqueConcepts.conceptsArray		  as uniqueConceptsArray
    ,smry.tx_avg_frm_strt				  as daysFromStart
  FROM @results_schema.pnc_study_summary_path smry
  join #_pnc_smry_msql_cmb concepts
  on concepts.pnc_tx_stg_cmb_id = smry.tx_stg_cmb
  join (select pnc_tx_smry_id, conceptsName, conceptsArray from #_pnc_unq_pth_id) uniqueConcepts
  on uniqueConcepts.pnc_tx_smry_id = smry.pnc_stdy_smry_id
  START WITH pnc_stdy_smry_id in (select pnc_stdy_smry_id from @results_schema.pnc_study_summary_path
        where 
        study_id = @studyId
        and source_id = @sourceId
        and tx_rslt_version = 2
        and tx_path_parent_key is null)
  CONNECT BY PRIOR pnc_stdy_smry_id = tx_path_parent_key
  ORDER SIBLINGS BY pnc_stdy_smry_id
  ) individualPathNoParentConcepts
  left join #_pnc_smry_msql_cmb parentConcepts
  on parentConcepts.pnc_tx_stg_cmb_id = individualPathNoParentConcepts.parent_comb
  order by rnum
)
select 
  rnum rnum,
  CASE 
    WHEN Lvl = 1 THEN ',{'
    WHEN Lvl - LAG(Lvl) OVER (order by rnum) = 1 THEN ',"children" : [{' 
    ELSE ',{' 
  END
  || ' "comboId" : ' || combo_id || ' '
  || ' ,"conceptName" : "' || concept_names || '" '  
  || ' ,"patientCount" : ' || pt_count || ' '
  || ' ,"percentage" : "' || pt_percentage || '" '  
  || ' ,"avgDuration" : ' || avg_duration || ' '
  || ' ,"avgGapDay" : ' || avg_gap || ' '
  || ' ,"gapPercent" : "' || gap_pcnt || '" '
  || ' ,"daysFromCohortStart" : ' || daysFromStart || ' '
  || ',"concepts" : ' || combo_concepts 
  || ',"uniqueConceptsName" : "' || uniqueConceptsName || '" '
  || ',"uniqueConceptsArray" : ' || uniqueConceptsArray
  || CASE WHEN Lvl > 1 THEN    
        ',"parentConcept": { "parentConceptName": "' || parent_concept_names || '", '  
        || '"parentConcepts":' || parent_combo_concepts   || '}'
     ELSE  NULL
     END 
  || CASE WHEN LEAD(Lvl, 1, 1) OVER (order by rnum) - Lvl <= 0 
     THEN '}' || rpad( ' ', 1+ (-2 * (LEAD(Lvl, 1, 1) OVER (order by rnum) - Lvl)), ']}' )
     ELSE NULL 
  END as JSON_SNIPPET
from connect_by_query
order by rnum) allRoots
union all
select rnum as rnum, table_row_id as table_row_id, 2 rslt_version, ']}' as JSON from (
	select distinct 1000000000 as rnum, 1 as table_row_id from @results_schema.pnc_study_summary_path)
--	select distinct 1/0F as rnum, 1 as table_row_id from @results_schema.pnc_study_summary_path)
) individualJsonRows;

----------------------------------version 2 into summary table
update @results_schema.pnc_study_summary set study_results_2 =
(select JSON from (
	select individualResult.table_row_id,
		DBMS_XMLGEN.CONVERT (
     	EXTRACT(
       		xmltype('<?xml version="1.0"?><document>' ||
               XMLAGG(
                 XMLTYPE('<V>' || DBMS_XMLGEN.CONVERT(JSON)|| '</V>')
                 order by rnum).getclobval() || '</document>'),
               '/document/V/text()').getclobval(),1) AS JSON
	from (select rnum, table_row_id, rslt_version, JSON
		from #_pnc_indv_jsn t1
		where t1.rslt_version = 2
	) individualResult
	group by individualResult.table_row_id
) mergeJsonRowsTable), 
last_update_time = CURRENT_TIMESTAMP 
where study_id = @studyId and source_id = @sourceId;
