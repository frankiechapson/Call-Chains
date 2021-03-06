create or replace procedure INSERT_CALL_CHAIN( I_TABLE_NAME      in varchar 
                                             , I_OWNER           in varchar default null
                                             ) is

/* ******************************************************************************************

    This procedure writes out the chain of callings of the "insert into"s a table

    History of changes
    yyyy.mm.dd | Version | Author         | Changes
    -----------+---------+----------------+-------------------------
    2014.01.06 |  1.0    | Ferenc Toth    | Created 

***************************************************************************************** */

    L_PROC_NAME     varchar ( 100 );

begin

    for L_R in 
        ( select TTABLE.OWNER, TTABLE.NAME, TTABLE.TYPE, TTABLE.LINE
           from (select * from ALL_SOURCE 
                  where OWNER = nvl( upper( I_OWNER ), OWNER ) 
                    and ' '||replace( replace( replace( replace( upper(text), chr(0) ), chr(8) ), chr(10) ), chr(13) )||' ' like '% INSERT %' ) TINSERT,
                (select * from ALL_SOURCE 
                  where OWNER = nvl( upper( I_OWNER ), OWNER ) 
                    and ' '||replace( replace( replace( replace( upper(text), chr(0) ), chr(8) ), chr(10) ), chr(13) )||' ' like '% INTO %'   ) TINTO  ,
                (select * from ALL_SOURCE 
                  where OWNER = nvl( upper( I_OWNER ), OWNER ) 
                    and ' '||replace( replace( replace( replace( upper(text), chr(0) ), chr(8) ), chr(10) ), chr(13) )||' ' like '% '||upper( I_TABLE_NAME )||' %' ) TTABLE
           where TINSERT.OWNER =  TINTO.OWNER             
             and TINSERT.NAME  =  TINTO.NAME
             and TINSERT.TYPE  =  TINTO.TYPE
             and TINSERT.LINE  between TINTO.LINE-1 and TINTO.LINE
             and TINTO.OWNER   =  TTABLE.OWNER
             and TINTO.NAME    =  TTABLE.NAME
             and TINTO.TYPE    =  TTABLE.TYPE
             and TINTO.LINE    between TTABLE.LINE-1 and TTABLE.LINE
          order by TTABLE.LINE
        ) loop

        if L_R.TYPE = 'PACKAGE BODY' then
            L_PROC_NAME := L_R.NAME||'.'||GET_PROCEDURE ( L_R.NAME, L_R.LINE, L_R.OWNER );
        else
            L_PROC_NAME := L_R.NAME;
        end if;

        dbms_output.put_line( ' '||L_R.TYPE||' | '||L_PROC_NAME||' : '||L_R.LINE );

        if L_PROC_NAME is not null and L_R.TYPE != 'TRIGGER' then
            PROC_CALL_CHAIN( L_PROC_NAME, 1, L_R.OWNER );
        end if;

    end loop; 

end;

