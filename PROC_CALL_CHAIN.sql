create or replace procedure PROC_CALL_CHAIN ( I_NAME            in varchar
                                            , I_LEVEL           in integer default 0
                                            , I_OWNER           in varchar default null
                                            ) is

/* ******************************************************************************************

    This procedure writes out the chain of callings of the given procedure/function

    History of changes
    yyyy.mm.dd | Version | Author         | Changes
    -----------+---------+----------------+-------------------------
    2014.01.06 |  1.0    | Ferenc Toth    | Created 

***************************************************************************************** */


    L_STRING_TO_SEACH   varchar(100);  
    L_LEVEL             integer := 1;
    L_PROC_NAME         varchar( 50);  

begin
    if  I_LEVEL > 50 then
        dbms_output.put_line( lpad(I_LEVEL, I_LEVEL, '-')||': ... more than 50 ...');    
    else
        L_STRING_TO_SEACH := '%'||I_NAME||'%';

        for L_R in 
            ( select *
                from DBA_SOURCE
               where OWNER = nvl( upper( I_OWNER ), OWNER )
                 and upper(TEXT) like  L_STRING_TO_SEACH
                 and NAME != I_NAME
                 and LINE > 1
              order by LINE
            ) loop

            if L_R.TYPE = 'PACKAGE BODY' then
                L_PROC_NAME := L_R.NAME||'.'||GET_PROCEDURE ( L_R.NAME, L_R.LINE, L_R.OWNER );
            else
                L_PROC_NAME := L_R.NAME;
            end if;

            if L_PROC_NAME is not null and I_NAME != L_PROC_NAME then
                dbms_output.put_line( lpad(I_LEVEL, I_LEVEL + 1, '-')||': '||L_R.TYPE||' | '||L_PROC_NAME||' : '||L_R.LINE );
                PROC_CALL_CHAIN( L_PROC_NAME, I_LEVEL + 1, I_OWNER );
            end if;

        end loop; 

    end if;    
end;

