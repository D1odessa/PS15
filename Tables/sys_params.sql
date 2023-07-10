CREATE TABLE sys_params (   param_name    VARCHAR2(150),
                            value_date        DATE,
                            value_text         VARCHAR2(2000),
                            value_number NUMBER,
                            param_descr   VARCHAR2(200) );


BEGIN
        INSERT INTO DIMA.sys_params (value_text, param_descr) 
                VALUES ('USD,EUR,KZT,AMD,GBP,ILS','Список валют для синхронізації в процедурі util.api_nbu_sync');
                COMMIT;

END;
/
