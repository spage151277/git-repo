###########################################################################################
Scripts related to TEMP TABLESPACE

To check instance-wise total allocated, total used TEMP for both rac and non-rac

set lines 152
col FreeSpaceGB format 999.999
col UsedSpaceGB format 999.999
col TotalSpaceGB format 999.999
col host_name format a30
col tablespace_name format a30
select tablespace_name,
(free_blocks*8)/1024/1024 FreeSpaceGB,
(used_blocks*8)/1024/1024 UsedSpaceGB,
(total_blocks*8)/1024/1024 TotalSpaceGB,
i.instance_name,i.host_name
from gv$sort_segment ss,gv$instance i where ss.tablespace_name in (select tablespace_name from dba_tablespaces where contents='TEMPORARY') and
i.inst_id=ss.inst_id;

###########################################################################################

Total Used and Total Free Blocks

select inst_id, tablespace_name, total_blocks, used_blocks, free_blocks  from gv$sort_segment;

###########################################################################################
Another Query to check TEMP USAGE

col name for a20
SELECT d.status "Status", d.tablespace_name "Name", d.contents "Type", d.extent_management
"ExtManag",
TO_CHAR(NVL(a.bytes / 1024 / 1024, 0),'99,999,990.900') "Size (M)", TO_CHAR(NVL(t.bytes,
0)/1024/1024,'99999,999.999') ||'/'||TO_CHAR(NVL(a.bytes/1024/1024, 0),'99999,999.999') "Used (M)",
TO_CHAR(NVL(t.bytes / a.bytes * 100, 0), '990.00') "Used %"
FROM sys.dba_tablespaces d, (select tablespace_name, sum(bytes) bytes from dba_temp_files group by
tablespace_name) a,
(select tablespace_name, sum(bytes_cached) bytes from
v$temp_extent_pool group by tablespace_name) t
WHERE d.tablespace_name = a.tablespace_name(+) AND d.tablespace_name = t.tablespace_name(+)
AND d.extent_management like 'LOCAL' AND d.contents like 'TEMPORARY';

###########################################################################################
Temporary Tablespace groups

SELECT * FROM DATABASE_PROPERTIES where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE';

###########################################################################################

select tablespace_name,contents from dba_tablespaces where tablespace_name like '%TEMP%';

select * from dba_tablespace_groups;
###########################################################################################
Block wise Check

select TABLESPACE_NAME, TOTAL_BLOCKS, USED_BLOCKS, MAX_USED_BLOCKS, MAX_SORT_BLOCKS, FREE_BLOCKS from V$SORT_SEGMENT;
###########################################################################################

select sum(free_blocks) from gv$sort_segment where tablespace_name = 'TEMP';

###########################################################################################
To Check Percentage Usage of Temp Tablespace

select (s.tot_used_blocks/f.total_blocks)*100 as "percent used"
from (select sum(used_blocks) tot_used_blocks
from v$sort_segment where tablespace_name='TEMP') s,
(select sum(blocks) total_blocks
from dba_temp_files where tablespace_name='TEMP') f;


###########################################################################################
To check Used Extents ,Free Extents available in Temp Tablespace

SELECT tablespace_name, extent_size, total_extents, used_extents,free_extents, max_used_size FROM v$sort_segment;

###########################################################################################


To list all tempfiles of Temp Tablespace

col file_name for a45
select tablespace_name,file_name,bytes/1024/1024,maxbytes/1024/1024,autoextensible from dba_temp_files  order by file_name;

###########################################################################################
SELECT d.tablespace_name tablespace , d.file_name filename, d.file_id fl_id, d.bytes/1024/1024
size_m
, NVL(t.bytes_cached/1024/1024, 0) used_m, TRUNC((t.bytes_cached / d.bytes) * 100) pct_used
FROM
sys.dba_temp_files d, v$temp_extent_pool t, v$tempfile v
WHERE (t.file_id (+)= d.file_id)
AND (d.file_id = v.file#);

###########################################################################################
Additional checks

select distinct(temporary_tablespace) from dba_users;

select username,default_tablespace,temporary_tablespace from dba_users order by temporary_tablespace;

SELECT * FROM DATABASE_PROPERTIES where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE';

Changing the default temporary Tablespace

SQL> alter database default temporary tablespace TEMP;

Database altered.

To add tempfile to Temp Tablespace

alter tablespace  temp  add tempfile '&tempfilepath' size 1800M;

alter tablespace temp add tempfile '/m001/oradata/SID/temp02.dbf' size 1000m;

alter tablespace TEMP add tempfile '/SID/oradata/data02/temp04.dbf' size 1800M autoextend on maxsize 1800M;

To resize the  tempfile in Temp Tablespace

alter database tempfile '/u02/oradata/TESTDB/temp01.dbf' resize 250M

alter database tempfile '/SID/oradata/data02/temp12.dbf' autoextend on maxsize 1800M;

alter tablespace TEMP add tempfile '/SID/oradata/data02/temp05.dbf' size 1800m reuse;

To find Sort Segment Usage by Users

select username,sum(extents) "Extents",sum(blocks) "Block"
from v$sort_usage
group by username;

To find Sort Segment Usage by a particular User

SELECT s.username,s.sid,s.serial#,u.tablespace, u.contents, u.extents, u.blocks
FROM v$session s, v$sort_usage u
WHERE s.saddr=u.session_addr
order by u.blocks desc;

To find Total Free space in Temp Tablespace

select 'FreeSpace  ' || (free_blocks*8)/1024/1024 ||' GB'  from v$sort_segment where tablespace_name='TEMP';

select tablespace_name , (free_blocks*8)/1024/1024  FreeSpaceInGB,
(used_blocks*8)/1024/1024  UsedSpaceInGB,
(total_blocks*8)/1024/1024  TotalSpaceInGB
from v$sort_segment where tablespace_name like '%TEMP%'

To find  Total Space Allocated for Temp Tablespace

select 'TotalSpace ' || (sum(blocks)*8)/1024/1024 ||' GB'  from dba_temp_files where tablespace_name='TEMP';

Get 10 sessions with largest temp usage

cursor bigtemp_sids is
select * from (
select s.sid,
s.status,
s.sql_hash_value sesshash,
u.SQLHASH sorthash,
s.username,
u.tablespace,
sum(u.blocks*p.value/1024/1024) mbused ,
sum(u.extents) noexts,
nvl(s.module,s.program) proginfo,
floor(last_call_et/3600)||':'||
floor(mod(last_call_et,3600)/60)||':'||
mod(mod(last_call_et,3600),60) lastcallet
from v$sort_usage u,
v$session s,
v$parameter p
where u.session_addr = s.saddr
and p.name = 'db_block_size'
group by s.sid,s.status,s.sql_hash_value,u.sqlhash,s.username,u.tablespace,
nvl(s.module,s.program),
floor(last_call_et/3600)||':'||
floor(mod(last_call_et,3600)/60)||':'||
mod(mod(last_call_et,3600),60)
order by 7 desc,3)
where rownum < 11;

Displays the amount of IO for each tempfile

SELECT SUBSTR(t.name,1,50) AS file_name,
f.phyblkrd AS blocks_read,
f.phyblkwrt AS blocks_written,
f.phyblkrd + f.phyblkwrt AS total_io
FROM   v$tempstat f,v$tempfile t
WHERE  t.file# = f.file#
ORDER BY f.phyblkrd + f.phyblkwrt DESC;

select * from (SELECT u.tablespace, s.username, s.sid, s.serial#, s.logon_time, program, u.extents, ((u.blocks*8)/1024) as MB,
i.inst_id,i.host_name
FROM gv$session s, gv$sort_usage u ,gv$instance i
WHERE s.saddr=u.session_addr and u.inst_id=i.inst_id  order by MB DESC) a where rownum<10;

Check for ORA-1652

show parameter background

cd <background dump destination>

ls -ltr|tail

view <alert log file name>

shift + G ---> to get the tail end...

?ORA-1652 ---- to search of the error...

shift + N ---- to step for next reported error...

I used these queries to check some settings:

-- List all database files and their tablespaces:
select  file_name, tablespace_name, status
,bytes   /1000000  as MB
,maxbytes/1000000  as MB_max
from dba_data_files ;

-- What temporary tablespace is each user using?:
select username, temporary_tablespace, default_tablespace from dba_users ;

-- List all tablespaces and some settings:
select tablespace_name, status, contents, extent_management
from dba_tablespaces ;

TABLESPACE_NAME                CONTENTS  EXTENT_MAN STATUS
------------------------------ --------- ---------- ---------
SYSTEM                         PERMANENT DICTIONARY ONLINE
TOOLS                          PERMANENT DICTIONARY ONLINE
TEMP                           TEMPORARY DICTIONARY OFFLINE
TMP                            TEMPORARY LOCAL      ONLINE

Now, the above query and the storage clause of the old 'create tablespace TEMP' command seem to tell us the tablespace only allows temporary objects, so it should be safe to assume that no one created any tables or other permanent objects in TEMP by mistake, as I think Oracle would prevent that. However, just to be absolutely certain, I decided to double-check. Checking for any tables in the tablespace is very easy:

-- Show number of tables in the TEMP tablespace - SHOULD be 0:
select count(*)  from dba_all_tables
where tablespace_name = 'TEMP' ;

Checking for any other objects (views, indexes, triggers, pl/sql, etc.) is trickier, but this query seems to work correctly - note that you'll probably need to connect internal in order to see the sys_objects view:

-- Shows all objects which exist in the TEMP tablespace - should get
-- NO rows for this:
column owner        format a20
column object_type  format a30
column object_name  format a40
select
o.owner  ,o.object_name
,o.object_type
from sys_objects s
,dba_objects o
,dba_data_files df
where df.file_id = s.header_file
and o.object_id = s.object_id
and df.tablespace_name = 'TEMP' ;

Identifying WHO is currently using TEMP Segments

10g onwards

SELECT sysdate,a.username, a.sid, a.serial#, a.osuser, (b.blocks*d.block_size)/1048576 MB_used, c.sql_text
FROM v$session a, v$tempseg_usage b, v$sqlarea c,
     (select block_size from dba_tablespaces where tablespace_name='TEMP') d
    WHERE b.tablespace = 'TEMP'
    and a.saddr = b.session_addr
    AND c.address= a.sql_address
    AND c.hash_value = a.sql_hash_value
    AND (b.blocks*d.block_size)/1048576 > 1024
    ORDER BY b.tablespace, 6 desc;
    
    
    
        
    
Find and Clear INACTIVE SESSIONS

select 'alter system kill session '||' '||''''||s.sid||','||s.serial# ||''' immediate;' FROM   v$session s
WHERE  s.type!= 'BACKGROUND'
AND S.TYPE='USER'
AND S.USERNAME='<SCHEMA NAME>'
AND TRUNC(S.LOGON_TIME) < '28-MAR-2013' 
AND S.STATUS='INACTIVE' and last_call_et > 30       -- more than 30 mins inactive


Query to find the session that is generating more Archives
This Query is to find the session that is generating more Archives.

col program for a10
col username for a10
select to_char(sysdate,'hh24:mi'), username, program , a.sid, a.serial#, b.name, c.value
from v$session a, v$statname b, v$sesstat c
where b.STATISTIC# =c.STATISTIC#
and c.sid=a.sid and b.name like 'redo%'
order by value;


To check INACTIVE sessions with HIGH DISK IO

select p.spid,s.username, s.sid,s.status,t.disk_reads, s.last_call_et/3600 last_call_et_Hrs,
s.action,s.program,s.machine cli_mach,s.process cli_process,lpad(t.sql_text,30) "Last SQL"
from gv$session s, gv$sqlarea t,v$process p
where s.sql_address =t.address and
s.sql_hash_value =t.hash_value and
p.addr=s.paddr and
t.disk_reads > 5000
and s.status='INACTIVE'
and s.process='1234'
order by S.PROGRAM;


Analyze Disk IO

prompt SESSIONS PERFORMING HIGH I/O > 50000
select p.spid, s.sid,s.process cli_process, s.status,t.disk_reads, s.last_call_et/3600 last_call_et_Hrs,
s.action,s.program,lpad(t.sql_text,30) "Last SQL"
from v$session s, v$sqlarea t,v$process p
where s.sql_address =t.address and
s.sql_hash_value =t.hash_value and
p.addr=s.paddr and
t.disk_reads > 10000
order by t.disk_reads desc;


LATCH SESSIONS DETAIL:
col event for a10

select s.sid,username,osuser,program,machine,status,to_char(logon_time,'DD-MON-YYYY HH24:MI:SS') "LOGON_TIME",last_call_et/3600 "LAST_CALL_HRS",sw.event from v$session s,v$session_wait sw where s.sid=sw.sid and sw.event like '%latch%';


SQL_TEXT OF LATCH SESSIONS:

select s.sid,username,sql_text,sw.event,l.name "LATCH_NAME" from v$session s,v$session_wait sw,v$sqltext sq,v$latch l where s.sid=sw.sid and sq.address = s.sql_address and l.latch# = sw.p2 and sw.event like '%latch%' order by s.sid,piece;


#########################################################################################################


DB File Scattered read Monitoring and Troubleshooting


Note:
This event signifies that the user process is reading buffers into the SGA buffer cache and is waiting for a physical I/O call to return.
A db file scattered read issues a scatter-read to read the data into multiple discontinuous memory locations.
A scattered read is usually a multiblock read. It can occur for a fast full scan (of an index) in addition to a full table scan.
The db file scattered read wait event identifies that a full table scan is occurring.
When performing a full table scan into the buffer cache, the blocks read are read into memory locations that are not physically adjacent to each other.
Such reads are called scattered read calls, because the blocks are scattered throughout memory.
This is why the corresponding wait event is called 'db file scattered read'.
Multiblock (up to DB_FILE_MULTIBLOCK_READ_COUNT blocks) reads due to full table scans into the buffer cache show up as waits for 'db file scattered read'.

DB_FILE_SCATTERED_READ COUNT ON DATABASE:


set pagesize 5000
set lines 185
set long 5000
col username for a15
col osuser for a15
col program for a20
col "LOGON_TIME" for a23
col status for a8
col machine for a15
col SQL_TEXT for a90
col EVENT for a50
col P1TEXT for a10
col P2TEXT for a10
col P3TEXT for a10
col p1 for 9999999999999
col p2 for 9999999999999
col p3 for 9999999999999
col "LAST_CALL_HRS" for 99999.999
col STATE for a12
select event,count(event) "DB_FILE_SCATTERED_READ_COUNT" from v$session_wait having count(event)>= 1 and event like '%scattered%' group by event;
DB_FILE_SCATTERED_READ SESSIONS DETAIL:

col event for a25
select s.sid,username,osuser,program,machine,status,to_char(logon_time,'DD-MON-YYYY HH24:MI:SS') "LOGON_TIME",last_call_et/3600 "LAST_CALL_HRS",sw.event from
v$session s,v$session_wait sw where s.sid=sw.sid and sw.event like '%scattered%';


DB_FILE_SCATTERED_READ_WAIT_DETAIL:

select sid,EVENT,P1TEXT,P1,P2TEXT,P2,P3TEXT,P3,WAIT_TIME,SECONDS_IN_WAIT,STATE from v$session_wait where event like '%scattered%';


SQL_TEXT OF DB_FILE_SCATTERED_READ SESSIONS:

select sw.sid,username,sql_text "SQL_TEXT",sw.event from v$session s,v$session_wait sw,v$sqltext sq where s.sid=sw.sid and sq.address = s.sql_address and sw.event like '%scattered%' order by sw.sid,piece;



USE THE BELOW SQL_FILE TO IDENTIFY THE SEGMENT:

set linesize 150
set pagesize 5000
col owner for a15
col segment_name for a30
SELECT owner,segment_name,segment_type FROM dba_extents WHERE file_id=&file AND &block_id BETWEEN block_id AND block_id + blocks -1 ;



Troubleshooting BUFFER BUSY WAITS

Note:
This wait indicates that there are some buffers in the buffer cache that multiple processes are attempting to access concurrently.
Query V$WAITSTAT for the wait statistics for each class of buffer.
Common buffer classes that have buffer busy waits include data block, segment header, undo header, and undo block.

BUFFER BUSY WAITS COUNT ON DATABASE:

set pagesize 5000
set lines 180
set long 5000
col username for a15
col osuser for a15
col program for a20
col "LOGON_TIME" for a23
col status for a8
col machine for a15
col SQL_TEXT for a90
col EVENT for a50
col P1TEXT for a10
col P2TEXT for a10
col P3TEXT for a10
col p1 for 9999999999999
col p2 for 9999999999999
col p3 for 9999999999999
col "LAST_CALL_HRS" for 99999.999

select event,count(event) "BUFFER_BUSY_WAITS/LOCK_COUNT" from v$session_wait having count(event)>= 1 and event like '%buffer busy waits%' group by event;


BUFFER_BUSY_WAITS SESSIONS DETAIL:

col event for a10
select s.sid,username,osuser,program,machine,status,to_char(logon_time,'DD-MON-YYYY HH24:MI:SS') "LOGON_TIME",last_call_et/3600 "LAST_CALL_HRS",sw.event from
v$session s,v$session_wait sw where s.sid=sw.sid and sw.event like '%buffer busy waits%';


SQL_TEXT OF BUFFER_BUSY_WAITS SESSIONS:

col "EVENT" for a25
select s.sid,username "USERNAME",sql_text "SQL_TEXT",sw.event "EVENT" from v$session s,v$session_wait sw,v$sqltext sq where s.sid=sw.sid and
sq.address = s.sql_address and sw.event like '%buffer busy waits% order by sw.sid,piece';



TYPE_OF_SEGMENT_CONTENDED_FOR

SELECT class, count FROM V$WAITSTAT WHERE count > 0 ORDER BY count DESC;

USE THE BELOW SQL_FILE TO IDENTIFY THE SEGMENT

set linesize 150
set pagesize 5000
col owner for a15
col segment_name for a30
SELECT owner,segment_name,segment_type FROM dba_extents WHERE file_id=&file AND &block_id BETWEEN block_id AND block_id + blocks -1 ;



Oracle Wait Event Analysis

Wait event
column seq# format 99999
column EVENT format a30
column p2 format 999999
column STATE format a10
column WAIT_T format 9999
select SID,SEQ#,EVENT,P1,P2,WAIT_TIME WAIT_T,SECONDS_IN_WAIT,STATE
from v$session_wait
where sid = '&sid' ;



Wait event List in DB

select event,count(event) "EVENT_COUNT" from v$session_wait group by event order by event;
To Find Wait Events for a given Session

column seq# format 99999                                                        
column EVENT format a30                                                        
column p2 format 9999                                                          
column STATE format a10                                                         
column WAIT_T format 9999                                                      
select SID,SEQ#,EVENT,P1,P2,WAIT_TIME WAIT_T,SECONDS_IN_WAIT,STATE
from gv$session_wait
where sid =  '&sid' ;

To Find Wait Event details of a specific wait event

column seq# format 99999                                                       
column EVENT format a30                                                        
column p2 format 9999                                                          
column STATE format a10                                                        
column WAIT_T format 9999                                                      
select SID,SEQ#,EVENT,P1,P2,WAIT_TIME WAIT_T,SECONDS_IN_WAIT,STATE
from gv$session_wait
where event like '%cursor: pin S%';

Count of sessions ordered by wait event associated

SELECT count(*), event FROM v$session_wait WHERE wait_time = 0 AND event NOT IN ('smon
timer','pmon timer','rdbms ipc message','SQL*Net message from client') GROUP BY event ORDER BY 1
DESC;

To find Wait event Most of the time the session waited for

select event,TOTAL_WAITS ,TOTAL_TIMEOUTS,TIME_WAITED from gv$session_event where sid=54
order by TIME_WAITED

To find the list of wait events and count of associated sessions

select count(sid),event from v$session_wait group by event order by 1;

No of events with sid's

prompt Sessions Wait Event Summary            
select EVENT,COUNT(SID)
from v$session_wait
GROUP BY EVENT;

Obtaining a parameter defined

col value for a10
col description for a30
select name,value,description from v$parameter where name like '%timed_statistics%';


Wait events

set linesize 152
set pagesize 80
column EVENT format a30
select *  from  v$system_event
where  event like '%wait%';

Sessions waiting "sql*net message from client"

prompt Sessions having Wait Event "sql*net message from client"          
select program,module,count(s.sid) from v$session s, v$session_Wait w
where w.sid=s.sid and w.event='SQL*Net message from client' group by program,module  having
count(s.sid)>5 order by count(s.sid);

Sessions having Wait Event "sql*net message from client" from more than 1Hour

select program,module,count(s.sid) from v$session s, v$session_Wait w
where w.sid=s.sid
and s.last_call_et > 3600
and w.event='SQL*Net message from client' group by program,module  having
count(s.sid)>5 order by count(s.sid);

Sessions having Wait Event "sql*net message from client"

select s.sid,s.process,S.STATUS,s.program,s.module,s.sql_hash_value,s.last_call_et/3600 Last_Call_Et_HRS
from v$session s, v$session_Wait w
where w.sid=s.sid and w.event='SQL*Net message from client'
and s.module='&Module_name'
order by 6 desc; 

Segment Statistics

select
object_name,
statistic_name,
value
from
V$SEGMENT_STATISTICS
where object_name ='SOURCE$';

select    statistic_name,  count(object_name)  from V$SEGMENT_STATISTICS
where STATISTIC_NAME like 'physical%'
group by statistic_name;

select distinct(STATISTIC_NAME) from v$SEGMENT_STATISTICS;  

V$SYSTEM_EVENT

This view contains information on total waits for an event.
Note that the TIME_WAITED and AVERAGE_WAIT columns will contain
a value of zero on those platforms that do not support a fast timing mechanism.
If you are running on one of these platforms and you want this column to reflect
true wait times, you must set TIMED_STATISTICS to TRUE in the parameter file;
doing this will have a small negative effect on system performance.

Buffer Busy waits

SELECT * FROM v$event_name WHERE name = 'buffer busy waits';

SELECT   sid, event, state, seconds_in_wait, wait_time, p1, p2, p3
FROM     v$session_wait
WHERE    event = 'buffer busy waits'
ORDER BY sid;
select * from v$waitstat;

SELECT   sid, event, state, seconds_in_wait, wait_time, p1, p2, p3
FROM     v$session_wait
WHERE    event = 'buffer busy waits'
ORDER BY sid;

Segment details from File number

SELECT owner, segment_name, segment_type
FROM   dba_extents
WHERE  file_id = &absolute_file_number
AND    &block_number BETWEEN block_id AND block_id + blocks -1;

Direct path write

SELECT * FROM v$event_name WHERE name = 'direct path write';         

SELECT tablespace_name, file_id "AFN", relative_fno "RFN"
FROM   dba_data_files
WHERE  file_id = 201;           
SELECT tablespace_name, file_id "AFN", relative_fno "RFN"
FROM   dba_data_files
WHERE  file_id = 201;

Total waits/time waited/max wait for a session

SELECT   event, total_waits, time_waited, max_wait
FROM     v$session_event
WHERE    sid = 47
ORDER BY event;

SELECT   A.name, B.value
FROM     v$statname A, v$sesstat B
WHERE    A.statistic# = 12
AND      B.statistic# = A.statistic#
AND      B.sid = 47;           
Sessions Ordered by Wait event in Database

set lines 150
set pages 500
col event for a50
select event,count(event) "EVENT_COUNT" from v$session_event group by event order by event;




Run TKPROF procedure on the raw trace files.  For example, Doyen_ora_18190.trc is the name of the raw trace file and trace1.txt is the name of the TKPROF file.



To enable trace for an API when executed from a SQL script outside of Oracle Applications
For Example Inventory APIs


-- enable trace
ALTER SESSION SET EVENTS '10046 trace name context forever, level 12';

-- Set the trace file identifier, to locate the file on the server
ALTER SESSION SET TRACEFILE_IDENTIFIER = 'API_TRACE';

-- Execute the API from the SQL script, in the same session.
EXEC <procedure name> ; 

-- Once the API completes execution, disable trace
ALTER SESSION SET EVENTS '10046 trace name context off';

-- Locate the trace file based on the tracefile identifier
SELECT VALUE FROM V$PARAMETER WHERE NAME = 'user_dump_dest'; 

-- Generate the tkprof of the trace file
tkprof <trace_File>.trc <tkprof>.out sys=no explain=apps/<apps pwd>


select username, spid from v$process;


2.   Start the debug session with the SPID of the process that needs traced.

SQL> oradebug setospid 2280

The oradebug command below will enable the maximum tracing possible:

SQL> oradebug event 10046 trace name context forever, level 12

1.   Turn tracing off.

SQL> oradebug event 10046 trace name context off

2.   Obtain the trace file name.  The oradebug facility provides an easy way to obtain the file name:  

SQL> oradebug tracefile_name
c:\oracle9i\admin\ORCL92\udump\mooracle_ora_2280.trc
Now  we can use the Tkprof Utilty to get the readable format.

Enable Trace for particular session  :
For example to enable level 1 trace in a session with SID 9 and serial number 29 use

Event 10046 level 12 trace can be enabled using

 EXECUTE dbms_support.start_trace_in_session (9,29,binds=>true,waits=>true);

Trace can be disabled using

 dbms_support.stop_trace_in_session (9,29);

select a.SID,a.SERIAL#,b.USERNAME,b.PROGRAM from v$session a , v$process b where a.PADDR=b.ADDR and b.SPID='&SPID'
EXECUTE DBMS_SYSTEM.set_sql_trace_in_session(sid=>1390, serial#=>7860, sql_trace=>TRUE);


Start Tuning....
How to Start tuning: Server Level (Focus from Oracle Database)

Whenever there is server level issue, The tuning starts from the server
.. Just remember the phrase �The person who has the problems has the symptoms for solutions� So let us start the tuning from server..

1. First we need to find out what the server utilization is and who is utilizing the most.

How to achieve it: we can use os specific commands like Topas in AIX,TOP in linux environments,Prstat/topas in solaris, task manager in windows.

What you need: once you found what is the utilization and who is doing that..
Then you need to get the server process id (spid) from the os level of the specific process who is utilizing the most.

2. After that login to any user session who can access v$ views.

Execute: ( I attached my queries ,, you can add the columns you need to add )

Select module,action,machine,sql_address,sql_id,status from v$session vs
Where paddr=(select addr from v$process where spid=�&spid�);

3. find out what the sql which is consuming resource.

Select sql_text,sql_fulltext,optimizer_cost from v$sql where sql_id=�&sql_id�;

4. Now you got the details of the sessions,, if you want to do kill the session .. go to your server console as the specific user and then kill the session

How should I do: use ��kill -9 �

5. Don�t stop here .. tune the query and take complete solution to the issue .

How to Start tuning: Session Level (focus from oracle Database)

Refer to the post� How to Start tuning: Server Level (Focus from Oracle Database)
When we found that the specific session taking more bottleneck towards performance. Then The best step to be taken is the tracing the session (ie getting more details) before killing it.
For Example FNDWFBG is taking more cpu usage.. what we need to take step is..
1. As per the guidelines in the post.. first we need to take the Os process id.

2. Login as sysdba

3. i. oradebug setospid &spid
ii. oradebug unlimit
iii. oradebug Event 10046 trace name context forever, level 12
Trace file will be generated with the process id in its name in User dump location.

4. Once the session got completed then execute the below command in the sysdba session where you initiated the oradebug.

oradebug Event 10046 trace name context off;

5. What next.. Generate tkprof for the session dump file to find the expensive query.

Suggested to use as below:

Tkprof explain=/ sys=no sort='(prsela, exeela, fchela)'

Example: tkprof PROD_ora_950460.trc PROD_ora_950460.tkp explain=apps/apps sys=no
sort='(prsela, exeela, fchela)'

The above tkprof options are very usefull.. it will give us the query details in the order of its expensiveness.

6. Beyond this.. DBA needs to work with the respective technical teams to tune the expensive query.


How to start tuning: Code Level 

Refer to the post� How to Start tuning: Session Level (focus from oracle Database)
Once we found the most expensive query, we need to tune the query and test it again..
Always advisable to tune and test in your test instance.

Follow the below steps to test and find out whether it is tuned or not�

1. Login to your Application user through which you can execute the statements

2. alter session set tracefile_identifier='10046';

3. alter session set timed_statistics = true;

4. alter session set statistics_level=all;

5. alter session set max_dump_file_size = unlimited;

6. alter session set events '10046 trace name context forever,level 12';

7. Execute the expensive statement

8. select * from dual; --- to ensure the previous cursor is closed

9. alter session set events '10046 trace name context off';

10. Generate the tkprof

Generate the tkprof as explained in the post How to Start tuning: Session Level (focus from oracle Database).. itll the give the details in the order of its expensiveness.

How to start tuning: Oracle Ebs Application Session

As per the previous posts.. we need to trace the session to find out what is the problem.
For E-Business Suite Session .. Here we go.
1. Navigate Responsibility: System Administrator > Profile > System >Query

User: User submitting the Journal entries Report
Profile: Initialization SQL Statement - Custom

2. Click on User column - Edit Field and enter

begin fnd_ctl.fnd_sess_ctl('','','TRUE','TRUE','LOG','ALTER SESSION SET EVENTS=''''''10046 TRACE NAME CONTEXT FOREVER,LEVEL 12'''''); end;

3. Save.

4. Reproduce the problem through the user session to find out cause for performance problem.

5 Trace file will be generated with the process id in its name.
6 Generate tkprof for the trace file.

Generate the tkprof as explained in the post How to Start tuning: Session Level (focus from oracle Database).. itll the give the details in the order of its expensiveness.



Finding Archivelogs applied lastly

select min(COMPLETION_TIME) last_appl from v$archived_log
where (THREAD#=1 and SEQUENCE#=28040)
or (THREAD#=2 and SEQUENCE#=24386)
or (THREAD#=3 and SEQUENCE#=24259)

LAST_APPL
---------------
08-jun-07 19:12

Removing Old Archivelog files of a date (Replace ls with rm command)

alter session set nls_date_format='dd-mon-rr hh24:mi';
set lines 180
set pagesize 9999
select 'ls -l ' || name
from v$archived_log
where applied = 'YES'
and to_char(COMPLETION_TIME,'rrrrmmdd') between '20070602' and '20070604';


Examples (Throughly test yourself and understand before use)
df -hP|grep <codetree>
du -sh *
ls -ltr|tail
ls -lSr|tail
ls -ltr|head
find . -iname *out -mtime +30 -exec ls -l {} \;
find . -mtime +3 -exec gzip -f {} \;
find . -mtime +60 -exec ls -l {} \;
find . -size +100000000c -xdev -exec ls -lrth {} \;

du -sj --->to sum up sizes
nohup find /SID/oracle/product/102/admin/SID_Host/bdump -size +100000000c -name "*.trc*" -mtime +15 -xdev -exec ls -l {} \; &

find . -size +100000000c -name "*log*" -mtime +1 -xdev -exec gzip -f {} \;

find . -size +100000000c -xdev -exec ls -ltr {} \;

find / -size +100000000c -xdev -type f -exec ls -lh {} \;

find . ! -name . -prune -size +100000000c -xdev -exec ls -lrth {} \;

find . ! -name . -prune -size +100000000c -xdev -exec du -sh {} \;

find . ! -name . -prune -name "core-*" -mtime +30 -exec ls -l {} \;

find /tmp ! -name . -prune -name "*.t" -mtime +15 -exec ls -ltrh {} \;

find /tmp ! -name . -prune -name "*.t" -mtime +15 -exec ls -l {} \;

find /tmp -name "*.tmp.gz" -mtime +15 -exec ls -ltrh {} \;

find /tmp -name "*.t" -mtime +1 -exec gzip  -f {} \;

find . ! -name . -prune -name "*.t" -mtime +3 -exec gzip -f {} \;

find . ! -name . -prune -name "*.tmp" -mtime +15 -exec ls -ltrh {} \;

find . ! -name . -prune -name "*.tmp" -mtime +15 -exec ls -l {} \;

find . ! -name . -prune -name "*.tmp" -mtime +3 -exec gzip -f {} \;

find / -xdev -size '+5000k'|xargs ls -lh | grep -v dev |grep aptrvrbi

find . -xdev -size '+5000k'|xargs ls -lh | grep -v dev |grep iasrvrbi

find /tmp -xdev -size '+5000k'|xargs ls -l | grep -v dev|head -500

find . -xdev -size '+50000k'|xargs ls -ltr | grep -v dev

find . -xdev -size '+5000k'|xargs ls -ltrh | grep -v dev

find . ! -name . -prune -xdev -size '+5000k'|xargs ls -lh | grep -v dev

find . ! -name . -prune -xdev -size '+5000k'|xargs ls -ltrh | grep -v dev

find . ! -name . -prune -name "*.tmp" -mtime +30 -exec ls -ltr {} \;

find . ! -name . -prune -name "*.tmp" -mtime +30 -exec ls -l {} \;

find . ! -name . -prune -name "*.tmp" -mtime +30 -exec ls -l {} \;

find . -mtime +30 -size +100000000c -xdev -exec ls -ltrh {} \;

find . -size +100000000c -xdev -exec ls -ltr {} \;

find . -size +10000000c -xdev -exec ls -ltrh {} \;

find . -size +10000000c -xdev -exec ls -ltr {} \;

find . -size +10000000c -xdev -exec du -sk {} \;

find / -xdev -size '+10000k'|xargs ls -ld | grep -v dev |grep SID --->10000k files

find ./ -name "o1*.out" -size +3000k  -mtime +10 -exec gzip {} \;

du -sk *|sort -n|tail -15

*applcsf log/out/tmp

*product *iAS/Apache/Apache *806 network/admin/log

*APPLMGR *common/admin log/out

find /SID/applmgr/common/admin/log/SID_oradev -mtime +60 -type f -exec ls -l {} \;

nohup find /SID/applcsf/log/SID_ERP01 -mtime +30 -exec ls -l {} \; &


nohup find /SID/applcsf/tmp -mtime +7 -exec gzip -f{} \; &

nohup find /SID/applcsf/log -mtime +7 -exec gzip -f {} \; &


nohup find /SID/applcsf/out -mtime +7 -exec gzip -f {} \; &

nohup find /SID/applcsf/tmp -mtime +3 -exec gzip -f {} \; &

nohup find /SID/applcsf/log -mtime +3 -exec gzip -f {} \; &

nohup find /SID/applcsf/ -mtime +3 -exec gzip -f {} \; &

nohup find /SID/applcsf/out -mtime +7 -exec gzip -f {} \; &

nohup find /SID/applcsf/out/SID_Host -mtime +7 -exec gzip -f {} \; &
find . -mtime +30 -exec ls -l {} \; --> purging files more than 30days old

find . -mtime +10 -exec gzip -f {} \; --> zipping files more than 7days old

find /tmp -name "*.t" -mtime +3 -exec gzip -f {} \;

find ./ -name "*.tmp" -mtime +15 -exec ls -l {} \;

find ./ -name "*.trc" -mtime +1 -exec gzip -f {} \;

find . -name '*trw' -mmin +240 -exec gzip  {} \; 
find /SID/3rdparty/apps/jboss-4.0.4.GA/server/default/log -name "*.log.*" -mtime +30 -exec ls -l {} \;

find . -mtime +7 -exec ls -lrt {} \;

find ./ -name "*core*" -mtime +1 -exec ls -ltr {} \;

df -k | sort -n | tail

nohup find /SID/applcsf/log/SID_Host -mtime +30 -exec ls -l {} \; &

find . -name "*.t" -exec ls -l {} \;

find /tmp -name "*.t" -mtime +3 -exec gzip -f {} \;

find /tmp -name "*.t" -mtime +30 -exec ls -l {} \;

find /tmp -name "*.t" -mtime +15 -exec ls -ltrh {} \;

find /tmp -name "*.TMP" -mtime +30 -exec ls -l {} \;

find /tmp -name "O*.t" -mtime +30 -user USER -maxdepth 1 -exec ls -l {} \;
   
find /tmp -name "O*.t" -mtime +7 -user USER -exec gzip -f {} \;

find . -name "*.t.Z" -mtime +30 -exec ls -l {} \;

find . -name "*.t" -exec gzip -f {} \;

nohup find . -name "*log*" -mtime +60 -exec ls -l {} \; &

nohup find . -name "*log*" -mtime +7 -exec gzip -f {} \; &

nohup find . -name "*log*" -mtime +30 -exec ls -l {} \; &

find . -name "*log*" -mtime +10 -exec gzip -f {} \;

find ./ -name "Events*" -mtime +30 -exec ls -l {} \;

find ./ -name "Events*" -mtime +30 -exec ls -ltrh {} \;

find ./ -name "Events*" -mtime +30 -exec ls -l {} \;

find . -name "*default-web-access.log.txt*" -mtime +30 -exec gzip -f {} \;

find ./ -name "XWII_BASE_APPS_*" -exec ls -l {} \;

*** find . ! -name . -prune -name "*.t" -mtime +30 -exec ls -ltr {} \; --->To find ".t" files without descending sub directories...

find . ! -name . -prune -name "*.t" -mtime +7 -exec gzip -f {} \;

find . -name "Exaaa*" -mtime +10 -exec ls -l {} \;

find ./ -name "*.trw" -mtime +60 -exec ls -l {} \;

nohup find ./ -name "*.trc*" -mtime +3 -exec gzip -f {} \; &

nohup find ./ -name "*.trw" -mtime +3 -exec gzip -f {} \; &

find ./ -name "*.out*" -mtime +30 -exec ls -l {} \;

find ./ -name "*.out" -mtime +30 -exec ls -l {} \;

find ./ -name "*.trc" -mtime +0 -exec ls -l {} \;

nohup find ./ -name "*.trc" -mtime +0 -exec gzip -f {} \;

nohup find ./ -name "*.trc*" -mtime +60 -exec ls -l {} \; &

nohup find ./ -name "*trc" -mtime +3 -exec gzip -f {} \; &

find ./ -name "*trc" -mtime +30 -exec ls -l {} \;

find . ! -name . -prune -size +100000000c -xdev -mtime +3 -exec ls -lrth {} \;

ls -l *.trc  |grep " Dec  7" | awk '{print $9}'

gzip -f `ls -l *.trc  |grep " Dec  7" | awk '{print $9}`

find /SID/backup/RMAN -name "data_full_*" -mtime +0 -type f -exec ls -l {} \;

zip error_log_pls.zip error_log_pls; >error_log_pls

zip stuck_rec.dbg.zip stuck_rec.dbg; >stuck_rec.dbg

zip stuck_rec.dbg.zip stuck_rec.dbg >/SID/backup/stuck_rec.dbg.zip

zip apps_pbgd1i.log.zip apps_pbgd1i.log; >apps_pbgd1i.log

zip SID.zip SID >/SID/applcsf/mailtmp/appclo1i.zip

zip mod_jserv.log_25sep2008.zip mod_jserv.log; >mod_jserv.log

zip Events148.log.zip Events148.log; >Events148.log

ls -l `ls -ltr *.dbf | grep  "Apr  3" | awk '{print $9}'`

ls -ltrh *.dbf | grep  "Apr  3"

ls -ltr *p*.zip* | awk '{ sum += $5 } { print "Size in GB " sum/1024/1024/1024}' |tail -1

nohup find /SID/applcsf/log -mtime +30 -exec ls -l {} \; &

nohup find /SID/applcsf/out -mtime +30 -exec ls -l {} \; &

nohup find /SID/applcsf/tmp -mtime +30 -exec ls -l {} \; &
find /tmp  \( -name '*.t' \) -mtime +3 -size +1000  -exec ls -l  {} \;

find ./ -name "*.trc" -mtime +1 -exec gzip -f {} \;
find ./ -name "tmp_*" -mtime +30 -exec ls -ltr {} \;

Finding directory sizes

du -k |sort  -nr |head -20
du -g |sort  -nr |head -20

find ./ -name "*.trc" -mtime +7 -exec ls -ltr {} \;

find . -size +100000000c -xdev -exec gzip {} \;
find . -size +100000000c -xdev -type f -exec ls -lh {} \;

find /appl/oracle/admin/SID/udump -name "*.trc*" -mtime +90 -exec ls -ltrh {} \;

find <path> -type f -print|xargs ls �l

Eg:

find /appl/formsA/oracle/product/dev6.0/reports60/server/cache -type f -print|xargs ls -l

find /data/a01/SID -name "*.arc" -mtime +5 -exec rm {} \;

find . -mtime +730 -type f �print  -exec tar -cvf /tempspace/repservr_cache_2years.tar . \;

find /tempspace -mtime +730 -type f �print  -exec tar -cvf /tempspace/repservr_cache_2years.tar {} \;

find /data/a01/SID -name "*.arc*" -mtime +5 -exec rm {} \;

find /data2/prod_export -name "comp_export_SID *.log" -mtime +30 -exec rm {} \;


Linux

ps -eo pid,user,vsz,rss,s,comm | sort -n -k 3,4
ps -eo pid,user,vsz,rss,args | sort -n -k 3,4 | tail -20

prstat -s rss
sar -W
swapon -s

SunOS

prstat -s rss
swap -l
- returns dev(vice)/low/blocks/free in 512-bytes blocks

ps -eo pid,user,vsz,rss,s,comm | sort -n -k 3,4  | tail -20
AIX

ps -efl | sort -n -k 10,10 | tail -50

ps -eo pid,user,vsz,rss,s,cmd | sort -n -k 3,4  | tail -20

ps -eo pid,user,vsz,comm | sort -n -k 3,3  | tail -20

SIZE

ps -eo pid,user,vsz,rss,s,comm | sort -n -k 3,4

vmstat
swapon -s

swap
usr/sbin/lsps -a

Real memory
usr/sbin/lsattr -HE -l sys0 -a realmem

HP-UX

ps -efl | sort -n -k 10,10 | tail -50
swapinfo

PCH

V linuxu:
pridat sloupec swap, dat do souboru a seradit:

top -b -n 1 >top.txt
cat top.txt | egrep "M|G" | sort -r -k 5,5 | more


V SUNu

ps -efl|sort -rk 10,10| head
Desaty sloupec je pouzita pamet ve strankach. Prikaz pagesize vypise velikost stranky, vynasobit a je to.

prstat -s rss

top -o size

swapinfo -t

swap -s

vmstat 4 6

HP-UX

swapinfo

swapinfo -m   --->Memory information (interms of MB)

vmstat -S

vmstat -s

sar -w 5 5

show parameter sga_max_size

free -m

ps -ef  |wc -l

No of processors

cat /proc/cpuinfo| grep processor| wc -l

cat /proc/cpuinfo | grep processor

Linux

free -m

Sun

prstat -t

prstat -s rss

/usr/sbin/prtconf | grep "Memory size"

df -k|grep swap

sar -w 5 5

prstat -t             prstat -u pdb2i25 -s size
top -o size
swap -s
free
swapon -s
vmstat 4 4
ps auxw |tail -10--hpunix

lsattr -E -l sys0 -a realmem  --- ram on aix
lsps -s  -- swap space on aix

vmstat
swap -l
prtconf | grep Mem
swap SUNOS:16106834.6

vmstat -p 3
mpstat

ps -eo pid,pcpu,args | sort +1n                         %cpu
ps -eo pid,vsz,args | sort +1n                             kilobytes of virtual memory

/usr/ucb/ps aux |more                                       Output is sorted with highest users (processes) of CPU and memory at the top

free --->swap information in kbytes
free -m -->swap information in mbytes
free -g -->swap information in gbytes

Solaris

$ /usr/sbin/prtconf grep -i "Memory size"
$ swap -s
$ df -k
$ /usr/local/bin/top
$ vmstat 5 100
$ sar -u 2 100
$ iostat -D 2 100
$ mpstat 5 100

For example:

$ man vmstat

Here is some sample output from these commands:

$ prtconf grep -i "Memory size"

Memory size: 4096 Megabytes

$ swap -s
total: 7443040k bytes allocated + 997240k reserved = 8440280k used, 2777096k available

$ df -k
Filesystem kbytes used avail capacity Mounted on
/dev/dsk/c0t0d0s0 4034392 2171569 1822480 55% /
/proc 0 0 0 0% /proc
fd 0 0 0 0% /dev/fd
mnttab 0 0 0 0% /etc/mnttab
/dev/dsk/c0t0d0s3 493688 231339 212981 53% /var
swap 2798624 24 2798600 1% /var/run
swap 6164848 3366248 2798600 55% /tmp
/dev/vx/dsk/dcdg01/vol01
25165824 23188748 1970032 93% /u01
/dev/vx/dsk/dcdg01/vol02
33554432 30988976 2565456 93% /u02
...

$ top

last pid: 29570; load averages: 1.00, 0.99, 0.95 10:19:19
514 processes: 503 sleeping, 4 zombie, 6 stopped, 1 on cpu
CPU states: 16.5% idle, 17.9% user, 9.8% kernel, 55.8% iowait, 0.0% swap
Memory: 4096M real, 46M free, 4632M swap in use, 3563M swap free

PID USERNAME THR PRI NICE SIZE RES STATE TIME CPU COMMAND
29543 usupport 1 35 0 2240K 1480K cpu2 0:00 0.64% top-3.5b8-sun4u
13638 usupport 11 48 0 346M 291M sleep 14:00 0.28% oracle
13432 usupport 1 58 0 387M 9352K sleep 3:56 0.17% oracle
29285 usupport 10 59 0 144M 5088K sleep 0:04 0.15% java
13422 usupport 11 58 0 391M 3968K sleep 1:10 0.07% oracle
6532 usupport 1 58 0 105M 4600K sleep 0:33 0.06% oracle
...

$ vmstat 5 100
procs memory page disk faults cpu
r b w swap free re mf pi po fr de sr f0 s1 s1 s1 in sy cs us sy id
0 1 72 5746176 222400 0 0 0 0 0 0 0 0 11 9 9 4294967196 0 0 -19 -6 -103
0 0 58 2750504 55120 346 1391 491 1171 3137 0 36770 0 37 39 5 1485 4150 2061 18 8 74
0 0 58 2765520 61208 170 272 827 523 1283 0 3904 0 36 40 2 1445 2132 1880 1 3 96
0 0 58 2751440 58232 450 1576 424 1027 3073 0 12989 0 22 26 3 1458 4372 2035 17 7 76
0 3 58 2752312 51272 770 1842 1248 1566 4556 0 19121 0 67 66 12 2390 4408 2533 13 11 75
...

$ iostat -c 2 100
cpu
us sy wt id
15 5 13 67
19 11 52 18
19 8 44 29
12 10 48 30
19 7 40 34
...

$ iostat -D 2 100
sd15 sd16 sd17 sd18
rps wps util rps wps util rps wps util rps wps util
7 4 9.0 6 3 8.6 5 3 8.1 0 0 0.0
4 22 16.5 8 41 37.9 0 0 0.7 0 0 0.0
19 34 37.0 20 24 37.0 12 2 10.8 0 0 0.0
20 20 29.4 24 37 51.3 3 2 5.3 0 0 0.0
28 20 40.8 24 20 42.3 1 0 1.7 0 0 0.0
...
$ mpstat 2 100
CPU minf mjf xcal intr ithr csw icsw migr smtx srw syscl usr sys wt idl
0 115 3 255 310 182 403 38 72 82 0 632 16 6 12 66
1 135 4 687 132 100 569 40 102 68 0 677 14 5 13 68
2 130 4 34 320 283 552 43 94 63 0 34 15 5 13 67
3 129 4 64 137 101 582 44 103 66 0 51 15 5 13 67
HP-UX 11.0:

top
Glance/GlancePlus
sam
/etc/swapinfo -t
/usr/sbin/swapinfo -t
ipcs -mop

Would it be safe to say that to view memory usage by user, execute the
following:

UNIX95= ps -e -o ruser,pid,vsz=Kbytes

...and to view shared memory usage, such as for Oracle processes, using the
following:

ipcs -bmop

$ grep Physical /var/adm/syslog/syslog.log
$ df -k
$ sar -w 2 100
$ sar -u 2 100
$ /bin/top
$ vmstat -n 5 100
$ iostat 2 100
$ top

For example:

$ grep Physical /var/adm/syslog/syslog.log
Nov 13 17:43:28 rmtdchp5 vmunix: Physical: 16777216 Kbytes, lockable: 13405388 Kbytes, available: 15381944 Kbytes

$ sar -w 1 100

HP-UX rmtdchp5 B.11.00 A 9000/800 12/20/02

14:47:20 swpin/s bswin/s swpot/s bswot/s pswch/s
14:47:21 0.00 0.0 0.00 0.0 1724
14:47:22 0.00 0.0 0.00 0.0 1458
14:47:23 0.00 0.0 0.00 0.0 1999
14:47:24 0.00 0.0 0.00 0.0 1846
...

$ sar -u 2 100 # This command generates CPU % usage information.

HP-UX rmtdchp5 B.11.00 A 9000/800 12/20/02

14:48:02 %usr %sys %wio %idle
14:48:04 20 2 1 77
14:48:06 1 1 0 98
...
$ iostat 2 100

device bps sps msps

c1t2d0 36 7.4 1.0
c2t2d0 32 5.6 1.0
c1t0d0 0 0.0 1.0
c2t0d0 0 0.0 1.0
...

AIX:

$ /usr/sbin/lsattr -E -l sys0 -a realmem
$ /usr/sbin/lsps -s
$ vmstat 5 100
$ iostat 2 100
$ /usr/local/bin/top # May not be installed by default in the server

For example:

$ /usr/sbin/lsattr -E -l sys0 -a realmem

realmem 33554432 Amount of usable physical memory in Kbytes False

NOTE: This is the total Physical + Swap memory in the system.
Use top or monitor command to get better breakup of the memory.

$ /usr/sbin/lsps -s

Total Paging Space Percent Used
30528MB 1%

Linux [RedHat 7.1 and RedHat AS 2.1]:

$ dmesg grep Memory
$ vmstat 5 100
$ /usr/bin/top

For example:

$ dmesg grep Memory
Memory: 1027812k/1048568k available (1500k kernel code, 20372k reserved, 103k d)$ /sbin/swapon -s

Tru64

$ vmstat -P grep -i "Total Physical Memory ="
$ /sbin/swapon -s
$ vmstat 5 100


For example

$ vmstat -P grep -i "Total Physical Memory ="
Total Physical Memory = 8192.00 M

$ /sbin/swapon -s

Swap partition /dev/disk/dsk1g (default swap):
Allocated space: 2072049 pages (15.81GB)
In-use space: 1 pages ( 0%)
Free space: 2072048 pages ( 99%)
Total swap allocation:
Allocated space: 2072049 pages (15.81GB)
Reserved space: 864624 pages ( 41%)
In-use space: 1 pages ( 0%)
Available space: 1207425 pages ( 58%)

Please take at least 10 snapshots of the "top" command to get an idea
aboud most OS resource comsuming processes in the server and the different
snapshot might contain a few different other processes and that will indicate
that the use of resouces are varying pretty quickly amound many processes.

AIX:
/usr/sbin/lsattr -E -l sys0 -a realmem
/usr/sbin/lsps -s

HP-UX:
grep Physical /var/adm/syslog/syslog.log
/usr/sbin/swapinfo -t

Linux:
cat /proc/meminfo | grep MemTotal
/sbin/swapon -s

Solaris:
/usr/sbin/prtconf | grep "Memory size"
/usr/sbin/swap -s

Tru64:
vmstat -P| grep -i "Total Physical Memory ="
/sbin/swapon -s

LONG BIT

getconf LONG_BIT

Huge Pages

grep -i huge /etc/sysctl.conf



Finding OS Version and Bit

OS Version

uname -a
AIX <ServerName> 3 5 00C8E96B4C00

uname
AIX

oslevel -r
5300-06

OS Bit

lsconf|grep -i kernel
Kernel Type: 64-bit

prtconf

/usr/bin/isainfo �kv

getconf LONG_BIT 

getconf -a | grep KERN
uname -m


kb/mb/gb conventions
1024 bytes =  1KB  (4 letters)
1024 *1024 = 1048576 = 1MB (7 letters)
1024 *1024 * 1024 = 1073741824 = 1GB (10 letters)


To Check whether Sendmail is Enabled in a Unix Box

lssrc -a |grep sendmail

ps �ef|grep sendmail


Lists the no of processes grouped by individual user on a box

ps -ef|awk '{print $1}'|sort -n|uniq -c

Process count

ps -ef|awk '{print $1 }'|sort|uniq -c |sort -n

ps -ef|wc -l

ps -ef|grep oracle|wc -l

ps -x|wc -l

For files greater than 100mb
find /home/oraapp  -size +100000c -ls


Extract AWR Report :

@$ORACLE_HOME/rdbms/admin/awrrpt.sql

----SOFAR-TOTALWORK

SELECT sid,
       TO_CHAR (start_time, 'hh24:mi:ss') stime,
       MESSAGE,
       (sofar / totalwork) * 100 percent
  FROM v$session_longops
 WHERE sofar / totalwork < 1
/

####################### Dump load activity################

login with sysdba

sqlplus / as sysdba

grant create any directory to  SBI_PROD;

CREATE DIRECTORY datadir1 AS  '/usr/oracle/app/product/11.2.0/dbhome_1/load_db';


select directory_path from dba_directories; 



