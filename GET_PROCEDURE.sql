create or replace function GET_PROCEDURE ( I_PACKAGE_NAME    in varchar
                                         , I_LINE_NUMBER     in number 
                                         , I_OWNER           in varchar default null
                                         ) return varchar is

/* ******************************************************************************************

    This function search and return with the procedure/function name
	in a given package body what belongs to the given line number

    History of changes
    yyyy.mm.dd | Version | Author         | Changes
    -----------+---------+----------------+-------------------------
    2014.01.06 |  1.0    | Ferenc Toth    | Created 

***************************************************************************************** */


    type          LT_STACK is table of varchar(100);
    L_STACK       LT_STACK    := new LT_STACK();
    L_COMMAND     varchar( 100);
    L_IN_COMMENT  boolean     := false;
    L_TEXT        varchar2(4000);

    function LF_NEXT_COMMAND( P_TEXT IN OUT varchar2 ) return varchar2 is
        L_CMD    varchar2(100);
        L_I      integer := 1;
    begin
        if length( P_TEXT ) < 2 then
            return null;
        end if;
        loop

            exit when L_I > length( P_TEXT ) or substr( P_TEXT, L_I, 2 ) = '--';

            if    substr( P_TEXT, L_I, 2 ) = '/*' then

                P_TEXT := substr( P_TEXT, L_I + 2 );
                return '/*';

            elsif substr( P_TEXT, L_I, 2 ) = '*/' then

                P_TEXT := substr( P_TEXT, L_I + 2 );
                return '*/';

            elsif substr( P_TEXT, L_I, 1 ) in ( ' ', ';' ) and L_CMD is not null then  -- end of command

                if    L_CMD = 'END' then

                    -- go for ;
                    loop
                        exit when L_I > length( P_TEXT ) or substr( P_TEXT, L_I, 1 ) = ';';
                        L_CMD := L_CMD || substr( P_TEXT, L_I, 1 );
                        L_I   := L_I + 1;
                    end loop;
                    P_TEXT := substr( P_TEXT, L_I + length( L_CMD ) );
                    return 'END';

                elsif L_CMD in ( 'LOOP' , 'BEGIN', 'IF' ) then

                    P_TEXT := substr( P_TEXT, L_I + length( L_CMD ) );
                    return L_CMD;

                elsif L_CMD in ( 'PROCEDURE', 'FUNCTION' ) then

                    -- go for name
                    loop
                        exit when L_I > length( P_TEXT ) or substr( P_TEXT, L_I, 1 ) != ' ';
                        L_CMD := L_CMD || substr( P_TEXT, L_I, 1 );
                        L_I   := L_I + 1;
                    end loop;
                    loop
                        exit when L_I > length( P_TEXT ) or substr( P_TEXT, L_I, 1 ) in ( ' ', '(', chr(10), chr(13) ) ;
                        L_CMD := L_CMD || substr( P_TEXT, L_I, 1 );
                        L_I   := L_I + 1;
                    end loop;

                    P_TEXT := substr( P_TEXT, L_I + length( L_CMD ) );
                    return L_CMD;

                end if;

                L_I   := L_I + length( L_CMD );
                L_CMD := '';

            else

                L_CMD := L_CMD || trim(substr( P_TEXT, L_I, 1 ));
                if substr( P_TEXT, L_I, 1 ) in ( ')') then
                    L_CMD := '';
                end if;
                L_I   := L_I + 1;

            end if;

        end loop;
        return null;
    end;

begin

    for L_ROWS in
        ( select *
            from DBA_SOURCE
           where OWNER = nvl( upper( I_OWNER ), OWNER )
             and NAME  = upper( I_PACKAGE_NAME )
             and TYPE  = 'PACKAGE BODY'
             and ( upper(TEXT) like '%PROCEDURE%' or
                   upper(TEXT) like '%FUNCTION%'  or
                   upper(TEXT) like '%BEGIN%'     or
                   upper(TEXT) like '%END%'       or
                   upper(TEXT) like '%IF %'       or
                   upper(TEXT) like '%/*%'        or
                   upper(TEXT) like '%*/%'        or
                   upper(TEXT) like '%LOOP%'
                 )
          order by LINE
        ) loop

        exit when L_ROWS.LINE >= I_LINE_NUMBER;

        L_TEXT := upper( trim( L_ROWS.TEXT ) )||';';
        L_TEXT := replace( L_TEXT, chr( 0) );
        L_TEXT := replace( L_TEXT, chr( 8) );
        L_TEXT := replace( L_TEXT, chr(10) );
        L_TEXT := replace( L_TEXT, chr(13) );

        loop
            exit when L_TEXT is null or substr( L_TEXT, 1, 1) in (chr(10), chr(13));

            L_COMMAND := LF_NEXT_COMMAND( L_TEXT );

            exit when L_COMMAND is null;

            if    L_COMMAND = '/*' then L_IN_COMMENT := true ;
            elsif L_COMMAND = '*/' then L_IN_COMMENT := false;
            elsif not L_IN_COMMENT and
                 ( L_COMMAND in ('BEGIN','IF','LOOP') or substr(L_COMMAND,1,8) in ('PROCEDUR','FUNCTION') ) then

                L_STACK.extend;
                L_STACK( L_STACK.count ) := L_COMMAND;

            elsif not L_IN_COMMENT and L_COMMAND = 'END' then

                L_STACK.TRIM;

            end if;

        end loop;

    end loop;

    -- go for PROCEDURE or FUNCTION!
    if L_STACK.count > 0 then
        loop
            L_TEXT:=  L_STACK( L_STACK.last );
            exit when substr(L_TEXT, 1, 8 ) in ('PROCEDUR','FUNCTION');
            L_STACK.TRIM;
            if L_STACK.count = 0 then
                L_TEXT := null;
                exit;
            end if;
        end loop;
    end if;

    return trim( substr( L_TEXT, instr( L_TEXT, ' ' ) ) );

end;
