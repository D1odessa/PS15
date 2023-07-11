create or replace PACKAGE util AS

    --переменные
    gc_min_salary CONSTANT NUMBER := 2000;
    
    TYPE rec_value_list IS RECORD (value_list VARCHAR2(100));
    TYPE tab_value_list IS TABLE OF rec_value_list;
    
    TYPE rec_exchange IS RECORD (   r030 NUMBER,
                                    txt VARCHAR2(100),
                                    rate NUMBER,
                                    cur VARCHAR2(100),
                                    exchangedate DATE );
    TYPE tab_exchange IS TABLE OF rec_exchange;
 
    TYPE rec_regions_list IS RECORD ( REGION_NAME VARCHAR2(100),
                                      EMP_NUM NUMBER);
    TYPE tab_regions_list IS TABLE OF rec_regions_list; 
 
    --функции

    FUNCTION add_year ( p_date in DATE DEFAULT sysdate,
                        p_year in NUMBER ) RETURN DATE;
                     
    FUNCTION get_job_title ( p_employee_id IN NUMBER )  RETURN VARCHAR2;
    
    FUNCTION get_dep_name ( p_employee_id IN NUMBER )  RETURN VARCHAR2;
    
    FUNCTION get_sum_price_sales(p_table VARCHAR2 DEFAULT 'products') RETURN NUMBER;
    
    FUNCTION table_from_list(   p_list_val  IN VARCHAR2,
                                p_separator IN VARCHAR2 DEFAULT ',') RETURN tab_value_list PIPELINED;
        
    FUNCTION get_currency (  p_currency     IN VARCHAR2 DEFAULT 'USD',
                             p_exchangedate IN DATE DEFAULT SYSDATE) RETURN tab_exchange PIPELINED;
                             
    FUNCTION get_region_cnt_emp ( p_department_id NUMBER default null) RETURN tab_regions_list PIPELINED;
   
   --процедуры
   
   PROCEDURE check_work_time;
   
   PROCEDURE add_new_jobs (   p_job_id        IN VARCHAR2,
                              p_job_title     IN VARCHAR2,
                              p_min_salary    IN NUMBER,
                              p_max_salary    IN NUMBER DEFAULT NULL,
                              po_err          OUT VARCHAR2 );
                              
    --
    PROCEDURE del_jobs ( p_job_id    IN VARCHAR2,
                         po_result   OUT VARCHAR2);
                         
    --
    PROCEDURE update_balance(p_employee_id  IN NUMBER,
                             p_balance      IN NUMBER);
                             
    -- механізму додавання нового співробітника                         
    PROCEDURE add_employee (  p_first_name      IN VARCHAR2,
                              p_last_name       IN VARCHAR2,
                              p_email           IN VARCHAR2,
                              p_phone_number    IN VARCHAR2,
                              p_hire_date       IN DATE DEFAULT trunc(sysdate, 'dd'),
                              p_job_id          IN VARCHAR2,
                              p_salary          IN NUMBER,
                              p_commission_pct  IN VARCHAR2,
                              p_manager_id      IN NUMBER,
                              p_department_id   IN NUMBER );
                              
        --процедура удаления сотрудника
        PROCEDURE fire_an_employee (  p_employee_id IN NUMBER );
        
        
        --
        PROCEDURE change_attribute_employee (   p_employee_id    IN VARCHAR2,
                                                p_first_name     IN VARCHAR2 DEFAULT NULL,
                                                p_last_name      IN VARCHAR2 DEFAULT NULL,
                                                p_email          IN VARCHAR2 DEFAULT NULL,
                                                p_phone_number   IN VARCHAR2 DEFAULT NULL,
                                                p_job_id         IN VARCHAR2 DEFAULT NULL,
                                                p_salary         IN NUMBER DEFAULT NULL,
                                                p_commission_pct IN VARCHAR2 DEFAULT NULL,
                                                p_manager_id     IN NUMBER DEFAULT NULL,
                                                p_department_id  IN NUMBER DEFAULT NULL );
                                                
        -- процедура копирования таблиц
        PROCEDURE copy_table (   p_source_scheme IN VARCHAR2,
                                 p_target_scheme IN VARCHAR2 DEFAULT USER,
                                 p_list_table    IN VARCHAR2 ,
                                 p_copy_data     IN BOOLEAN DEFAULT FALSE,
                                 po_result       OUT VARCHAR2 );


        -- т6 процедура синхронізації даних з API у базу даних (курсы валют )
        PROCEDURE api_nbu_sync ;

        
   
END util;
---------------------------------------------------------------------------------------------
---  UTIL BODY ---
---------------------------------------------------------------------------------------------
create or replace PACKAGE BODY util AS

----переменные
    c_percent_of_min_salary CONSTANT NUMBER := 1.5;
    
    
----------- Функции внутри пакета util
   
----------------- функция проверки наличия в таблице по ячейке
        FUNCTION is_exist ( p_func IN VARCHAR2 DEFAULT 'count(*)',
                            p_what IN VARCHAR2,
                            p_colum IN VARCHAR2,
                            p_where IN VARCHAR2 ) RETURN NUMBER IS
                               
             v_result NUMBER;
             vv_sql VARCHAR2(600);
          BEGIN
            
            vv_sql := 'select ' || p_func ||' FROM dima.'||p_where||' p
                    WHERE p.'|| p_colum ||'='''|| p_what ||''' ';
            EXECUTE IMMEDIATE vv_sql INTO v_result;
                        
          RETURN v_result;
          END is_exist;   
          
          
----------------- процедура доступа по времени
        PROCEDURE time_access (p_employee_group IN NUMBER DEFAULT 1) IS
            
            BEGIN
                IF p_employee_group = 1 THEN
                    IF TO_CHAR(SYSDATE, 'DY') IN ('СБ', 'ВС') OR TO_CHAR(SYSDATE, 'hh24') < 8 OR TO_CHAR(SYSDATE, 'hh24') > 17 THEN
                        raise_application_error (-20001, 'Ви можете додавати/видалити нового співробітника лише в робочий час');
                    END IF;
--                ELSIF  p_employee_group = 2 THEN
                    
                        
                END IF;
                
            END time_access;
   
------------------------ ФУНКЦИИ внешние
-------------------- 
     FUNCTION add_year(p_date in DATE DEFAULT sysdate,
                       p_year in NUMBER ) RETURN DATE IS
    v_date DATE;
    v_year NUMBER := p_year*12 ;
    BEGIN
        SELECT add_months(p_date, v_year)
        INTO v_date
        FROM dual;
        RETURN v_date;
    END add_year;
    
-----------------------    --  
    FUNCTION get_job_title ( p_employee_id IN NUMBER )  RETURN VARCHAR2 IS
        v_job_title dima.jobs.job_title%TYPE;

    BEGIN   
        SELECT jb.job_title
        INTO v_job_title
        FROM employees em
        JOIN dima.jobs jb
        ON em.job_id = jb.job_id
        WHERE em.employee_id = p_employee_id;
    
        RETURN v_job_title;
    END get_job_title;
    
-------------------------    --
    FUNCTION get_dep_name(p_employee_id IN NUMBER)  RETURN VARCHAR2 IS
        v_dep_name dima.departments.department_name%type;

    BEGIN
    
        select dp.department_name
        into v_dep_name 
        from employees em
        join dima.departments dp
        on em.department_id = dp.department_id
        where em.employee_id = p_employee_id;
    
        RETURN v_dep_name;
    END get_dep_name;
    
    
---------------------------------------
        FUNCTION get_sum_price_sales(p_table VARCHAR2 DEFAULT 'products') RETURN NUMBER IS
       
        v_table VARCHAR2(50) := p_table;
        v_dynamic_sql_code VARCHAR2(500);
        v_sum NUMBER;
        err_tab_ncor EXCEPTION;
        v_message dima.logs.message%TYPE;
    
    BEGIN
    
        IF v_table not in ('products_old','products') THEN
            raise err_tab_ncor;
        END IF;
    
        v_dynamic_sql_code := 'SELECT SUM(p.price_sales) FROM hr.'||v_table||' p';
    --    dbms_output.put_line(v_dynamic_sql_code);
        EXECUTE IMMEDIATE v_dynamic_sql_code INTO v_sum;
    
        RETURN v_sum;
    
    EXCEPTION
        WHEN err_tab_ncor THEN
            v_message := '"Неприпустиме значення! Очікується products або products_old" (код помилки -20001)' ||SQLERRM ;
            to_log(p_appl_proc => 'util.get_sum_price_sales', p_message => v_message);
            raise_application_error(-20001, 'Неприпустиме значення! Очікується products або products_old" (код помилки -20001)');
    
    END get_sum_price_sales;
    
------------------- 07 ------1
    FUNCTION table_from_list(    p_list_val IN VARCHAR2,
                                    p_separator IN VARCHAR2 DEFAULT ',') RETURN tab_value_list PIPELINED IS

    out_rec tab_value_list := tab_value_list();
    l_cur SYS_REFCURSOR;

    BEGIN
    OPEN l_cur FOR
        SELECT TRIM(REGEXP_SUBSTR(p_list_val, '[^'||p_separator||']+', 1, LEVEL)) AS cur_value
            FROM dual
        CONNECT BY LEVEL <= REGEXP_COUNT(p_list_val, p_separator) + 1;

        BEGIN
        LOOP
                EXIT WHEN l_cur%NOTFOUND;
                FETCH l_cur BULK COLLECT     
                INTO out_rec;
                FOR i IN 1 .. out_rec.count LOOP
                    PIPE ROW(out_rec(i));
                END LOOP;
        END LOOP;
    CLOSE l_cur;

        EXCEPTION

        WHEN OTHERS THEN
            IF (l_cur%ISOPEN) THEN
                    CLOSE l_cur;
                    RAISE;
            ELSE
                RAISE;
            END IF;
        END;

END table_from_list;

--------7-------2
    FUNCTION get_currency (  p_currency IN VARCHAR2 DEFAULT 'USD',
                         p_exchangedate IN DATE DEFAULT SYSDATE) RETURN tab_exchange PIPELINED IS
    out_rec tab_exchange := tab_exchange();
    l_cur SYS_REFCURSOR;
    BEGIN
        OPEN l_cur FOR
        
        SELECT tt.r030, tt.txt, tt.rate, tt.cur, TO_DATE(tt.exchangedate, 'dd.mm.yyyy') AS exchangedate
        FROM (SELECT get_needed_curr(p_valcode => p_currency,p_date => p_exchangedate) AS json_value FROM dual)
            CROSS JOIN json_table
            (
            json_value, '$[*]'
            COLUMNS
                (
                r030 NUMBER PATH '$.r030',
                txt VARCHAR2(100) PATH '$.txt',
                rate NUMBER PATH '$.rate',
                cur VARCHAR2(100) PATH '$.cc',
                exchangedate VARCHAR2(100) PATH '$.exchangedate'
                )
            ) TT;
        BEGIN
        LOOP
            EXIT WHEN l_cur%NOTFOUND;
            FETCH l_cur BULK COLLECT
            INTO out_rec;
            FOR i IN 1 .. out_rec.count LOOP
                PIPE ROW(out_rec(i));
            END LOOP;
        END LOOP;
        CLOSE l_cur;
        
        EXCEPTION
        WHEN OTHERS THEN
            IF (l_cur%ISOPEN) THEN
                CLOSE l_cur;
                RAISE;
            ELSE
                RAISE;
            END IF;
        END;
    END get_currency;
    
------------h07_01--   домашка 7_01
    FUNCTION get_region_cnt_emp ( p_department_id NUMBER default null) RETURN tab_regions_list PIPELINED IS

    out_rec tab_regions_list := tab_regions_list();
    l_cur SYS_REFCURSOR;

    BEGIN
        OPEN l_cur FOR
        
            select  tt.region_name, count(tt.region_name) as emp_num
            from (  select em.employee_id, em.department_id, rg.region_id, rg.region_name
                    from hr.employees em
                    join  hr.departments dp
                        on em.department_id = dp.department_id
                    join  hr.locations lc
                        on dp.location_id = lc.location_id
                    join hr.countries cn
                        on lc.country_id = cn.country_id
                    join hr.regions rg
                        on cn.region_id = rg.region_id
            --        where em.department_id = 60
                    where em.department_id = p_department_id or p_department_id is null--em.department_id = null or null is null
                    ) tt
            group by tt.region_name;
    
            BEGIN
            LOOP
                    EXIT WHEN l_cur%NOTFOUND;
                    FETCH l_cur BULK COLLECT     
                    INTO out_rec;
                    FOR i IN 1 .. out_rec.count LOOP
                        PIPE ROW(out_rec(i));
                    END LOOP;
            END LOOP;
        CLOSE l_cur;
    
            EXCEPTION
    
            WHEN OTHERS THEN
                IF (l_cur%ISOPEN) THEN
                        CLOSE l_cur;
                        RAISE;
                ELSE
                    RAISE;
                END IF;
            END;

    END get_region_cnt_emp;

    
----------- ПРОЦЕДУРЫ внешние -------------------------
    
-------------- 0 --
    
    PROCEDURE check_work_time IS
                
        BEGIN
        
            IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') IN ('SAT', 'SUN') THEN
                raise_application_error (-20205, 'Ви можете вносити зміни лише у робочі дні');
            END IF;
          
                       
    END check_work_time;
    
    
---------------- 1 --
        PROCEDURE add_new_jobs(   p_job_id        IN VARCHAR2,
                                  p_job_title     IN VARCHAR2,
                                  p_min_salary    IN NUMBER,
                                  p_max_salary    IN NUMBER DEFAULT NULL,
                                  po_err          OUT VARCHAR2) IS
        v_max_salary jobs.max_salary%TYPE;
        v_is_exist_job NUMBER;
        salary_err EXCEPTION;
        
    BEGIN
    
--        IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') IN ('SAT', 'SUN') THEN
--            raise_application_error (-20205, 'Ви можете вносити зміни лише у робочі дні');
--        END IF;
        check_work_time;
    
        IF p_max_salary IS NULL THEN
            v_max_salary := p_min_salary * c_percent_of_min_salary;
        ELSE
            v_max_salary := p_max_salary;
        END IF;
        
        --SELECT COUNT(j.job_id)
        --INTO v_is_exist_job
        --FROM jobs j
        --WHERE j.job_id = p_job_id;
        BEGIN
            IF ( p_min_salary < gc_min_salary OR p_max_salary < gc_min_salary ) THEN
                --po_err := 'Передана зарплата менша за 2000';
                RAISE salary_err;
            --elsif v_is_exist_job >=1 THEN
            --   po_err := 'Посада '||p_job_id||' вже існує';
            ELSE
                INSERT INTO dima.jobs (job_id,job_title,min_salary,max_salary)
                VALUES (p_job_id,p_job_title,p_min_salary,v_max_salary);
                COMMIT;
                po_err := 'Посада '||p_job_id||' успішно додана';
            END IF;
            
        EXCEPTION
            WHEN salary_err THEN
                raise_application_error(-20001, 'Передана зарплата менша за 2000');
            WHEN dup_val_on_index THEN
                raise_application_error(-20002, 'Посада '||p_job_id||' вже існує');
            WHEN OTHERS THEN
                raise_application_error(-20003, 'Неизвестная ошибка при добавлении должности'|| SQLERRM);
            
        END;
    END add_new_jobs;
    
--------------2--
    PROCEDURE del_jobs ( p_job_id    IN VARCHAR2,
                         po_result   OUT VARCHAR2) IS
    v_job_id dima.jobs.job_id%type;                        
    BEGIN
        check_work_time;
        BEGIN
            select jb.job_id
            into v_job_id
            from dima.jobs jb
            where jb.job_id = p_job_id;
        
             delete from dima.jobs jb
             where jb.job_id = p_job_id;
             COMMIT;    
             po_result := 'Посада '||p_job_id||' успішно видалена';
            
        EXCEPTION
            WHEN no_data_found THEN
                raise_application_error(-20004, '"Посада '|| p_job_id ||' не існує"(код помилки -20004)');
                        
        END;
    END del_jobs;
    
---------3-----
    PROCEDURE update_balance(p_employee_id IN NUMBER,
                             p_balance IN NUMBER) IS
                             
        v_balance_new dima.balance.balance%TYPE;
        v_balance_old dima.balance.balance%TYPE;
        v_message dima.logs.message%TYPE;
    
    BEGIN
        SELECT balance
        INTO v_balance_old
        FROM dima.balance b
        WHERE b.employee_id = p_employee_id
        FOR UPDATE; -- Блокуємо рядок для оновлення
    
        IF v_balance_old >= p_balance THEN
            UPDATE balance b
            SET b.balance = v_balance_old - p_balance
            WHERE employee_id = p_employee_id
    
            RETURNING b.balance INTO v_balance_new; -- щоб не робити новий SELECT INTO
        ELSE
            v_message := 'Employee_id = '||p_employee_id||'. Недостатньо коштів на рахунку. Поточний баланс '||v_balance_old||', спроба зняття '||p_balance||'';
            raise_application_error(-20001, v_message);
        END IF;
    
        v_message := 'Employee_id = '||p_employee_id||'. Кошти успішно зняті з рахунку. Було '||v_balance_old||', стало '||v_balance_new||'';
        dbms_output.put_line(v_message);
        to_log(p_appl_proc => 'util.update_balance', p_message => v_message);
    
--        IF 1=0 THEN -- зімітуємо непередбачену помилку
--            v_message := 'Непередбачена помилка';
--            raise_application_error(-20001, v_message);
--        END IF;
    COMMIT; -- зберігаємо новий баланс та знімаємо блокування в поточній транзакції
    
    EXCEPTION
        WHEN OTHERS THEN
            to_log(p_appl_proc => 'util.update_balance', p_message => NVL(v_message, 'Employee_id = '||p_employee_id||'. ' ||SQLERRM));
            ROLLBACK; -- Відміняємо транзакцію у разі виникнення помилки
            raise_application_error(-20001, NVL(v_message, 'Не відома помилка'));
    
    END update_balance;
    
    
-------- Процедура механізму додавання нового співробітника
    
    PROCEDURE add_employee (  p_first_name IN VARCHAR2,
                              p_last_name IN VARCHAR2,
                              p_email IN VARCHAR2,
                              p_phone_number IN VARCHAR2,
                              p_hire_date IN DATE DEFAULT trunc(sysdate, 'dd'),
                              p_job_id IN VARCHAR2,
                              p_salary IN NUMBER,
                              p_commission_pct IN VARCHAR2,
                              p_manager_id IN NUMBER,
                              p_department_id IN NUMBER ) IS
                          
        v_job_id_exist NUMBER;
        v_department_id_exist NUMBER;
        v_sql VARCHAR2(500);
        v_min_salary NUMBER;
        v_max_salary NUMBER;
        v_employee_id NUMBER;
        v_sqlerrm VARCHAR2(600);
        
        
        --  
         FUNCTION get_max_employee_id RETURN NUMBER IS
             vv_employee_id NUMBER;
          BEGIN
            SELECT NVL(MAX(employee_id),0)+1
            INTO vv_employee_id
            FROM dima.employees;
          RETURN vv_employee_id;
          END get_max_employee_id;
          
        --
                          
    BEGIN
            --
            log_util.log_start('add_employee');
            
            --2 проверка 1
            v_job_id_exist := is_exist('count(*)',p_job_id,'job_id','jobs');
            
                IF v_job_id_exist =0 THEN
                    raise_application_error(-20001,'Введено неіснуючий код посади');
                END IF;
                
            --3 проверка 2  
            v_department_id_exist := is_exist ('count(*)',p_department_id,'department_id','departments');
                
                IF v_department_id_exist =0 THEN
                    raise_application_error(-20001,'Введено неіснуючий ідентифікатор відділу');
                END IF;
        
             --4 проверка 3    
             v_min_salary := is_exist('min_salary',p_job_id,'job_id','jobs');
             v_max_salary := is_exist('max_salary',p_job_id,'job_id','jobs');
                
                 IF p_salary < v_min_salary or p_salary > v_max_salary  THEN
                    raise_application_error(-20001,'Введено неприпустиму заробітну плату для даного коду посади');
                 END IF;
        
              --5 проверка рабочего времени
                time_access(); 
                
              --6
                v_employee_id := get_max_employee_id();
        
        INSERT INTO dima.employees(employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id)
        VALUES(v_employee_id, p_first_name, p_last_name, p_email, p_phone_number, p_hire_date, p_job_id, p_salary, p_commission_pct, p_manager_id, p_department_id);
        COMMIT;
        
             -- Співробітник ІМ'Я, Прізвище, КОД ПОСАДИ, ІД ДЕПАРТАМЕНТУ успішно додано до системи
        dbms_output.put_line('Співробітник '||p_first_name||' '||p_last_name ||' ' ||p_job_id ||' ІД ДЕПАРТАМЕНТУ = '||p_department_id|| ' успішно додано до системи');
            v_sql := 'Співробітник '||p_first_name||' '||p_last_name ||' ' ||p_job_id ||' ІД ДЕПАРТАМЕНТУ = '||p_department_id|| ' успішно додано до системи';
        log_util.log_finish('add_employee',v_sql);

        
    EXCEPTION
        
        WHEN OTHERS THEN
            v_sqlerrm := sqlerrm  ;
            log_util.log_error('add_employee',  v_sqlerrm); 
            ROLLBACK; -- Відміняємо транзакцію у разі виникнення помилки
            raise_application_error(-20001, sqlerrm);
    
    END add_employee;

------- процедура механізму звільнення існуючого співробітника
        
        PROCEDURE fire_an_employee (  p_employee_id IN NUMBER ) IS
        
            v_employee_id_exist NUMBER;
            v_empl VARCHAR2(300);
            vo_result VARCHAR2(350);
            v_sqlerrm VARCHAR2(300);
        
        BEGIN
            
            log_util.log_start('fire_an_employee');
        
            v_employee_id_exist := is_exist('count(*)',p_employee_id,'employee_id','employees');
                IF v_employee_id_exist =0 THEN
                    raise_application_error(-20001,'Переданий співробітник не існує');
                END IF;
                                --удаление возможно в разрешенный период
            time_access();
                                --добавление сотрудника в таблицу истории сотрудников
            INSERT INTO dima.employees_history (employee_id,first_name,last_name,email,phone_number,start_date,end_date,job_id,department_id)
                                    select employee_id,first_name,last_name,email,phone_number,hire_date,sysdate,job_id,department_id 
                                    from dima.employees
                                    where employee_id = p_employee_id;
                                    
                    --формат співробітника ім'я,прізвище, код посади успільності, ід департаменту
                select first_name||' '||last_name ||' код посади - ' ||job_id ||' ІД ДЕПАРТАМЕНТУ = '|| department_id as v_empl
                INTO v_empl 
                from dima.employees
                where employee_id = p_employee_id;
            
            delete from dima.employees em
                     where em.employee_id = p_employee_id;
                     COMMIT;    
                vo_result := 'Співробітника '||p_employee_id||' '||v_empl||' успішно звільнено';
                dbms_output.put_line(vo_result);    
                     
            
            log_util.log_finish('fire_an_employee',vo_result);
        
                
        EXCEPTION
                
                WHEN OTHERS THEN
                    v_sqlerrm := sqlerrm ;
                    log_util.log_error('fire_an_employee',  v_sqlerrm); 
                    ROLLBACK; -- Відміняємо транзакцію у разі виникнення помилки
                    raise_application_error(-20001, sqlerrm);
            
        END fire_an_employee;
        
---------- Процедура  механізму зміни атрибутів співробітника

        PROCEDURE change_attribute_employee (   p_employee_id   IN VARCHAR2,
                                                p_first_name    IN VARCHAR2 DEFAULT NULL,
                                                p_last_name     IN VARCHAR2 DEFAULT NULL,
                                                p_email         IN VARCHAR2 DEFAULT NULL,
                                                p_phone_number  IN VARCHAR2 DEFAULT NULL,
                                                p_job_id        IN VARCHAR2 DEFAULT NULL,
                                                p_salary        IN NUMBER DEFAULT NULL,
                                                p_commission_pct IN VARCHAR2 DEFAULT NULL,
                                                p_manager_id    IN NUMBER DEFAULT NULL,
                                                p_department_id IN NUMBER DEFAULT NULL) IS
                                                
            v_list_par VARCHAR2(300) :='first_name,last_name,email,phone_number,job_id,salary,commission_pct,manager_id,department_id';
            vv_sql VARCHAR2(600);
            
            pp_salary VARCHAR2(30) := to_char(p_salary);
            pp_manager_id VARCHAR2(30) := to_char(p_manager_id);
            pp_department_id VARCHAR2(30) := to_char(p_department_id);
            v_sqlerrm VARCHAR2(400);
        
        BEGIN
        
            log_util.log_start('change_attribute_employee');
            
            IF p_employee_id is null OR (p_first_name is null AND p_last_name is null AND 
                p_email is null and p_phone_number is null AND p_job_id is null AND p_salary is null AND 
                p_commission_pct is null AND p_manager_id is null AND p_department_id is null) THEN
                    raise_application_error(-20001,'Жодного атрибута для зміни не передано');  
            END IF;
            
             FOR cc IN ( SELECT t.vals,
                                CASE
                                     WHEN vals = 'first_name' THEN p_first_name
                                     WHEN vals = 'last_name' THEN p_last_name
                                     WHEN vals = 'email' THEN p_email
                                     WHEN vals = 'phone_number' THEN p_phone_number
                                     WHEN vals = 'job_id' THEN p_job_id
                                     WHEN vals = 'salary' THEN pp_salary
                                     WHEN vals = 'commission_pct' THEN p_commission_pct
                                     WHEN vals = 'manager_id' THEN pp_manager_id
                                     WHEN vals = 'department_id' THEN pp_department_id
                                 END AS p_v
                             FROM (       
                                      SELECT REGEXP_SUBSTR(znach, '[^,]+', 1, LEVEL) vals
                                            FROM ( SELECT v_list_par as znach
                                                     FROM dual )
                                      CONNECT BY LEVEL <= LENGTH(REGEXP_REPLACE(znach, '[^,]+')) + 1) t) LOOP
                
                IF cc.p_v is not null THEN
                
                        vv_sql := 'UPDATE dima.employees em SET em.' || cc.vals ||' = '''||cc.p_v|| ''' WHERE em.employee_id ='||p_employee_id;
--                        dbms_output.put_line('У співробітника '||p_employee_id||' успішно оновлені атрибути');
                        dbms_output.put_line(vv_sql);
                        EXECUTE IMMEDIATE vv_sql;
                END IF;
            END LOOP;
--            COMMIT;
            dbms_output.put_line('У співробітника '||p_employee_id||' успішно оновлені атрибути');
            log_util.log_finish('change_attribute_employee','У співробітника '||p_employee_id||' успішно оновлені атрибути');
            
        
        EXCEPTION
                
                WHEN OTHERS THEN
                    v_sqlerrm := sqlerrm ;
                    log_util.log_error('change_attribute_employee',  v_sqlerrm); 
                    ROLLBACK; -- Відміняємо транзакцію у разі виникнення помилки
                    raise_application_error(-20001, sqlerrm);
        
        END change_attribute_employee;


----------  Процедура копирования таблиц
    
        PROCEDURE copy_table (   p_source_scheme IN VARCHAR2,
                                 p_target_scheme IN VARCHAR2 DEFAULT USER,
                                 p_list_table    IN VARCHAR2 ,
                                 p_copy_data     IN BOOLEAN DEFAULT FALSE,
                                 po_result       OUT VARCHAR2 ) IS
    

        v_source_scheme VARCHAR2(300) := ''''||p_source_scheme||'''';  

        v_target_scheme VARCHAR2(300) := p_target_scheme||'.'; 
    v_tab VARCHAR2(100);   --имя таблицы для перебора в цикле for
    v_ddl_select VARCHAR2(2000);  -- DDL команды в v_sql
    v_sql VARCHAR2(2000);   -- DDL команда создания таблицы
     
    t_exist number;
    v_sql_exist VARCHAR2(300);
                                    
BEGIN
        log_util.log_start('copy_table');
         dbms_output.put_line(p_list_table);   
         dbms_output.put_line('from '||v_source_scheme|| ' to '||v_target_scheme);
                  
         FOR i in (select * from TABLE (util.table_from_list( p_list_table))) loop
         
         <<search_tables>>
            BEGIN
--                dbms_output.put_line(i.VALUE_LIST); --значение текущей иттерации цикла 
                v_tab := ''''||i.VALUE_LIST||'''';
                
                --проверка, есть ли такая таблица в схеме для создания таблиц 
                  v_sql_exist :=  ' SELECT count(*) from all_tab_columns
                                        where owner = '||''''||p_target_scheme||''''||
                                        ' AND TABLE_NAME IN ('||v_tab||')';
                                        
                  EXECUTE IMMEDIATE v_sql_exist into t_exist ;
                                
                    IF t_exist = 0 THEN 
                
                v_ddl_select  := 'select table_name||'' (''||LISTAGG(column_name ||'' ''|| data_type||count_symbol,'', '')
                                            WITHIN GROUP(ORDER BY column_id)||'')'' AS ddl_code
                                    FROM (SELECT table_name,
                                             column_name,
                                             data_type,
                                             CASE
                                             WHEN data_type = ''VARCHAR2'' THEN ''(''||data_length||'')'' 
                                             WHEN data_type = ''CHAR'' THEN ''(''||data_length||'')''
                                             WHEN data_type = ''DATE'' THEN NULL
                                             WHEN data_type = ''NUMBER'' THEN replace( ''(''||data_precision||'',''||data_scale||'')'', ''(,)'', NULL)
                                             END AS count_symbol,
                                             column_id
                                 FROM all_tab_columns
                                 WHERE owner ='||v_source_scheme||'
                                 AND table_name IN ('||v_tab||')
                                 ORDER BY table_name, column_id)
                                 GROUP BY table_name';
                                 
                 -- выборка таблицы для создания и ее столбцов                
                EXECUTE IMMEDIATE v_ddl_select into v_sql ; 
                  
                 --создание таблицы                    
                 v_sql := 'CREATE TABLE '||v_target_scheme||v_sql;
--                      dbms_output.put_line(v_sql);
                 EXECUTE IMMEDIATE v_sql;
                    log_util.log_start('copy_table','создана таблица '||i.VALUE_LIST||' в схеме '||p_target_scheme);
                    po_result := po_result||'создана таблица '||i.VALUE_LIST ||',';
                    
                    --копировать данные с таблицы?
                    IF p_copy_data = TRUE THEN
                    
                        v_ddl_select := 'INSERT INTO '||p_target_scheme||'.' ||i.VALUE_LIST||' SELECT * FROM '||p_source_scheme||'.'||i.VAlUE_LIST;
                            dbms_output.put_line(v_ddl_select);
                        EXECUTE IMMEDIATE v_ddl_select ; 
                            COMMIT;
                            log_util.log_start('copy_table','в таблицу '||i.VALUE_LIST||' скопированы данные из схемы '||p_source_scheme);
                         
                    END IF;
                
                ELSE
                    dbms_output.put_line( ' table = '||i.VALUE_LIST||', имеется в схеме');
                    log_util.log_start('copy_table',' table = '||i.VALUE_LIST||', имеется в схеме');
        
                END IF;
        
            EXCEPTION
                    WHEN no_data_found THEN
                        dbms_output.put_line( ' table = '||i.VALUE_LIST||', не знайдена  в схеме джерела');
                        log_util.log_start('copy_table',' table = '||i.VALUE_LIST||', не знайдена  в схеме джерела');
                    CONTINUE;
                    
                    WHEN OTHERS THEN
                            log_util.log_error('copy_table',  sqlerrm); 
                            raise_application_error(-20001, sqlerrm);
                    
            END search_tables;
        
        END LOOP;
--    dbms_output.put_line(po_result);
        log_util.log_finish('copy_table');
END copy_table; 


------------- т6 процедура синхронізації даних з API у базу даних (курсы валют ) ------------------------------------
           PROCEDURE api_nbu_sync  IS
                         
                    v_list_currencies VARCHAR2(200);
                    v_sql VARCHAR2(400);
                BEGIN   
                        
                        SELECT value_text
                            INTO v_list_currencies
                        FROM sys_params
                        WHERE param_name = 'list_currencies';
                                
                        
                        FOR cc IN ( SELECT value_list AS curr FROM TABLE(util.table_from_list(p_list_val => v_list_currencies)) ) LOOP
                                
                                <<insert_block>>
                                BEGIN
                                
                                dbms_output.put_line('insert '||cc.curr);
                                    v_sql :=    ' INSERT INTO cur_exchange (R030, TXT, RATE, CUR, EXCHANGEDATE, CHANGE_DATE)
                                                 SELECT t.R030, t.TXT, t.RATE, t.CUR, t.EXCHANGEDATE, trunc(sysdate, ''dd'') as CHANGE_DATE
                                                 FROM TABLE(util.get_currency(p_currency => '||''''||cc.curr||''''||')) t';
                --                        dbms_output.put_line(v_sql);
                                
                                    EXECUTE IMMEDIATE v_sql ;
                                    
                                 EXCEPTION
                                    WHEN OTHERS THEN
                                        log_util.log_error('api_nbu_sync',sqlerrm);
                                        raise_application_error(-20001, sqlerrm);
                            
                                END insert_block ;
                        
                        END LOOP;
                        
                        COMMIT;
                        log_util.log_finish('api_nbu_sync');
                    
     
            END api_nbu_sync;
------------------------------------
        
    
END util;
